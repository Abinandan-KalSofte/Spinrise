# Extract Tasks 
 ---
  TASK EXTRACTION — EMAIL BATCH
  ──────────────────────────────────────────────────────────
  You are a Chief of Staff assistant. Read the emails below and extract
  every actionable task. For each task output a structured row.

  EXTRACTION RULES:
  1. One row per task — do not merge separate actions into one row.
  2. Owner = the person named or implied as responsible (not the sender
     unless they are assigning themselves).
  3. Due = exact date if stated; "EoD [date]" if end-of-day; "ASAP" if
     urgent but undated; "—" if no date given.
  4. Priority = Critical / High / Medium / Low using this guide:
       Critical — blocks pilot/release or CEO explicitly marked urgent
       High     — due today or directly impacts another person's work
       Medium   — due this week, no immediate blocker
       Low      — no deadline, informational follow-up
  5. Source = email subject line (abbreviated to ≤ 50 chars if needed).
  6. If an email contains ZERO tasks, skip it — do not output a blank row.
  7. If a task was already listed in a prior email in the batch, do not
     duplicate it — mark it "Carried forward" in Notes.

  OUTPUT FORMAT (markdown table):
  | # | Priority | Owner | Task | Due | Source (Subject) | Notes |
  |---|----------|-------|------|-----|------------------|-------|

  After the table output a one-line SUMMARY:
    Total tasks: N  |  Critical: N  |  High: N  |  Medium: N  |  Low: N

  ──────────────────────────────────────────────────────────
  Email summary available here 
  "D:\Spinrise\Docs\Email\EmailSummary.md"