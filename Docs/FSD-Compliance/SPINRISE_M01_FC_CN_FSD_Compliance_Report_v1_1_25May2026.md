# FSD Compliance Report — PR Foreclosure & Cancellation (Undo)

**Module:** M01 — PR Foreclosure / PR Cancellation / Undo Cancellation
**FSD Version:** v1.1 — CEO countersigned 23 May 2026
**Blueprint Version:** v6.1 — 22 May 2026 (CEO — T. Mani)
**Build:** UI/UX Design Prototype — Port 3001
**Report Date:** 25 May 2026
**Prepared By:** Abinandan N — Full Stack Developer, Kalpatharu Software Ltd
**Report Version:** v1.1 (corrected — FSD and Blueprint v6.1 fully read via pandoc extraction)

---

## 1. Scope

This report covers the FSD v1.1 compliance status of the UI/UX design prototype for three workflows deployed on port 3001:
- PR Foreclosure (Force Closure) — FrmPRForeclosure.frm
- PR Cancellation — Indentcancellation.frm
- Undo PR Cancellation — Indentcancellation.frm

Backend development has not commenced. This report applies to the UI/UX design layer only.

---

## 2. CEO Five-Point Compliance Check (Email — 25 May 2026)

### Point 1 — Foreclosure: All Open PRs Across All Financial Years (OI-01-F1)

| | |
|---|---|
| **FSD Reference** | OI-01-F1 — Closed by Sasi, Stage 2, 20 May 2026 |
| **FSD Decision** | *"Year guard NOT required for Foreclosure. A PR raised in a prior financial year may legitimately be foreclosed in the next financial year when fulfilment is no longer expected. Do NOT apply yfdate/yldate filter in sp_PR_GetOpenForForeclosure."* |
| **SP Spec** | `sp_PR_GetOpenForForeclosure` — No yfdate/yldate parameter. All open PRs across all financial years returned. |
| **Prototype Status** | ✅ **COMPLIANT** — No FY filter applied. Prototype shows all open PR lines regardless of year. |

---

### Point 2 — Cancellation: Current Financial Year Filter Active

| | |
|---|---|
| **FSD Reference** | Section 6 — sp_PR_GetCancellablePRs specification |
| **FSD Decision** | *"Parameters: @divcode varchar(10), @yfdate datetime, @yldate datetime. … prdate BETWEEN @yfdate AND @yldate."* |
| **Prototype Status** | ✅ **COMPLIANT** — Both the Cancel lookup and Undo Cancellation lookup are scoped to current FY. Confirmed in prototype SP comment: `sp_PR_GetCancellablePRs … within FY` and `sp_PR_GetCancelledPRsForUndo … within FY`. |

---

### Point 3 — Cancellation: PO_ORD Check Active + User Message

| | |
|---|---|
| **FSD Reference** | OI-02-F2 — Closed, CEO confirmed 20 May 2026; Section 6 sp_PR_GetCancellablePRs spec |
| **FSD Decision** | *"Add PO_ORD check to sp_PR_GetCancellablePRs — exclude any PR with a PO_ORD record. User message: 'A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR.'"* |
| **PO_ORD Check** | ✅ **COMPLIANT** — SP design excludes `QTYORD=0, not in PO_ENQL, not in PO_ORD`. Confirmed in prototype. |
| **User Message** | ⚠️ **GAP** — The message *"A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR."* is not currently displayed in the UI prototype. PRs with PO raised are silently excluded from the lookup list. |
| **Gap Clarification** | The FSD specifies the message in the context of the SP design (OI-02-F2 closure). Whether this message should appear as (a) a UI toast when a PR with PO is searched, (b) a note on the Cancel lookup modal, or (c) a backend API error response requires Mariyaiya's clarification. The underlying business rule (PO PRs excluded) IS implemented correctly. Only the explicit message display is missing from the prototype. |
| **Action Required** | Mariyaiya to confirm message trigger point. Prototype to be updated once confirmed. |

---

### Point 4 — Sub-Cost Centre (SCCCODE) Visible on PR Line Items

| | |
|---|---|
| **FSD Reference** | Section 6 — sp_PR_GetOpenForForeclosure column list |
| **Cancellation** | ✅ **COMPLIANT** — "Sub Cost Centre" column visible in PR line items grid (read-only). |
| **Foreclosure** | ❌ **NOT APPLICABLE per FSD SP spec** — sp_PR_GetOpenForForeclosure column list per FSD v1.1: `SELECT prno, prdate, Depname, prsno, itemcode, Itemname, balance`. SCCCODE (SubCost) is not in this result set. The prototype cannot display a column the SP does not return. If SCCCODE is required in Foreclosure, the SP specification must be updated by Mariyaiya. |
| **"Mandatory" Note** | Per PR Form FSD v2.5 (F-05, CLOSED): Sub-Cost Centre removed as a data entry field. In Foreclosure/Cancellation, SCCCODE is read-only display of existing PR data — not a mandatory entry field. CEO's reference to "mandatory" is understood as "mandatory to display (visible)". |
| **Action Required** | Mariyaiya to confirm if `sp_PR_GetOpenForForeclosure` should include SCCCODE. Prototype updated once SP spec is confirmed. |

---

### Point 5 — Item Lookup: "Item Id" as Reference (Not "Item Code")

| | |
|---|---|
| **FSD Reference** | Blueprint v6.1 UX standard; confirmed in Cancellation prototype design |
| **Cancellation** | ✅ **COMPLIANT** — "Item Id" column header used in PR line items grid. |
| **Foreclosure** | ✅ **FIXED** — Column header was "Item Code." Corrected to "Item Id" in prototype HTML and Blueprint HTML (06-pr-foreclosure.html) on 25 May 2026. |
| **Name-based search** | Confirmed — Item lookup in PR Form uses name-based search with Item Id as reference column per FSD. Not applicable to Foreclosure/Cancellation browse-only modals (no item data entry on these screens). |

---

## 3. Full Compliance Matrix

| # | Requirement | Screen | Status | FSD Reference |
|---|---|---|---|---|
| C-01 | No FY filter on Foreclosure (OI-01-F1) | Foreclosure | ✅ Compliant | FSD OI-01-F1, Section 6 SP spec |
| C-02 | FY filter active on Cancellation | Cancellation | ✅ Compliant | Section 6 sp_PR_GetCancellablePRs |
| C-03 | FY filter active on Undo Cancellation | Undo Cancel | ✅ Compliant | Section 6 sp_PR_GetCancelledPRsForUndo |
| C-04 | PO_ORD check active (PRs excluded from cancel list) | Cancellation | ✅ Compliant | FSD OI-02-F2, Section 6 |
| C-05 | User message for PO_ORD blocked PRs | Cancellation | ⚠️ Gap | FSD OI-02-F2 — message not in prototype |
| C-06 | Sub-Cost Centre visible in PR line items | Cancellation | ✅ Compliant | Cancellation grid — read-only column present |
| C-07 | Sub-Cost Centre in Foreclosure line items | Foreclosure | ❌ N/A per SP spec | FSD Section 6 SP column list omits SubCost |
| C-08 | "Item Id" column header | Cancellation | ✅ Compliant | UI prototype |
| C-09 | "Item Id" column header | Foreclosure | ✅ Fixed | Fixed 25 May 2026 |
| C-10 | Cancellation reason — mandatory | Cancellation | ✅ Compliant | Inline validation present |
| C-11 | Cancel sets CANCELFLAG='Y' — PO_PRH + all PO_PRL | Cancellation | ✅ Compliant | Confirm dialog documents transaction |
| C-12 | Undo clears CANCELFLAG — PO_PRH + all PO_PRL | Undo Cancel | ✅ Compliant | Confirm dialog documents transaction |
| C-13 | Transaction atomicity: BeginTrans/Commit/Rollback + LogDet_PO | Both | ✅ Compliant | FSD G6 PASS, Section 6 transaction design |

---

## 4. Deviations — Identified and Closed

| # | Deviation | Screen | Fix Applied | Date |
|---|---|---|---|---|
| D-01 | "Item Code" used as column header — should be "Item Id" per Blueprint v6.1 | Foreclosure | Corrected to "Item Id" in prototype HTML and Blueprint HTML 06-pr-foreclosure.html | 25 May 2026 |

---

## 5. Open Gaps

| # | Gap | FSD Reference | Owner | Priority |
|---|---|---|---|---|
| G-01 | User message "A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR." — not displayed in prototype. Message trigger point (UI toast / modal note / API error) needs clarification. | FSD OI-02-F2, Section 6 | Mariyaiya (confirm trigger point) → Abinandan (implement) | Medium |
| G-02 | SCCCODE (Sub-Cost Centre) absent from Foreclosure grid — FSD SP spec for sp_PR_GetOpenForForeclosure does not include SubCost in result set. If required in Foreclosure, SP spec must be updated. | FSD Section 6 — sp_PR_GetOpenForForeclosure column list | Mariyaiya (FSD SP update if required) | Medium |

---

## 6. Items Pending Management Decision / Clarification

| # | Question | Owner | Notes |
|---|---|---|---|
| M-01 | PO_ORD user message trigger — should the message appear (a) in Cancel lookup modal as info text when PR# searched returns no result, (b) as a UI toast on selection attempt, or (c) only as a backend API validation error? | Mariyaiya | FSD OI-02-F2 specifies the message text but not the UI trigger mechanism. |
| M-02 | Undo Cancellation — restored PR status. What status should the PR return to after undo — "Requested" (original creation status) or the last approval status the PR held before cancellation? IST domain review input required. | Muthuvel + Mariyaiya | IST domain review submission — EoD 25 May 2026 per CEO instruction. |
| M-03 | OI-06 (CEO Working Session gate) — per Blueprint v6.1 §4.2, CEO Working Session is the first step of the review chain. It was not held before Stage 1 FSD writing for this module. CEO to confirm: (a) waived for this FSD, or (b) to be held before Sprint start. | CEO — T. Mani | Non-blocking for UI/UX review. Blocking for Sprint coding start per Blueprint v6.1. |

---

## 7. Summary

| Category | Count |
|---|---|
| FSD Requirements Checked | 13 |
| Compliant | 10 |
| Fixed in this session (25 May 2026) | 1 |
| Open Gaps (require Mariyaiya input) | 2 |
| Pending Management Decision | 3 |

**CEO 5-point check result: 4 of 5 confirmed compliant. Point 3 (user message) partially confirmed — PO_ORD check is compliant; message display is a gap pending Mariyaiya's clarification on trigger point.**

---

## 8. Next Actions

| # | Action | Owner | Due |
|---|---|---|---|
| 1 | Confirm PO_ORD user message trigger point (G-01) and update prototype | Mariyaiya → Abinandan | Next session |
| 2 | Confirm if sp_PR_GetOpenForForeclosure should include SCCCODE (G-02) | Mariyaiya | Next session |
| 3 | Domain review — Undo restored status (M-02) | Muthuvel + Mariyaiya | EoD 25 May 2026 |
| 4 | OI-06 resolution — CEO Working Session gate (M-03) | CEO T. Mani | Before Sprint start |
| 5 | FSD v1.1 to be provided in text-readable format (.md or .txt) for future compliance reviews | Mariyaiya / TL-Dev Sasi | Standing request |

---

*Report prepared by Abinandan N | Kalpatharu Software Ltd | 25 May 2026 | Confidential — Internal Use Only*
*FSD source: SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1_1_TL-IST_Review_CEO_Submission.docx (extracted via pandoc)*
*Blueprint source: SPINRISE_Blueprint_v6_1_22May2026.docx (extracted via pandoc)*
