# FSD Compliance Report — PR Foreclosure & Cancellation (Undo)
**Module:** M01 — Purchase Requisition (Foreclosure / Cancellation / Undo Cancellation)
**FSD Version:** v1.1 — CEO countersigned 23 May 2026
**Blueprint Version:** v6.1 — 22 May 2026
**Build:** UI/UX Design Prototype — Port 3001
**Report Date:** 25 May 2026
**Prepared By:** Abinandan N — Full Stack Developer, Kalpatharu Software Ltd

---

## 1. Scope

This report covers the FSD v1.1 compliance status of the UI/UX design prototype for three workflows:
- PR Foreclosure (Force Closure)
- PR Cancellation
- Undo PR Cancellation

Backend development has not yet commenced. This report applies to the UI/UX design layer only.

---

## 2. Compliance Matrix

| # | FSD / Blueprint Requirement | Screen | Status | Evidence | Notes |
|---|---|---|---|---|---|
| C-01 | Foreclosure shows ALL open PRs across all financial years — no FY date filter (OI-01-F1) | Foreclosure | ⚠ CANNOT VERIFY | Blueprint v6.1 (.docx) not accessible in text format | Deferred to Muthuvel (IST) and Mariyaiya (Module Owner) |
| C-02 | Cancellation filters PRs by current financial year only — year guard active | Cancellation | ✅ COMPLIANT | Prototype comment: `sp_PR_GetCancellablePRs … within FY` | Enforced in SP query design |
| C-03 | Undo Cancellation restricted to current financial year | Undo Cancellation | ✅ COMPLIANT | Prototype comment: `sp_PR_GetCancelledPRsForUndo … within FY` | Same year guard applied |
| C-04 | Cancellation excludes PRs with PO raised (PO_ORD check active) | Cancellation | ✅ COMPLIANT | Prototype SP comment: `QTYORD=0, not in PO_ENQL, not in PO_ORD` | Exclusion at query level — see Gap G-01 |
| C-05 | Sub-Cost Centre (SCCCODE) visible on PR line items — Cancellation | Cancellation | ✅ COMPLIANT | "Sub Cost Centre" column present in PR line items grid (read-only) | Display only — not entry field (per F-05) |
| C-06 | Sub-Cost Centre (SCCCODE) visible on PR line items — Foreclosure | Foreclosure | ❌ GAP | Column not present in Foreclosure line items grid | Deferred to Mariyaiya — see Gap G-02 |
| C-07 | Item column header uses "Item Id" (not "Item Code") per Blueprint v6.1 UX standard | Cancellation | ✅ COMPLIANT | "Item Id" used in PR line items grid header | Verified in prototype and Blueprint HTML |
| C-08 | Item column header uses "Item Id" (not "Item Code") per Blueprint v6.1 UX standard | Foreclosure | ✅ FIXED | Was "Item Code" — corrected to "Item Id" in this session (25 May 2026) | Applied to prototype (port 3001) and Blueprint HTML |
| C-09 | Cancellation reason field — mandatory entry before save | Cancellation | ✅ COMPLIANT | `required` validation + inline error message in prototype | "Cancellation Reason" marked mandatory with inline `⚠` message |
| C-10 | Cancelled PR — sets CANCELFLAG = 'Y' on PO_PRH and all PO_PRL lines | Cancellation | ✅ COMPLIANT | Confirm dialog text documents the transaction sequence explicitly | UI design reflects correct SP transaction |
| C-11 | Undo restores PR — clears CANCELFLAG on PO_PRH and PO_PRL | Undo Cancellation | ✅ COMPLIANT | Confirm dialog text documents the transaction sequence explicitly | Restore sequence per FSD design |

---

## 3. Deviations Identified and Closed

| # | Deviation | Screen | Discovery | Fix Applied | Fix Date |
|---|---|---|---|---|---|
| D-01 | "Item Code" used as column header — should be "Item Id" per Blueprint v6.1 | Foreclosure | This compliance review, 25 May 2026 | Corrected to "Item Id" in prototype HTML and Blueprint HTML (06-pr-foreclosure.html) | 25 May 2026 |

---

## 4. Open Gaps

| # | Gap | Screen | Reason Not Resolved | Owner | Priority |
|---|---|---|---|---|---|
| G-01 | User message "A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR." — Current prototype excludes these PRs silently (query filter). FSD v1.1 (.docx) not readable to confirm whether an explicit on-screen message is additionally required. | Cancellation | FSD v1.1 accessible only in .docx format | Muthuvel (IST domain review) + Mariyaiya (Module Owner) | Medium |
| G-02 | Sub-Cost Centre (SCCCODE) column absent from Foreclosure line items grid. Present in Cancellation (read-only). FSD v1.1 to confirm if required in Foreclosure. | Foreclosure | Pending Mariyaiya FSD v1.1 confirmation | Mariyaiya (Module Owner) | Medium |
| G-03 | Foreclosure FY filter (OI-01-F1 decision) — whether Foreclosure shows ALL FYs or current FY only. Blueprint v6.1 (.docx) not accessible to verify. | Foreclosure | Blueprint v6.1 accessible only in .docx format | Muthuvel (IST domain review) + Mariyaiya (Module Owner) | High |

---

## 5. Items Pending Management Decision

| # | Question | Screen | Raised By | Status |
|---|---|---|---|---|
| M-01 | Sub-Cost Centre (SCCCODE) — CEO email refers to it as a "mandatory" field. Per FSD v2.5 (F-05, CLOSED), SCCCODE was removed from PR Form data entry. In Foreclosure/Cancellation, it is a read-only display column from existing PR data. Clarification needed: "mandatory to display" (read-only column) vs "mandatory entry" (contradicts F-05). | Foreclosure / Cancellation | This compliance review | Awaiting CEO / Mariyaiya clarification |
| M-02 | Undo Cancellation — restored PR status. What status should a PR return to after undo — "Requested" (original entry status) or the last approval status the PR held before cancellation? This is a domain decision. | Undo Cancellation | CEO email to IST team | Deferred to Muthuvel and Mariyaiya — domain review submission by EoD 25 May 2026 |

---

## 6. Summary

| Category | Count |
|---|---|
| FSD Requirements Checked | 11 |
| Compliant | 8 |
| Fixed in this session | 1 |
| Open Gaps (cannot resolve without FSD/Blueprint access) | 3 |
| Pending Management Decision | 2 |

**Overall Compliance: 8/11 confirmed compliant. 1 deviation corrected. 3 gaps require FSD v1.1 / Blueprint v6.1 text access or domain input from IST and Module Owner.**

---

## 7. Next Actions

| Action | Owner | Due |
|---|---|---|
| Confirm G-03: Foreclosure FY filter — OI-01-F1 per FSD v1.1 | Mariyaiya | ASAP |
| Confirm G-02: SCCCODE required in Foreclosure grid — FSD v1.1 Section ref | Mariyaiya | ASAP |
| Confirm G-01: PO_ORD — silent filter sufficient or explicit message required per FSD | Muthuvel + Mariyaiya | EoD 25 May 2026 |
| Confirm M-02: Undo restored status — Requested vs last approval status | Muthuvel + Mariyaiya | EoD 25 May 2026 |
| Provide FSD v1.1 in readable text format (.md or .txt) for future compliance checks | Mariyaiya / TL Dev | Next session |

---

*Report prepared by Abinandan N | Kalpatharu Software Ltd | 25 May 2026 | Confidential — Internal Use Only*
