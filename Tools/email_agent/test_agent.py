"""
End-to-end test for the email agent pipeline.
Creates a realistic SPINRISE CEO email, runs it through summarise + Jira extract + create.
"""
import json
import email
import email.utils
from datetime import datetime

# ── Load agent modules ──────────────────────────────────────────────────────
from email_agent import (
    load_config, AIClient, JiraClient,
    summarise_email, extract_jira_tasks,
)

# ── Build a realistic mock CEO email ────────────────────────────────────────
TEST_EMAIL_BODY = """\
Hi Abinandan,

After reviewing the PR Form session today, please action the following before tomorrow morning:

1. The Rate Source selector (LPO / Average / Manual) is still missing from the item grid.
   This is a pilot-blocking gap — implement and deploy to 172.16.16.40:3000 by 22 May EOD.

2. The printed PR document does not show the requester employee name.
   Fix the QuestPDF template to include PR_EMP.ENAME from the API response.

3. Update your daily EOD progress mail to include deployment build number from now on.

Pilot date is 30 May. No slippage.

T. Mani
CEO — Kalpatharu Software Ltd
"""

def build_mock_msg() -> email.message.Message:
    msg = email.message.Message()
    msg["Message-ID"] = f"<test-{datetime.now().strftime('%Y%m%d%H%M%S')}@kalsofte.com>"
    msg["From"]    = "T. Mani <ceo@kalsofte.com>"
    msg["To"]      = "Abinandan N <abinandan.n@kalsofte.com>"
    msg["Date"]    = email.utils.formatdate()
    msg["Subject"] = "PR Form — 3 action items before 22 May (pilot prep)"
    msg.set_payload(TEST_EMAIL_BODY)
    return msg


def main() -> None:
    cfg   = load_config()
    ai    = AIClient(cfg)
    jira  = JiraClient(cfg) if cfg.get("jira_enabled") and cfg.get("jira_token") else None

    msg = build_mock_msg()
    print(f"\n{'='*60}")
    print(f"TEST EMAIL")
    print(f"From   : {msg['From']}")
    print(f"Subject: {msg['Subject']}")
    print(f"{'='*60}\n")

    # Step 1 — Summarise
    print("STEP 1: Summarising email via AI...")
    summary = summarise_email(ai, msg)
    if summary:
        print(f"\nSummary generated:\n{summary}\n")
    else:
        print("No summary generated (SKIP)\n")

    # Step 2 — Extract Jira tasks
    print("STEP 2: Extracting Jira tasks via AI...")
    tasks = extract_jira_tasks(ai, msg)
    if not tasks:
        print("No Jira tasks extracted.\n")
    else:
        print(f"{len(tasks)} task(s) extracted:")
        for i, t in enumerate(tasks, 1):
            print(f"  [{i}] [{t.get('issue_type','Task')}] [{t.get('priority','Medium')}] {t.get('summary')}")
            print(f"       Epic hint: {t.get('epic_hint')} | Due: {t.get('due_date')}")
        print()

    # Step 3 — Push to Jira
    if jira and tasks:
        print("STEP 3: Creating Jira issues...")
        for task in tasks:
            summary_text = task.get("summary", "")
            if not summary_text:
                continue
            if jira.issue_exists_by_summary(summary_text):
                print(f"  SKIP (already exists): {summary_text}")
                continue
            epic_key = jira.resolve_epic(task.get("epic_hint", ""))
            key = jira.create_issue(
                summary    = summary_text,
                issue_type = task.get("issue_type", "Task"),
                priority   = task.get("priority", "Medium"),
                description= task.get("description", ""),
                epic_key   = epic_key,
                due_date   = task.get("due_date"),
            )
            if key:
                print(f"  CREATED {key} (epic={epic_key}): {summary_text}")
            else:
                print(f"  FAILED : {summary_text}")
    elif not jira:
        print("STEP 3: Jira disabled — skipping push.")

    print(f"\n{'='*60}")
    print("Test complete. Check https://kalsofte.atlassian.net/jira/software/projects/SPIN/boards/34")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
