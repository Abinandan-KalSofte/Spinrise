# PROMPT_04 — Session Startup Checklist
**Use at the start of every dev session to orient Claude and resume work.**
No placeholders needed — paths and names are pre-filled.

---

## Context load

```
Read @CLAUDE.md for project memory and all coding rules.
Read @Docs/ChangeLog/[YYYY-MM-DD]_session_[topic].md   ← yesterday's work log
Read @Docs/MODULE_TRACKER.md                            ← module progress
```

---

## Task

You are my senior .NET + React architect and Chief of Staff for Spinrise ERP V2.

Today is **[DD MMM YYYY]**. Run the session startup checklist and report back before accepting any new task.

---

## Startup checklist

### 1 — Git status

```bash
git status
git log --oneline -10
```

Report:
- Current branch
- Uncommitted changes (list files)
- Commits ahead of `feature/m01-pr`
- Any stray files or untracked items needing attention

### 2 — Prior session WIP

Read the most recent worklog in `Docs/ChangeLog/`.

Report:
- Tasks completed last session
- Tasks left in progress
- Any blockers noted
- Open questions awaiting answers

### 3 — Open IST / CR items

From the worklog or MODULE_TRACKER.md, list:

| # | Ref | Description | Status | Blocker |
|---|---|---|---|---|
| 1 | IST-F[nn] | [description] | Open / In Progress / Resolved | [yes/no] |
| 2 | CR-[nn] | [description] | Open / In Progress / Resolved | [yes/no] |

### 4 — Today's plan

Suggest a prioritised task list for today based on:
- Open IST findings (Functional > Cosmetic)
- In-progress module work
- Any deadline from the email log (`Docs/Email/EmailSummary.md`)

Format:
```
Priority | Task | FSD Ref / IST Ref | Est. Effort
---------|------|-------------------|------------
Critical | [task] | IST-F[nn] | 30 min
High     | [task] | §4.2 | 2 hrs
Medium   | [task] | — | 1 hr
```

### 5 — Session header

Output the session header from CLAUDE.md:

```
SPINRISE SESSION START — [DD MMM YYYY] [HH:MM IST]
────────────────────────────────────────────
Role active         : [ ] Dev Architect  [ ] Chief of Staff  [ ] Both
FSD version in use  : [version / "not yet provided"]
UI/UX Blueprint     : [ ] Provided  [ ] Not yet provided
Active CR Documents : [list or "none"]
Open IST findings   : [list or "none"]
Prior session WIP   : [ ] Read — pending tasks noted
Git status          : [ ] Confirmed — no stray uncommitted changes
Work log file       : worklog_[YYYYMMDD].md — [ ] Created  [ ] Appended
────────────────────────────────────────────
Ready. Awaiting instruction.
```

---

## Work log

Create today's worklog at:
`Docs/ChangeLog/[YYYY-MM-DD]_session_[topic].md`

Use the standard format from CLAUDE.md (Session Work Log section).

---

## Hard rules

| Rule | Detail |
|---|---|
| Read worklog before advising | Never advise without checking yesterday's WIP |
| Absolute dates | All dates in `DD MMM YYYY` format |
| Confirm branch | Never start work on wrong branch — always check `git status` first |
| Ask before assuming | If worklog references a CR/FSD that isn't loaded, ask for it |
