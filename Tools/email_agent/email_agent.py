#!/usr/bin/env python3
"""
Spinrise Email Monitor Agent
Watches Thunderbird INBOX and Sent folders for new emails, summarises each with AI,
appends the result to EmailSummary.md, and creates Jira issues for actionable items.

Supported providers (set in config.json):
  gemini    — Google Gemini (free tier, recommended)
  ollama    — Local Ollama (fully offline, no API key)
  anthropic — Anthropic Claude (paid)

Runs as a standalone process -- no Claude Code dependency.
"""

import os
import re
import sys
import json
import time
import logging
import mailbox
import email
import email.header
import hashlib
import base64
import shutil
import subprocess
import argparse
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path
from typing import Optional

try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
except ImportError:
    print("Missing dependency: watchdog")
    print("Run: pip install watchdog")
    sys.exit(1)

# ─── Paths ────────────────────────────────────────────────────────────────────

BASE_DIR    = Path(__file__).parent
CONFIG_FILE = BASE_DIR / "config.json"
STATE_FILE  = BASE_DIR / "state.json"

DEFAULT_CONFIG: dict = {
    "thunderbird_path": "",
    "watch_mode": "mbox",
    # Optional second path for Sent folder — set to empty string to disable
    "sent_path": "",
    "sent_watch_mode": "mbox",
    "summary_file": "D:\\Spinrise\\Docs\\Email\\EmailSummary.md",
    "provider": "gemini",
    "gemini_api_key": "",
    "gemini_model": "gemini-2.0-flash",
    "ollama_url": "http://localhost:11434",
    "ollama_model": "llama3.2",
    "anthropic_api_key": "",
    "anthropic_model": "claude-opus-4-7",
    "log_file": "email_agent.log",
    "skip_existing_on_first_run": True,
    # ─── Jira integration ──────────────────────────────────────────────────
    "jira_enabled": False,
    "jira_url": "https://kalsofte.atlassian.net",
    "jira_email": "",
    "jira_token": "",
    "jira_project_key": "SPIN",
    "jira_default_assignee_id": "",
    "jira_sprint_id": 0,
}

# ─── Logging ─────────────────────────────────────────────────────────────────

def setup_logging(log_filename: str) -> None:
    log_path = BASE_DIR / log_filename
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[
            logging.FileHandler(log_path, encoding="utf-8"),
            logging.StreamHandler(sys.stdout),
        ],
    )

logger = logging.getLogger(__name__)

PANDOC_AVAILABLE = shutil.which("pandoc") is not None

# ─── Config & State ──────────────────────────────────────────────────────────

def load_config() -> dict:
    if not CONFIG_FILE.exists():
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        print(f"Config file created: {CONFIG_FILE}")
        print("Fill in the required fields, then re-run.")
        sys.exit(0)
    with open(CONFIG_FILE, encoding="utf-8") as f:
        user_cfg = json.load(f)
    cleaned = {k: v for k, v in user_cfg.items() if not k.startswith("_")}
    return {**DEFAULT_CONFIG, **cleaned}


def load_state() -> dict:
    if STATE_FILE.exists():
        with open(STATE_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {"processed_ids": [], "mbox_offset": -1, "sent_mbox_offset": -1, "jira_pushed_ids": []}


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)

# ─── Jira Client ─────────────────────────────────────────────────────────────

# Maps keywords in the email/AI response to epic keys
EPIC_MAP = {
    "M01 PR Form":        "SPIN-1",
    "PR Form":            "SPIN-1",
    "M01 PR Amendment":   "SPIN-2",
    "PR Amendment":       "SPIN-2",
    "M01 PR Cancellation":"SPIN-3",
    "PR Cancellation":    "SPIN-3",
    "M01 PR Foreclosure": "SPIN-4",
    "PR Foreclosure":     "SPIN-4",
    "M01 PR Approval":    "SPIN-5",
    "PR Approval":        "SPIN-5",
    "M02 RMI":            "SPIN-6",
    "M03 Sales":          "SPIN-7",
    "M04 HR":             "SPIN-8",
    "Governance":         "SPIN-9",
    "Sprint 2 Backlog":   "SPIN-10",
}


class JiraClient:
    def __init__(self, cfg: dict) -> None:
        self.base       = cfg["jira_url"].rstrip("/")
        self.project    = cfg["jira_project_key"]
        self.sprint_id  = cfg.get("jira_sprint_id", 0)
        self.account_id = cfg.get("jira_default_assignee_id", "")
        creds = f"{cfg['jira_email']}:{cfg['jira_token']}"
        token = base64.b64encode(creds.encode()).decode()
        self.headers = {
            "Authorization": f"Basic {token}",
            "Content-Type":  "application/json",
            "Accept":        "application/json",
        }

    def _call(self, method: str, path: str, body: dict | None = None) -> dict:
        url     = f"{self.base}{path}"
        data    = json.dumps(body).encode() if body else None
        req     = urllib.request.Request(url, data=data, headers=self.headers, method=method)
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())

    def _to_adf(self, text: str) -> dict:
        return {
            "version": 1, "type": "doc",
            "content": [{"type": "paragraph", "content": [{"type": "text", "text": text}]}],
        }

    def issue_exists_by_summary(self, summary: str) -> bool:
        escaped = summary.replace('"', '\\"')[:70]
        try:
            result = self._call("POST", "/rest/api/3/search/jql", {
                "jql": f'project = {self.project} AND summary ~ "{escaped}"',
                "maxResults": 5, "fields": ["summary"],
            })
            return len(result.get("issues", [])) > 0
        except Exception:
            return False

    def create_issue(self, summary: str, issue_type: str = "Task",
                     priority: str = "Medium", description: str = "",
                     epic_key: str | None = None, due_date: str | None = None,
                     labels: list | None = None) -> str | None:
        fields: dict = {
            "project":   {"key": self.project},
            "summary":   summary[:255],
            "issuetype": {"name": issue_type},
            "priority":  {"name": priority},
        }
        if description:
            fields["description"] = self._to_adf(description)
        if due_date:
            fields["duedate"] = due_date
        if labels:
            fields["labels"] = labels
        if self.account_id:
            fields["assignee"] = {"id": self.account_id}
        if epic_key:
            fields["parent"] = {"key": epic_key}
        if self.sprint_id and issue_type != "Epic":
            fields["customfield_10020"] = self.sprint_id

        try:
            result = self._call("POST", "/rest/api/3/issue", {"fields": fields})
            return result.get("key")
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace")
            logger.error(f"Jira create failed [{e.code}]: {body[:300]}")
            return None
        except Exception as e:
            logger.error(f"Jira create error: {e}")
            return None

    def resolve_epic(self, hint: str) -> str | None:
        if not hint or hint.lower() == "none":
            return None
        for keyword, key in EPIC_MAP.items():
            if keyword.lower() in hint.lower():
                return key
        return None

# ─── AI Provider Abstraction ─────────────────────────────────────────────────

class AIClient:
    def __init__(self, cfg: dict) -> None:
        self.provider = cfg["provider"].lower()
        self.cfg = cfg
        self._client = None
        if self.provider == "gemini":
            self._init_gemini()
        elif self.provider == "anthropic":
            self._init_anthropic()
        elif self.provider == "ollama":
            self._check_ollama()
        else:
            logger.error(f"Unknown provider '{self.provider}'. Use: gemini, ollama, anthropic")
            sys.exit(1)

    def _init_gemini(self) -> None:
        try:
            from google import genai
        except ImportError:
            logger.error("Gemini SDK not installed. Run: pip install google-genai")
            sys.exit(1)
        api_key = self.cfg.get("gemini_api_key") or os.environ.get("GEMINI_API_KEY", "")
        if not api_key:
            logger.error("No Gemini API key. Set gemini_api_key in config.json or GEMINI_API_KEY env var.")
            sys.exit(1)
        self._client = genai.Client(api_key=api_key)
        logger.info(f"Provider: Google Gemini ({self.cfg['gemini_model']})")

    def _init_anthropic(self) -> None:
        try:
            import anthropic as _anthropic
        except ImportError:
            logger.error("Anthropic SDK not installed. Run: pip install anthropic")
            sys.exit(1)
        api_key = self.cfg.get("anthropic_api_key") or os.environ.get("ANTHROPIC_API_KEY", "")
        if not api_key:
            logger.error("No Anthropic API key.")
            sys.exit(1)
        self._client = _anthropic.Anthropic(api_key=api_key)
        logger.info(f"Provider: Anthropic Claude ({self.cfg['anthropic_model']})")

    def _check_ollama(self) -> None:
        url = self.cfg["ollama_url"].rstrip("/") + "/api/tags"
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                r.read()
        except Exception:
            logger.error(f"Cannot reach Ollama at {self.cfg['ollama_url']}.")
            sys.exit(1)
        logger.info(f"Provider: Ollama ({self.cfg['ollama_model']})")

    def generate(self, prompt: str) -> Optional[str]:
        try:
            if self.provider == "gemini":
                return self._gemini_generate(prompt)
            elif self.provider == "anthropic":
                return self._anthropic_generate(prompt)
            elif self.provider == "ollama":
                return self._ollama_generate(prompt)
        except Exception as e:
            logger.error(f"AI generation error: {e}")
            return None

    def _gemini_generate(self, prompt: str) -> Optional[str]:
        response = self._client.models.generate_content(
            model=self.cfg["gemini_model"], contents=prompt,
        )
        text = response.text
        return text.strip() if text else None

    def _anthropic_generate(self, prompt: str) -> Optional[str]:
        response = self._client.messages.create(
            model=self.cfg["anthropic_model"], max_tokens=800,
            messages=[{"role": "user", "content": prompt}],
        )
        for block in response.content:
            if hasattr(block, "text"):
                return block.text.strip()
        return None

    def _ollama_generate(self, prompt: str) -> Optional[str]:
        payload = json.dumps({"model": self.cfg["ollama_model"], "prompt": prompt, "stream": False}).encode()
        url = self.cfg["ollama_url"].rstrip("/") + "/api/generate"
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=120) as r:
            data = json.loads(r.read())
        return data.get("response", "").strip() or None

# ─── Email Helpers ───────────────────────────────────────────────────────────

def decode_header(raw: str) -> str:
    if not raw:
        return ""
    parts = email.header.decode_header(raw)
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            decoded.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(part)
    return " ".join(decoded).strip()


def extract_body(msg: email.message.Message, max_chars: int = 5000) -> str:
    body_parts: list[str] = []
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain" and "attachment" not in str(part.get("Content-Disposition", "")):
                try:
                    payload = part.get_payload(decode=True)
                    charset = part.get_content_charset() or "utf-8"
                    body_parts.append(payload.decode(charset, errors="replace"))
                except Exception:
                    pass
    else:
        try:
            payload = msg.get_payload(decode=True)
            if payload:
                charset = msg.get_content_charset() or "utf-8"
                body_parts.append(payload.decode(charset, errors="replace"))
        except Exception:
            pass
    # HTML-only emails: convert via pandoc (clean output) or fall back to regex strip
    if not body_parts and msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/html":
                raw = part.get_payload(decode=True) or b""
                charset = part.get_content_charset() or "utf-8"
                html = raw.decode(charset, errors="replace")
                if PANDOC_AVAILABLE:
                    try:
                        result = subprocess.run(
                            ["pandoc", "-f", "html", "-t", "plain", "--wrap=none"],
                            input=html, capture_output=True, text=True,
                            timeout=15, encoding="utf-8",
                        )
                        if result.returncode == 0:
                            body_parts.append(result.stdout)
                        else:
                            body_parts.append(re.sub(r"<[^>]+>", " ", html))
                    except Exception:
                        body_parts.append(re.sub(r"<[^>]+>", " ", html))
                else:
                    body_parts.append(re.sub(r"<[^>]+>", " ", html))
                break

    return "\n\n".join(body_parts).strip()[:max_chars]


def stable_id(msg: email.message.Message) -> str:
    mid = msg.get("Message-ID", "").strip()
    if mid:
        return mid
    raw = f"{msg.get('From','')}{msg.get('Date','')}{msg.get('Subject','')}"
    return hashlib.sha1(raw.encode()).hexdigest()


def _pandoc_to_text(src: Path, dest_txt: Path) -> bool:
    """Convert any pandoc-supported file to plain text. Returns True on success."""
    if not PANDOC_AVAILABLE:
        return False
    try:
        result = subprocess.run(
            ["pandoc", str(src), "-t", "plain", "--wrap=none", "-o", str(dest_txt)],
            capture_output=True, timeout=30,
        )
        return result.returncode == 0 and dest_txt.exists()
    except Exception as e:
        logger.warning(f"pandoc conversion failed for {src.name}: {e}")
        return False


def extract_attachments(msg: email.message.Message, out_dir: Path) -> list[dict]:
    """Save all attachments to out_dir. DOCX files are also converted to .txt."""
    out_dir.mkdir(parents=True, exist_ok=True)
    results: list[dict] = []
    for part in msg.walk():
        disp = str(part.get("Content-Disposition", ""))
        if "attachment" not in disp:
            continue
        filename = part.get_filename()
        if not filename:
            continue
        payload = part.get_payload(decode=True)
        if not payload:
            continue
        dest = out_dir / filename
        dest.write_bytes(payload)
        text: str | None = None
        if filename.lower().endswith(".docx"):
            txt_path = out_dir / (filename + ".txt")
            if _pandoc_to_text(dest, txt_path):
                text = txt_path.read_text(encoding="utf-8", errors="replace")
            else:
                try:
                    from docx import Document
                    doc = Document(dest)
                    text = "\n".join(p.text for p in doc.paragraphs if p.text.strip())
                    txt_path.write_text(text, encoding="utf-8")
                except Exception as e:
                    logger.warning(f"docx parse failed for {filename}: {e}")
        elif filename.lower().endswith(".pdf"):
            txt_path = out_dir / (filename + ".txt")
            if _pandoc_to_text(dest, txt_path):
                text = txt_path.read_text(encoding="utf-8", errors="replace")
                logger.info(f"PDF converted to text via pandoc: {filename}")
            else:
                logger.warning(f"pandoc unavailable — PDF not extracted: {filename}")
        results.append({"filename": filename, "text": text})
        logger.info(f"Attachment saved: {filename} → {dest}")
    return results

# ─── Markdown Stripper ───────────────────────────────────────────────────────

def strip_ai_markdown(text: str) -> str:
    """Remove markdown formatting from AI output before writing to the log."""
    # ATX headers: # ## ###
    text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)
    # Bold / italic: **x** *x* __x__ _x_
    text = re.sub(r'\*{1,2}([^*\n]+)\*{1,2}', r'\1', text)
    text = re.sub(r'_{1,2}([^_\n]+)_{1,2}', r'\1', text)
    # Fenced code blocks
    text = re.sub(r'```[^\n]*\n(.*?)```', r'\1', text, flags=re.DOTALL)
    # Inline code
    text = re.sub(r'`([^`\n]+)`', r'\1', text)
    # Horizontal rules
    text = re.sub(r'^(-{3,}|\*{3,})\s*$', '', text, flags=re.MULTILINE)
    # Collapse 3+ blank lines → one blank line
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


# ─── AI Summarisation ────────────────────────────────────────────────────────

SUMMARY_PROMPT = """\
You are an assistant that creates concise email summary entries for the Spinrise ERP project log.

The project log (EmailSummary.md) already contains many entries organised by module.
Your task: produce ONE new entry in exactly this format for the email below.

---
**[{date}] — {subject}**
*From:* {sender}
*To:* {recipient}

2-4 sentence summary covering: who sent it, what was communicated or requested, any decisions or action items, and outcome/status if visible. Be factual and professional.

---

Rules:
- Output ONLY the formatted entry above, no extra text, no explanation
- Keep it factual, no speculation
- If the email is a bounce, delivery receipt, or system notification with no project content, output exactly: SKIP

Email:
From: {sender}
To: {recipient}
Date: {date}
Subject: {subject}

Body:
{body}
"""

# ─── Jira Task Extraction ────────────────────────────────────────────────────

JIRA_EXTRACT_PROMPT = """\
You are an assistant that extracts actionable Jira tasks from SpinRise ERP project emails.

SpinRise is a 12-month ERP migration at Kalpatharu Software Ltd. The Jira project key is SPIN.
Abinandan (abinandan.n@kalsofte.com) is the M01 sprint lead. The CEO is ceo@kalsofte.com.

Analyze this email. If it contains clear action items that should be tracked in Jira, output a JSON array.
If there are no clear action items, output exactly: NO_TASKS

Each task in the array:
{{
  "summary": "concise task title under 80 chars",
  "issue_type": "Task or Bug or Story",
  "priority": "Highest or High or Medium or Low",
  "description": "what needs to be done, one sentence",
  "epic_hint": "M01 PR Form or M01 PR Amendment or M01 PR Cancellation or M01 PR Foreclosure or M01 PR Approval or M02 RMI or M03 Sales or M04 HR or Governance or none",
  "due_date": "YYYY-MM-DD or null"
}}

Rules:
- CEO directives and corrections → Bug (High or Highest priority)
- New features or enhancements → Story
- Defects and regressions → Bug
- Meetings, reports, communication tasks → Task
- Maximum 3 tasks per email
- Only include tasks clearly actionable by Abinandan or the team
- Date-anchor rule: only extract a task if a date signal appears within 3 sentences of the action item.
  Date signals include: a specific date (DD/MM/YYYY, YYYY-MM-DD), day names (Monday–Sunday),
  "today", "tomorrow", "EOD", "by [date]", "ASAP", "this week", "next week", month names,
  or a deadline phrase. If no date signal exists anywhere in the email, extract the task only if
  it is a direct instruction from CEO/MD, and set due_date to null.
- Exclude Jira system notifications, delivery receipts, and non-project emails — output NO_TASKS
- Output ONLY the JSON array or NO_TASKS, nothing else

Email:
From: {sender}
To: {recipient}
Date: {date}
Subject: {subject}

Body:
{body}
"""


def _resolve_priority(sender: str, ai_priority: str, weights: dict) -> str:
    """Override AI-assigned priority based on sender identity."""
    sender_lower = sender.lower()
    for key, override in weights.items():
        if key.lower() in sender_lower:
            return override
    return ai_priority


def extract_jira_tasks(ai: AIClient, msg: email.message.Message, cfg: dict) -> list[dict]:
    subject   = decode_header(msg.get("Subject", "(no subject)"))
    sender    = decode_header(msg.get("From", ""))
    recipient = decode_header(msg.get("To", ""))
    date_str  = msg.get("Date", "")
    body      = extract_body(msg, max_chars=3000)

    # Skip system notifications and Jira emails
    skip_senders = ["jira@", "noreply@", "atlassian", "no-reply"]
    if any(s in sender.lower() for s in skip_senders):
        return []

    prompt = JIRA_EXTRACT_PROMPT.format(
        date=date_str, subject=subject, sender=sender,
        recipient=recipient, body=body,
    )
    result = ai.generate(prompt)
    if not result or result.strip() == "NO_TASKS":
        return []

    # Strip markdown code fences and bold markers if present
    cleaned = result.strip()
    cleaned = re.sub(r"\*+", "", cleaned)
    if cleaned.startswith("```"):
        cleaned = "\n".join(cleaned.split("\n")[1:])
    if cleaned.endswith("```"):
        cleaned = cleaned.rsplit("```", 1)[0]
    cleaned = cleaned.strip()

    try:
        tasks = json.loads(cleaned)
        if isinstance(tasks, list):
            weights = cfg.get("sender_weights", {})
            for task in tasks:
                task["priority"] = _resolve_priority(
                    sender, task.get("priority", "Medium"), weights
                )
            return tasks
    except json.JSONDecodeError:
        logger.warning(f"Jira extract returned non-JSON: {cleaned[:100]}")
    return []

# ─── Core Processing ──────────────────────────────────────────────────────────

def summarise_email(ai: AIClient, msg: email.message.Message) -> Optional[str]:
    subject   = decode_header(msg.get("Subject", "(no subject)"))
    sender    = decode_header(msg.get("From", "(unknown)"))
    recipient = decode_header(msg.get("To", ""))
    date_str  = msg.get("Date", "")
    body      = extract_body(msg)

    if not body and not subject:
        return None

    prompt = SUMMARY_PROMPT.format(
        date=date_str, subject=subject, sender=sender,
        recipient=recipient, body=body,
    )
    result = ai.generate(prompt)
    if not result or result.strip().upper() == "SKIP":
        logger.info(f"Skipped (non-project or empty): {subject}")
        return None
    return strip_ai_markdown(result)


def process_email(ai: AIClient, msg: email.message.Message,
                  cfg: dict, state: dict,
                  jira: Optional[JiraClient] = None,
                  collected_tasks: Optional[list] = None) -> None:
    subject   = decode_header(msg.get("Subject", "(no subject)"))
    sender    = decode_header(msg.get("From", ""))
    date_str  = msg.get("Date", "")

    # 1. Extract attachments
    attachment_dir = cfg.get("attachment_dir", "")
    if attachment_dir:
        extract_attachments(msg, Path(attachment_dir))

    # 2. Summarise → EmailSummary.md
    entry = summarise_email(ai, msg)
    if entry:
        _append_summary(cfg["summary_file"], entry,
                        sender=sender, sender_weights=cfg.get("sender_weights", {}))

    # 3. Extract tasks — always, regardless of Jira setting
    extracted_ids = set(state.get("jira_pushed_ids", []))
    msg_id        = stable_id(msg)
    state_key     = f"jira_{msg_id}"

    if state_key not in extracted_ids:
        tasks = extract_jira_tasks(ai, msg, cfg)

        for task in tasks:
            task_summary = task.get("summary", "")
            if not task_summary:
                continue

            # 3a. Push to Jira if enabled
            key: str | None = None
            if jira and cfg.get("jira_enabled"):
                if jira.issue_exists_by_summary(task_summary):
                    logger.info(f"Jira: already exists — {task_summary}")
                else:
                    epic_key = jira.resolve_epic(task.get("epic_hint", ""))
                    key = jira.create_issue(
                        summary     = task_summary,
                        issue_type  = task.get("issue_type", "Task"),
                        priority    = task.get("priority", "Medium"),
                        description = task.get("description", ""),
                        epic_key    = epic_key,
                        due_date    = task.get("due_date"),
                        labels      = task.get("labels", []),
                    )
                    if key:
                        logger.info(f"Jira: created {key} — {task_summary}")

            # 3b. Write Excel row
            excel_path = cfg.get("excel_output", "")
            if excel_path:
                write_excel_row(excel_path, {
                    "date":        date_str,
                    "sender":      sender,
                    "subject":     subject,
                    "priority":    task.get("priority", "Medium"),
                    "summary":     task_summary,
                    "description": task.get("description", ""),
                    "jira_key":    key or "",
                })

            # 3c. Append Claude prompt file
            prompt_dir = cfg.get("prompt_output_dir", "")
            if prompt_dir:
                append_claude_prompt(Path(prompt_dir), date_str, task, subject, sender)

            # 3d. Collect for morning brief
            if collected_tasks is not None:
                collected_tasks.append({
                    "summary":     task_summary,
                    "description": task.get("description", ""),
                    "priority":    task.get("priority", "Medium"),
                    "epic_hint":   task.get("epic_hint", ""),
                    "due_date":    task.get("due_date"),
                    "subject":     subject,
                    "sender":      sender,
                    "jira_key":    key or "",
                })

        if tasks:
            logger.info(f"Tasks: {len(tasks)} extracted from: {subject}")

        extracted_ids.add(state_key)
        state["jira_pushed_ids"] = list(extracted_ids)
        save_state(state)


def _append_summary(summary_file: str, entry: str,
                    sender: str = "", sender_weights: dict | None = None) -> None:
    path = Path(summary_file)
    if not path.exists():
        logger.error(f"Summary file not found: {summary_file}")
        return
    # Prepend a priority marker for highest-weight senders (CEO / MD)
    priority_banner = ""
    if sender and sender_weights:
        sender_lower = sender.lower()
        for key, level in sender_weights.items():
            if key.lower() in sender_lower and level == "Highest":
                priority_banner = f"<!-- ⚠ PRIORITY: {level} — from {key} -->\n"
                break
    separator = f"\n\n<!-- appended {datetime.now().strftime('%Y-%m-%d %H:%M')} -->\n\n"
    with open(path, "a", encoding="utf-8") as f:
        f.write(separator + priority_banner + entry + "\n")
    logger.info(f"Appended summary to {path.name}")


def _parse_email_date(date_str: str):
    """Convert RFC 2822 email Date header to Python datetime for Excel; fall back to raw string."""
    if not date_str:
        return ""
    try:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(date_str).replace(tzinfo=None)
    except Exception:
        return date_str


def write_excel_row(excel_path: str, row: dict) -> None:
    """Append one task row to the Excel task log, creating the file + header if new."""
    try:
        from openpyxl import load_workbook, Workbook
        from openpyxl.styles import Alignment
    except ImportError:
        logger.warning("openpyxl not installed — skipping Excel output")
        return
    path = Path(excel_path)
    if path.exists():
        wb = load_workbook(path)
        ws = wb.active
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        wb = Workbook()
        ws = wb.active
        ws.append(["Date", "From", "Subject", "Priority", "Task Summary", "Description", "Jira Key"])
        # Column widths
        ws.column_dimensions["A"].width = 18   # Date
        ws.column_dimensions["B"].width = 28   # From
        ws.column_dimensions["C"].width = 40   # Subject
        ws.column_dimensions["D"].width = 10   # Priority
        ws.column_dimensions["E"].width = 45   # Task Summary
        ws.column_dimensions["F"].width = 55   # Description
        ws.column_dimensions["G"].width = 12   # Jira Key
    ws.append([
        _parse_email_date(row.get("date", "")),
        row.get("sender", ""),
        row.get("subject", ""),
        row.get("priority", ""),
        row.get("summary", ""),
        row.get("description", ""),
        row.get("jira_key", ""),
    ])
    # Wrap text in description cell
    last_row = ws.max_row
    ws.cell(last_row, 6).alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[last_row].height = 40
    wb.save(path)
    logger.info(f"Excel row written → {path.name}")


EPIC_TO_MODULE: dict[str, tuple[str, str, str]] = {
    "M01 PR Form":         ("M01 Purchase Requisition", "PR Entry Form",           "§3.1"),
    "PR Form":             ("M01 Purchase Requisition", "PR Entry Form",           "§3.1"),
    "M01 PR Amendment":    ("M01 Purchase Requisition", "PR Amendment",            "§3.4"),
    "PR Amendment":        ("M01 Purchase Requisition", "PR Amendment",            "§3.4"),
    "M01 PR Cancellation": ("M01 Purchase Requisition", "PR Cancellation",         "§3.5"),
    "PR Cancellation":     ("M01 Purchase Requisition", "PR Cancellation",         "§3.5"),
    "M01 PR Foreclosure":  ("M01 Purchase Requisition", "PR Foreclosure",          "§3.6"),
    "PR Foreclosure":      ("M01 Purchase Requisition", "PR Foreclosure",          "§3.6"),
    "M01 PR Approval":     ("M01 Purchase Requisition", "PR First Level Approval", "§3.2"),
    "PR Approval":         ("M01 Purchase Requisition", "PR First Level Approval", "§3.2"),
    "M02 RMI":             ("M02 RMI Purchase Order",   "RMI PO Entry",            "§2.1"),
    "M03 Sales":           ("M03 Sales",                "Sales Module",            "§?"),
    "M04 HR":              ("M04 HR",                   "HR Module",               "§?"),
}


def append_claude_prompt(prompt_dir: Path, date_str: str, task: dict,
                         subject: str, sender: str) -> None:
    """Append a structured PROMPT_01-style brief to today's prompt_YYYYMMDD.md."""
    prompt_dir.mkdir(parents=True, exist_ok=True)
    filename = f"prompt_{datetime.now().strftime('%Y%m%d')}.md"
    dest = prompt_dir / filename

    epic = task.get("epic_hint", "")
    module_name, feature_name, fsd_ref = EPIC_TO_MODULE.get(epic, (epic or "Unknown Module", "Feature", "§?"))
    action      = task.get("description") or task.get("summary", "")
    priority    = task.get("priority", "Medium")
    issue_type  = task.get("issue_type", "Task")

    entry = (
        f"\n---\n\n"
        f"## [{priority}] {task.get('summary', 'Untitled Task')}\n\n"
        f"**Source:** {subject}  \n"
        f"**From:** {sender}  \n"
        f"**Date:** {date_str}  \n"
        f"**Type:** {issue_type} | **Module:** {module_name} | **FSD:** {fsd_ref}\n\n"
        f"### Paste into Claude Code\n\n"
        f"```\n"
        f"Read @CLAUDE.md\n"
        f"Read @Docs/FSD_[module].md — {fsd_ref}\n\n"
        f"Module: {module_name}\n"
        f"Feature: {feature_name} — {action}\n"
        f"FSD reference: {fsd_ref}\n\n"
        f"Build following PROMPT_01 clean architecture flow:\n"
        f"Controller → Service → Repository → Stored Procedure\n"
        f"```\n"
    )
    with open(dest, "a", encoding="utf-8") as f:
        f.write(entry)
    logger.info(f"Claude prompt appended → {filename}")

# ─── MBOX Processor ──────────────────────────────────────────────────────────

class MboxProcessor:
    def __init__(self, cfg: dict, state: dict, ai: AIClient,
                 jira: Optional[JiraClient], offset_key: str = "mbox_offset",
                 collected_tasks: Optional[list] = None) -> None:
        self.cfg             = cfg
        self.state           = state
        self.ai              = ai
        self.jira            = jira
        self.offset_key      = offset_key
        self.collected_tasks = collected_tasks
        self.path            = Path(cfg["thunderbird_path"] if offset_key == "mbox_offset"
                                   else cfg["sent_path"])

    def run(self) -> None:
        if not self.path.exists():
            logger.warning(f"MBOX not found: {self.path}")
            return

        current_size = self.path.stat().st_size
        last_offset  = self.state.get(self.offset_key, -1)

        if last_offset == -1:
            if self.cfg.get("skip_existing_on_first_run", True):
                logger.info(f"First run — skipping existing messages in {self.path.name}.")
                self.state[self.offset_key] = current_size
                save_state(self.state)
                return
            else:
                last_offset = 0

        if current_size == last_offset:
            return

        processed = set(self.state.get("processed_ids", []))
        new_count  = 0

        try:
            mbox = mailbox.mbox(str(self.path))
            for msg in mbox:
                mid = stable_id(msg)
                if mid in processed:
                    continue
                processed.add(mid)
                subject = decode_header(msg.get("Subject", "(no subject)"))
                logger.info(f"Processing: {subject}")
                process_email(self.ai, msg, self.cfg, self.state, self.jira, self.collected_tasks)
                new_count += 1
            mbox.close()
        except Exception as e:
            logger.error(f"Failed reading MBOX {self.path.name}: {e}")
            return

        self.state[self.offset_key]  = current_size
        self.state["processed_ids"]  = list(processed)
        save_state(self.state)

        if new_count:
            logger.info(f"Processed {new_count} new message(s) from {self.path.name}")

# ─── Watchdog Handlers ───────────────────────────────────────────────────────

class MboxChangeHandler(FileSystemEventHandler):
    def __init__(self, processor: MboxProcessor, mbox_name: str) -> None:
        super().__init__()
        self.processor = processor
        self.mbox_name = mbox_name

    def on_modified(self, event) -> None:
        if not event.is_directory and Path(event.src_path).name == self.mbox_name:
            self.processor.run()

    def on_created(self, event) -> None:
        if not event.is_directory and Path(event.src_path).name == self.mbox_name:
            self.processor.run()


class EmlFolderHandler(FileSystemEventHandler):
    def __init__(self, cfg: dict, state: dict, ai: AIClient,
                 jira: Optional[JiraClient]) -> None:
        super().__init__()
        self.cfg           = cfg
        self.state         = state
        self.ai            = ai
        self.jira          = jira
        self.processed_ids = set(state.get("processed_ids", []))

    def on_created(self, event) -> None:
        if event.is_directory:
            return
        path = Path(event.src_path)
        if path.suffix.lower() not in (".eml", ""):
            return
        time.sleep(0.3)
        self._handle_file(path)

    def _handle_file(self, path: Path) -> None:
        try:
            with open(path, "rb") as f:
                msg = email.message_from_bytes(f.read())
        except Exception as e:
            logger.error(f"Cannot read {path}: {e}")
            return

        mid = stable_id(msg)
        if mid in self.processed_ids:
            return

        self.processed_ids.add(mid)
        self.state["processed_ids"] = list(self.processed_ids)
        save_state(self.state)

        subject = decode_header(msg.get("Subject", "(no subject)"))
        logger.info(f"New .eml: {subject}")
        process_email(self.ai, msg, self.cfg, self.state, self.jira)

# ─── Morning Brief & One-Shot Mode ───────────────────────────────────────────

_PRIORITY_ORDER = ["Highest", "High", "Medium", "Low"]
_PRIORITY_EMOJI = {"Highest": "🔴", "High": "🟠", "Medium": "🟡", "Low": "🟢"}


def generate_morning_brief(cfg: dict, tasks: list[dict]) -> Optional[Path]:
    """Write a markdown morning brief from tasks collected in this run."""
    if not tasks:
        logger.info("Morning brief: no tasks collected — skipping.")
        return None

    output_dir = Path(cfg.get("prompt_output_dir", str(BASE_DIR)))
    output_dir.mkdir(parents=True, exist_ok=True)
    dest = output_dir / f"morning_brief_{datetime.now().strftime('%Y%m%d')}.md"

    today   = datetime.now().strftime("%d %b %Y")
    now_str = datetime.now().strftime("%H:%M")
    sources = len(set(t.get("subject", "") for t in tasks))

    grouped: dict[str, list] = {p: [] for p in _PRIORITY_ORDER}
    for t in tasks:
        grouped.setdefault(t.get("priority", "Medium"), []).append(t)

    lines: list[str] = [
        f"# Morning Brief — {today}",
        f"**Generated:** {now_str} IST  |  **New Tasks:** {len(tasks)}  |  **Emails:** {sources}",
        "",
    ]
    for pri in _PRIORITY_ORDER:
        bucket = grouped.get(pri, [])
        if not bucket:
            continue
        emoji = _PRIORITY_EMOJI.get(pri, "⚪")
        lines += [f"## {emoji} {pri} ({len(bucket)})", ""]
        for task in bucket:
            epic = task.get("epic_hint", "")
            mod  = EPIC_TO_MODULE.get(epic, (epic or "General", "", ""))[0]
            lines += [
                f"### {task.get('summary', 'Untitled')}",
                f"**Module:** {mod}  |  **Due:** {task.get('due_date') or '—'}  |  **From:** {task.get('sender', '—')}",
            ]
            if task.get("description"):
                lines.append(f"> {task['description']}")
            if task.get("jira_key"):
                lines.append(f"**Jira:** `{task['jira_key']}`")
            if task.get("subject"):
                lines.append(f"_Source: {task['subject']}_")
            lines.append("")
        lines.append("")

    lines += ["---", ""]
    prompt_file = output_dir / f"prompt_{datetime.now().strftime('%Y%m%d')}.md"
    if prompt_file.exists():
        lines += [
            f"**Claude Code prompts:** `{prompt_file}`",
            "Paste the relevant prompt into Claude Code to begin work.",
        ]

    dest.write_text("\n".join(lines), encoding="utf-8")
    logger.info(f"Morning brief → {dest}")
    print(f"\nMorning brief: {dest}")
    return dest


def run_once(cfg: dict, ai: AIClient, state: dict, jira: Optional[JiraClient],
             morning_brief: bool = False) -> None:
    """Process all new emails once and exit — no file watcher started."""
    collected: Optional[list] = [] if morning_brief else None

    # Process INBOX
    inbox_proc = MboxProcessor(cfg, state, ai, jira,
                               offset_key="mbox_offset",
                               collected_tasks=collected)
    inbox_proc.run()

    # Process Sent (optional)
    sent_path = cfg.get("sent_path", "")
    if sent_path and Path(sent_path).exists():
        sent_cfg  = {**cfg, "thunderbird_path": sent_path}
        sent_proc = MboxProcessor(sent_cfg, state, ai, jira,
                                  offset_key="sent_mbox_offset",
                                  collected_tasks=collected)
        sent_proc.path = Path(sent_path)
        sent_proc.run()

    if morning_brief and collected is not None:
        generate_morning_brief(cfg, collected)

    logger.info("Run-once complete.")


# ─── Main ────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Spinrise Email Agent")
    parser.add_argument("--run-once", action="store_true",
                        help="Process new emails once and exit (no file watcher)")
    parser.add_argument("--morning-brief", action="store_true",
                        help="Generate a markdown morning brief after processing (implies --run-once)")
    args = parser.parse_args()

    cfg = load_config()
    setup_logging(cfg["log_file"])
    logger.info("=" * 60)
    logger.info(f"Spinrise Email Agent | provider={cfg['provider']} | jira={'ON' if cfg.get('jira_enabled') else 'OFF'}")
    logger.info(f"INBOX : {cfg['thunderbird_path']}")
    if cfg.get("sent_path"):
        logger.info(f"Sent  : {cfg['sent_path']}")
    logger.info(f"Output: {cfg['summary_file']}")
    logger.info("=" * 60)

    if not cfg["thunderbird_path"]:
        logger.error("thunderbird_path is not set in config.json")
        sys.exit(1)

    ai    = AIClient(cfg)
    state = load_state()
    jira  = JiraClient(cfg) if cfg.get("jira_enabled") and cfg.get("jira_token") else None
    if jira:
        logger.info(f"Jira: {cfg['jira_url']} | project={cfg['jira_project_key']}")

    # ── One-shot mode (no watcher) ────────────────────────────────────────────
    if args.run_once or args.morning_brief:
        run_once(cfg, ai, state, jira, morning_brief=args.morning_brief)
        return

    observer = Observer()

    # ── INBOX watcher ────────────────────────────────────────────────────────
    if cfg["watch_mode"] == "mbox":
        inbox_path = Path(cfg["thunderbird_path"])
        inbox_proc = MboxProcessor(cfg, state, ai, jira, offset_key="mbox_offset")
        inbox_proc.run()
        inbox_handler = MboxChangeHandler(inbox_proc, inbox_path.name)
        observer.schedule(inbox_handler, str(inbox_path.parent), recursive=False)
        logger.info(f"Watching INBOX: {inbox_path.name}")
    else:
        folder_path = cfg["thunderbird_path"]
        if not Path(folder_path).is_dir():
            logger.error(f"INBOX folder not found: {folder_path}")
            sys.exit(1)
        inbox_handler = EmlFolderHandler(cfg, state, ai, jira)
        for p in sorted(Path(folder_path).iterdir()):
            if p.suffix.lower() in (".eml", ""):
                inbox_handler._handle_file(p)
        observer.schedule(inbox_handler, folder_path, recursive=False)
        logger.info(f"Watching INBOX folder: {folder_path}")

    # ── Sent folder watcher (optional) ───────────────────────────────────────
    sent_path = cfg.get("sent_path", "")
    if sent_path:
        sent_mode = cfg.get("sent_watch_mode", "mbox")
        if sent_mode == "mbox":
            sent_mbox = Path(sent_path)
            if sent_mbox.exists():
                # Use a temporary cfg copy with thunderbird_path pointing to Sent
                sent_cfg = {**cfg, "thunderbird_path": sent_path}
                sent_proc = MboxProcessor(sent_cfg, state, ai, jira, offset_key="sent_mbox_offset")
                sent_proc.path = sent_mbox
                sent_proc.run()
                sent_handler = MboxChangeHandler(sent_proc, sent_mbox.name)
                observer.schedule(sent_handler, str(sent_mbox.parent), recursive=False)
                logger.info(f"Watching Sent : {sent_mbox.name}")
            else:
                logger.warning(f"Sent MBOX not found: {sent_path}")
        else:
            if Path(sent_path).is_dir():
                sent_handler = EmlFolderHandler(cfg, state, ai, jira)
                for p in sorted(Path(sent_path).iterdir()):
                    if p.suffix.lower() in (".eml", ""):
                        sent_handler._handle_file(p)
                observer.schedule(sent_handler, sent_path, recursive=False)
                logger.info(f"Watching Sent folder: {sent_path}")

    observer.start()
    logger.info("Running. Press Ctrl+C to stop.")

    try:
        while observer.is_alive():
            time.sleep(2)
    except KeyboardInterrupt:
        logger.info("Shutting down.")
    finally:
        observer.stop()
        observer.join()
    logger.info("Stopped.")


if __name__ == "__main__":
    main()
