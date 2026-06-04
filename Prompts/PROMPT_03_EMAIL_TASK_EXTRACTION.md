# PROMPT_03 — Morning Email Task Extraction
**Use every morning to parse overnight emails and produce an action list.**
No placeholders needed — paths are pre-filled for this machine.

---

## Context load

```
Read @CLAUDE.md — Chief of Staff role section.
```

---

## Task

You are my Chief of Staff for Spinrise ERP V2 project.

Parse today's unread emails from the Thunderbird INBOX, extract all action items, and produce a structured daily task list.

---

## Email sources (confirmed paths — do not ask)

| Source | Path |
|---|---|
| INBOX (mbox) | `C:\Users\Admin\AppData\Roaming\Thunderbird\Profiles\fjzej4xv.default-release\ImapMail\mail.kalsofte.com\INBOX` |
| Sent folder | `C:\Users\Admin\AppData\Roaming\Thunderbird\Profiles\fjzej4xv.default-release\ImapMail\mail.kalsofte.com\INBOX.sbd\Sent` |
| Email agent script | `D:\SpinriseV2\Tools\email_agent\email_agent.py` |
| Email agent config | `D:\SpinriseV2\Tools\email_agent\config.json` |
| Output summary (MD) | `D:\SpinriseV2\Docs\Email\EmailSummary.md` |
| Output tasks (Excel) | `D:\SpinriseV2\Docs\Email\EmailTasks.xlsx` |
| Attachments | `D:\SpinriseV2\Docs\Extracted\` |

**Run the agent:** `python D:\SpinriseV2\Tools\email_agent\email_agent.py`

---

## Sender priority weights

| Sender | Priority level |
|---|---|
| `ceo@kalsofte.com` | **Highest** — always process first |
| `md@kalsofte.com` | **Highest** — always process first |
| `qa@kalsofte.com` | **High** |
| Muthuvel (any address) | **High** |
| All others | Normal |

---

## Processing steps

### Step 1 — Run email agent

Run the email agent script to pull and parse the INBOX. If the script fails, note the error and proceed manually with the mbox file.

### Step 2 — Extract action items

For each email, extract:

- **From / Date / Subject**
- **Action items** — explicit asks, implicit tasks, decisions required, follow-ups
- **Attachments** — list filenames; note if extracted to `Docs/Extracted/`
- **Deadline** — explicit or implied; convert relative dates to absolute (`DD MMM YYYY`)

### Step 3 — Classify each item

| Category | Examples |
|---|---|
| **Dev task** | Build feature X, fix bug Y, deploy Z |
| **Reply required** | Approval needed, question asked, info requested |
| **Meeting / MOM** | Meeting scheduled, action items from MOM |
| **IST finding** | QA-flagged defect, UI correction |
| **Information only** | FYI emails — no action |

### Step 4 — Produce output

#### A) Email Summary Table

```
# Email Summary — [DD MMM YYYY]

| # | From | Subject | Summary | Action Required | Due |
|---|---|---|---|---|---|
| 1 | [sender] | [subject] | [2-line summary] | [Yes/No] | [date or —] |
```

#### B) Action Item Task List

```
# Action Items — [DD MMM YYYY]

Priority | Task | Source Email | Owner | Due | Status
---------|------|--------------|-------|-----|-------
Critical | [task] | [subject] | Abinandan | [date] | Open
High     | [task] | [subject] | Abinandan | [date] | Open
```

#### C) IST / CR items (if any)

List separately with IST reference number if present:

```
IST Findings from QA:
- IST-F[nn]: [description] — [Cosmetic / Functional] — [screen]
```

#### D) Reply drafts (if reply required)

Draft professional reply for each email that needs a response.
- Concise — no filler
- Sign off: "Regards, Abinandan"

---

## Output file

Append today's summary to `D:\SpinriseV2\Docs\Email\EmailSummary.md`.

Update `D:\SpinriseV2\Docs\Email\EmailTasks.xlsx` with new rows (one row per action item).

---

## Hard rules

| Rule | Detail |
|---|---|
| Absolute dates | Always convert "Thursday", "next week" etc. to `DD MMM YYYY` |
| CEO/MD first | Process highest-priority senders first, output at top |
| No assumed tasks | Only extract what the email explicitly or clearly implies |
| IST always Functional | When in doubt, classify as Functional — raise CR |
| Draft replies concisely | No padding, no "I hope this finds you well" filler |
| Attachments → Docs/Extracted | Note filename; do not embed content in summary |
