"""
Tests Jira push directly with hardcoded tasks — bypasses AI (used when Gemini quota exhausted).
"""
from email_agent import load_config, JiraClient

cfg  = load_config()
jira = JiraClient(cfg)

# Simulate tasks that the AI would have extracted from a CEO email
TEST_TASKS = [
    {
        "summary":    "Implement Rate Source selector — LPO / Average / Manual (pilot-blocking)",
        "issue_type": "Bug",
        "priority":   "Highest",
        "description": "CEO directive 21 May: Rate Source selector missing from item grid. Deploy to 172.16.16.40:3000 by 22 May EOD.",
        "epic_hint":  "M01 PR Form",
        "due_date":   "2026-05-22",
    },
    {
        "summary":    "Fix printed PR — requester employee name missing from QuestPDF template",
        "issue_type": "Bug",
        "priority":   "High",
        "description": "CEO directive 21 May: PR_EMP.ENAME not rendered on printed PR document. Map from API response.",
        "epic_hint":  "M01 PR Form",
        "due_date":   "2026-05-22",
    },
    {
        "summary":    "Include build number in EOD progress mail",
        "issue_type": "Task",
        "priority":   "Medium",
        "description": "CEO directive 21 May: EOD mail must include deployment build number from now on.",
        "epic_hint":  "Governance",
        "due_date":   None,
    },
]

print(f"\n{'='*60}")
print("JIRA PUSH TEST — bypassing AI (Gemini quota exhausted)")
print(f"{'='*60}\n")

for task in TEST_TASKS:
    summary = task["summary"]
    if jira.issue_exists_by_summary(summary):
        print(f"  SKIP (exists): {summary[:60]}")
        continue
    epic_key = jira.resolve_epic(task["epic_hint"])
    key = jira.create_issue(
        summary    = summary,
        issue_type = task["issue_type"],
        priority   = task["priority"],
        description= task["description"],
        epic_key   = epic_key,
        due_date   = task["due_date"],
    )
    status = f"CREATED {key} (epic={epic_key})" if key else "FAILED"
    print(f"  {status}: {summary[:60]}")

print(f"\nDone. Board: https://kalsofte.atlassian.net/jira/software/projects/SPIN/boards/34\n")
