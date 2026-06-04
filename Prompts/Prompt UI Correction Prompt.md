 ---
  UI/UX CORRECTION — [Module Name] — First-Level Approval
  ══════════════════════════════════════════════════════════
  Date        : [DD MMM YYYY]
  Module      : [e.g., M01 — Purchase Requisition]
  Screen/Page : [e.g., PR Form — Header Section]
  Blueprint   : [Blueprint filename or "Attached"]
  Reviewer    : [Name / Role]
  ══════════════════════════════════════════════════════════

  ## Correction Items

  For each item, fill the table below:

  | # | Screen / Component | Element | Current Behaviour | Required Behaviour | Category |
  |---|--------------------|---------|-------------------|--------------------|----------|
  | 1 | [e.g., PR Header]  | [e.g., Department dropdown] | [what it does now] | [what it must do] | Cosmetic / Functional |
  | 2 |                    |         |                   |                    |          |

  ## Instructions to Claude

  Apply the corrections above. For each item:

  1. Classify — Cosmetic (label/colour/spacing/font) or Functional
     (logic/validation/field/API/workflow).

  2. Cosmetic → fix inline.
     Commit format: `Fix [IST-REF or UI-C##]: [what changed] in [file] at [line]`

  3. Functional → do NOT fix. Raise a CR Document instead:
     CR Document
     ──────────────────────────────────────
     UI Correction Ref : UI-F[nn]
     FSD Section       : Section [x.x]
     Current Behaviour : [one sentence]
     Required Behaviour: [one sentence]
     ──────────────────────────────────────

  4. After applying all cosmetic fixes, provide:
     - Files changed with line references
     - List of any functional items raised as CRs (no code written)
     - Open questions (if any) before proceeding

  Do NOT assume any business rule. If a correction is ambiguous → STOP and ask.
  ══════════════════════════════════════════════════════════