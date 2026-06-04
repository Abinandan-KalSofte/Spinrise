+----------------------------------------------------------------------------------------+
| **SPINRISE ERP**                                                                       |
|                                                                                        |
| Functional Specification Document                                                      |
|                                                                                        |
| **PR Foreclosure Entry + PR Cancellation Entry**                                       |
|                                                                                        |
| FrmPRForeclosure.frm + Indentcancellation.frm \| M01 Purchase Order Module \| FSD v1.1 |
+========================================================================================+

  --------------------------------------------------------------------------------------------------------------------------------------------
  **Document**             SPINRISE FSD --- PR Foreclosure Entry + PR Cancellation Entry (Combined)
  ------------------------ -------------------------------------------------------------------------------------------------------------------
  **Forms**                FrmPRForeclosure.frm (PR Foreclosure Entry) │ Indentcancellation.frm (PR Cancellation Entry) │ M01 Purchase Order

  **Blueprint Version**    Blueprint v6.0

  **FSD Version**          v1.1 (Both forms, single FSD --- all Blueprint v6 §4.3 sections complete)

  **Stage 0 Sign-off**     FULLY APPROVED --- 19 May 2026 │ TL-Dev: Sasi │ Both forms cleared │ No conditional sign-off

  **Current Stage**        STAGE 4 --- CEO Review │ T. Mani │ Target: 23 May 2026

  **Technology Stack**     React.js 18 + Ant Design Pro │ ASP.NET Core 8 Web API (C#) │ Dapper │ MS SQL Server 2019/2022 │ QuestPDF │ EPPlus

  **Review Chain**         Developer → TL-Dev Sasi (Stage 2) → TL-IST Palanivel (Stage 3) → CEO T. Mani (Stage 4)

  **Organisation**         Kalpatharu Software Ltd │ SPINRISE Migration │ Internal Confidential

  **Expert Review Date**   23 May 2026 │ TL-IST Spinning Vertical ERP Expertise
  --------------------------------------------------------------------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **✅ VERDICT:** FSD v1.1 is technically sound and ready for CEO Stage 4 countersignature. All 9 Blueprint v6 gates PASS. All 7 audit findings documented and resolved (3 on FrmPRForeclosure, 4 on Indentcancellation --- AF-01 to AF-04 resolved; AF-02 to AF-04-Indentcancellation NOTED as G4/G5/G7 VB6 backlog, SPINRISE fixes confirmed). No open items blocking CEO sign-off (OI-05 is IST note, OI-06 is process gate --- both non-blocking).
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Executive Summary --- Key Metrics at a Glance**

+---------------------+------------------------+---------------------------+----------------------------+-------------------------+---------------------------+
| **Blueprint Gates** | **Audit Findings**     | **Critical Defects**      | **Error Handlers**         | **Code Reduction**      | **Open Items**            |
|                     |                        |                           |                            |                         |                           |
| **9 / 9 PASS**      | **7 Documented**       | **6 Raised**              | **SPINRISE Mandatory**     | **15.2% avg**           | **2 Non-blocking**        |
|                     |                        |                           |                            |                         |                           |
| Both forms cleared  | AF-01 to AF-04 (F1+F2) | CD-01 to CD-03 (×2 forms) | All C# endpoints try-catch | 749+1,033 lines cleaned | OI-05 (IST) & OI-06 (CEO) |
+=====================+========================+===========================+============================+=========================+===========================+

# Expert Commentary --- TL-IST Spinning Vertical ERP Perspective

## Overall Assessment

This combined FSD covering PR Foreclosure and PR Cancellation represents a thorough and well-structured specification for two critical post-processing transactions in the M01 Purchase Order module. Both forms are lean status-update transactions with no print output, no Pre-GST fields, no ig_param customer branches, and no document number generation --- making them well-suited as early Sprint candidates with low complexity but high operational importance in spinning mill procurement workflows.

The Stage 0 VB6 code audit is rigorous: 7 compliance findings documented across both forms, all with confirmed resolution status. The developer has clearly distinguished between what is within Stage 0 scope (fix now) and what is VB6 legacy backlog (fix in SPINRISE). This is the correct approach for migration FSDs.

## Transaction Integrity (G6) --- Critical for Spinning Mill Operations

In spinning mill environments, PR Foreclosure and Cancellation transactions directly affect the procurement commitment register. Unmatched transactions or partial updates to PO_PRH/PO_PRL without corresponding LogDet_PO entries would create data integrity issues that are difficult to detect in live production.

Both forms have correct transaction boundaries confirmed at Stage 0:

- FrmPRForeclosure: BeginTrans before the grid row loop, CommitTrans when at least one row is selected (chk\>0), RollbackTrans on error or zero selection. LogDet_PO INSERT is inside the BeginTrans block --- atomic.

- Indentcancellation: BeginTrans → UPDATE PO_PRH → UPDATE PO_PRL → INSERT LogDet_PO → CommitTrans --- in BOTH the cancel and undo paths. RollbackTrans in Err0 handler. G6 PASS, both forms.

SPINRISE must replicate this atomicity using Dapper BeginTransaction wrapping all three DML statements per operation. This is a non-negotiable requirement for spinning mill data integrity.

## Error Handling --- G7 Partial Finding on Indentcancellation (AF-04-F2) --- CEO Attention

The G7 finding on Indentcancellation is the most significant technical observation in this FSD. Five subroutines with direct database operations (bindcontls, IndType, undoLookup, ScopeLookup, stock_find) have no On Error GoTo handler in the VB6 source. This means:

- Any DB failure in these subs results in silent failure --- no rollback, no user notification, no audit trail.

- In a spinning mill production environment with network instability (a known characteristic of shop-floor setups), this creates a window for data corruption on lookup queries and form load operations.

The VB6 defect is correctly NOTED as backlog --- fixing it in Stage 0 would require regression testing of 1,033 lines serving live customer data. SPINRISE\'s mandatory try-catch + Serilog per C# API endpoint eliminates this entirely. The per-sub SPINRISE fix specification in AF-04-F2 and Section 4 Business Rules is detailed and correct.

## Stored Procedure Design --- Correct for Spinning Mill Multi-Division Operations

The introduction of three new stored procedures (sp_PR_GetOpenForForeclosure, sp_PR_GetCancellablePRs, sp_PR_GetCancelledPRsForUndo) is the right architectural decision. Key observations:

- sp_PR_GetOpenForForeclosure correctly omits yfdate/yldate parameter. A PR raised in a prior financial year (e.g. March 2025) may legitimately require foreclosure in the current year when seasonal demand did not materialise. This is a well-known procurement pattern in spinning mills with annual raw material planning cycles.

- sp_PR_GetCancellablePRs correctly incorporates the PO_ORD check (CEO confirmed, OI-02-F2). Preventing cancellation of PRs against which a Purchase Order has already been raised is essential --- in spinning mill operations, this prevents a situation where a PO remains \'live\' with no backing PR, creating a commitment without a requisition.

- sp_PR_GetCancelledPRsForUndo correctly applies yfdate/yldate scope --- unlike foreclosure, undo-cancellation is a corrective action that should be restricted to the current financial year.

## Dual-Form Architecture --- Commended

Combining FrmPRForeclosure and Indentcancellation into a single FSD is architecturally correct. Both forms share PO_PRH and PO_PRL as primary tables, both are status-update transactions with no print output, and both are triggered from the same M01 Purchase Order module workflow. A single FSD reduces review overhead and ensures that the SPINRISE API endpoint design is consistent across both operations.

## Pre-GST Scan --- Verified Clean

The confirmed absence of AED/BED/Cess/VAT/CST references in both forms is important for spinning mills that have been on GSTN since 2017. Neither form has any Pre-GST fields in scope. Pre-GST section correctly marked NOT APPLICABLE. No remediation required.

## CEO Working Session --- OI-06 Process Observation

Sasi\'s OI-06 is a valid process observation. Per Blueprint v6 §4.2, the CEO Working Session is the entry point of the FSD review chain --- it is where the CEO provides business direction before specification writing begins. For this FSD, it was not held before Stage 1. This does not block Stage 3 or Stage 4 technically, but the CEO should formally acknowledge this as waived or schedule it before Sprint start, as this affects the completeness of the business alignment record.

# Expert Observations --- Points Requiring CEO Attention at Stage 4

+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **⚠ CONCERN 1 (AF-04-F2 / CD-03-F2): 5 Subs with DB Operations --- No VB6 Error Handler**                                                                                                                                                                                                                                |
|                                                                                                                                                                                                                                                                                                                          |
| Five subroutines in Indentcancellation.frm (bindcontls, IndType, undoLookup, ScopeLookup, stock_find) perform database operations with no On Error GoTo handler. The VB6 defect is intentionally left unfixed (outside Stage 0 scope). CEO should acknowledge this known VB6 risk and confirm it is accepted as backlog. |
|                                                                                                                                                                                                                                                                                                                          |
| SPINRISE fix is confirmed and fully specified: all five C# API endpoint equivalents are in try-catch with Serilog. React toast notification on API error. No silent failures in SPINRISE.                                                                                                                                |
+==========================================================================================================================================================================================================================================================================================================================+

+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **⚠ CONCERN 2 (CD-01-F1, CD-01-F2): SQL String Concatenation --- VB6 Backlog Acceptance on Record**                                                                                                                                                                                                                                        |
|                                                                                                                                                                                                                                                                                                                                            |
| FrmPRForeclosure original code (cleaned in Stage 0 --- Billdisplay and related subs, parameterized as FIX G4-1 to G4-4). Indentcancellation: all queries in Command1_Click, bindcontls, undoLookup, ScopeLookup use string concatenation --- HIGH SQL injection risk throughout --- G4 backlog per Blueprint v6, not fixed in VB6 Stage 0. |
|                                                                                                                                                                                                                                                                                                                                            |
| SPINRISE fix confirmed: Dapper \@parameter binding + stored procedures for all lookup queries. Zero string-built SQL in SPINRISE. CEO should confirm VB6 backlog acceptance position is consistent with migration go/no-go policy for existing customer databases.                                                                         |
+============================================================================================================================================================================================================================================================================================================================================+

+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **📋 NOTE 3: DB Migration --- Execution Gated on CEO Countersignature**                                                                                                       |
|                                                                                                                                                                               |
| Section 6 explicitly states: Execute only after CEO countersignature --- not to be run in any live customer database before CEO approval is received.                         |
|                                                                                                                                                                               |
| Three new stored procedures and two ALTER TABLE statements (row_version on PO_PRH and PO_PRL) are pending deployment. Your signature directly unblocks all migration scripts. |
|                                                                                                                                                                               |
| The PO_PRH/PO_PRL row_version ALTERs must be consolidated with M01 PR Form and PO Form DB migration scripts --- not executed independently.                                   |
+===============================================================================================================================================================================+

+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **📋 NOTE 4: OI-06 --- CEO Working Session Gate**                                                                                                                                       |
|                                                                                                                                                                                         |
| Per Blueprint v6 §4.2, the CEO Working Session is the first step of the review chain. Sasi raised OI-06 at Stage 2: this was not held before Stage 1 FSD writing for this module.       |
|                                                                                                                                                                                         |
| CEO to confirm at Stage 4: (a) Working Session is formally waived for this FSD, OR (b) it will be held before Sprint start. No developer may begin coding before this gate is resolved. |
|                                                                                                                                                                                         |
| No Sprint coding may begin on FrmPRForeclosure or Indentcancellation before OI-06 is formally closed by CEO.                                                                            |
+=========================================================================================================================================================================================+

# CEO Stage 4 --- Actions Required

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **\#**   **CEO Action Required**                                                                                        **Detail**
  -------- -------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **1**    **Countersign FSD v1.1 to lock the development baseline**                                                      Your signature on Section 9 (Review Chain & Sign-off) locks the FSD as the definitive development baseline per Blueprint v6 Section 4.2. No developer may begin coding FrmPRForeclosure or Indentcancellation before this gate is passed.

  **2**    **Authorise DB Migration scripts (Section 6) for customer databases**                                          Three new stored procedures are pending your countersignature before execution on any live customer database: sp_PR_GetOpenForForeclosure, sp_PR_GetCancellablePRs, sp_PR_GetCancelledPRsForUndo. Additionally, ALTER TABLE PO_PRH ADD row_version ROWVERSION and ALTER TABLE PO_PRL ADD row_version ROWVERSION are pending. Execute only after CEO approval.

  **3**    **Formally confirm acceptance of VB6 backlog items (AF-02 to AF-04-Indentcancellation, CD-01-F1, CD-01-F2)**   SQL concatenation throughout Indentcancellation (CD-01-F2) and 5 subs without error handlers (AF-04-F2) are intentionally left as VB6 backlog --- outside Stage 0 scope and not to be carried into SPINRISE. Please formally confirm this is the accepted migration policy on record.

  **4**    **Confirm OI-06: CEO Working Session --- waived or to be held before Sprint start**                            Per Blueprint v6 §4.2, the CEO Working Session is the first step of the review chain. Sasi raised OI-06 at Stage 2: this was not held before Stage 1 FSD writing. CEO to confirm: (a) Working Session is waived for this FSD, or (b) it will be held before Sprint start. No coding may begin until this is resolved.

  **5**    **Confirm PO_ORD check in sp_PR_GetCancellablePRs (OI-02-F2 --- already direction given)**                     CEO confirmed on 20-May-2026: add PO_ORD check to sp_PR_GetCancellablePRs --- exclude any PR that has a PO_ORD record. User message: \'A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR.\' This is already incorporated in Section 6. CEO to formally countersign as part of this Stage 4 approval.
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Review Chain & Sign-off Status

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Role**                    **Name**     **Date**              **Status**   **Notes**
  --------------------------- ------------ --------------------- ------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Stage 1 --- Developer**   Mariyaiya    20 May 2026           COMPLETE     FSD v1.1 complete. All Blueprint v6 §4.3 sections complete (both forms). 7 audit findings documented. SP names pending --- confirmed by Sasi at Stage 2. Submitted for Stage 2 review.

  **Stage 2 --- TL-Dev**      Sasi         20 May 2026           CLEARED      Stage 0 FULLY APPROVED 19 May 2026 (both forms). SP names confirmed (sp_PR_GetOpenForForeclosure, sp_PR_GetCancellablePRs, sp_PR_GetCancelledPRsForUndo). OI-01-F1, OI-02-F1, OI-03-F1, OI-01-F2, OI-02-F2, OI-03-F2, OI-04-F2 closed. OI-05-F2 (IST note) and OI-06 (CEO Working Session) remain non-blocking. Stage 2 CLEARED on receipt of v1.1.

  **Stage 3 --- TL-IST**      Palanivel    21--23 May 2026       CLEARED      Domain expert review complete --- see TL-IST Expert Commentary section. Verdict: FSD v1.1 is ready for CEO Stage 4 countersignature. OI-05-F2 IST note addressed. All domain findings consolidated below.

  **Stage 4 --- CEO**         T. Mani      Target: 23 May 2026   AWAITED      CEO countersignature = locked development baseline per Blueprint v6 §4.2. No coding before this gate. Execute DB Migration (Section 6) only after this gate. OI-06 (CEO Working Session) to be confirmed waived or scheduled.
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Stage 0 Gate Results --- Blueprint v6.0 (Nine Gates)

Blueprint v6 Section 5.1: Sasi is the only person who can issue Stage 0 sign-off. Stage 0 FULLY APPROVED by TL-Dev Sasi --- 19 May 2026. Both forms cleared. All 7 audit findings documented and resolved/noted.

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Gate**      **Blueprint v6 Check**            **Result**             **Evidence & SPINRISE Action**
  ------------- --------------------------------- ---------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  G1            CustID blocks removed             PASS                   Zero If CustID= branches in cleaned code --- both forms confirmed (F1+F2). Zero CustID in SPINRISE.

  G2            Dead UI code removed              PASS                   FrmPRForeclosure: ByPass All checkbox (ChkByPass) --- dead control, no business logic --- removed. Indentcancellation: dead frame controls removed. Both cleaned.

  G3            Commented-out code removed        PASS                   FrmPRForeclosure: 7 FIX annotation lines retained (FIX G4-1 to G4-4, L1, L2, U2) as Stage 0 fix markers --- Sasi confirmed acceptable. Indentcancellation: zero comment lines remain.

  G4            Debug code removed                PASS                   Zero Stop / MsgBox debug / Print debug in either cleaned form.

  G5            Deprecated API calls flagged      PASS (noted)           FrmPRForeclosure: fpSPR80.OCX (FarPoint Spread) → Ant Design Table (CD-02-F1). Indentcancellation: MSDATGRD.OCX, MSMASK32.OCX, MSCOMCTL.OCX → React/Ant Design (CD-03-F2). All OCX noted. SPINRISE: zero OCX.

  G6            Transaction integrity clean       PASS                   FrmPRForeclosure: BeginTrans before loop, CommitTrans (chk\>0), RollbackTrans (chk=0 + error). LogDet_PO INSERT inside BeginTrans. Indentcancellation: BeginTrans → UPDATE PO_PRH → UPDATE PO_PRL → INSERT LogDet_PO → CommitTrans in both cancel and undo paths. RollbackTrans in Err0 handler. G6 PASS both forms.

  G7            Error handling present            PASS (partial on F2)   FrmPRForeclosure: 8 subs WITH handler (BUTTON_Click, SetGridHead, Form_Load, Billdisplay, getMasterName, GetText, SetSpreadCol, Form_KeyDown). 5 trivial subs without --- none contain DB ops (confirmed). Indentcancellation: 5 subs with DB ops have no handler (bindcontls, IndType, undoLookup, ScopeLookup, stock_find) --- AF-04-F2 raised. SPINRISE: ALL C# API endpoints in try-catch + Serilog. No silent failures.

  G8            OERN removed --- zero tolerance   PASS                   FrmPRForeclosure: zero On Error Resume Next in cleaned 749-line file. Indentcancellation: zero active OERN in cleaned 1,033-line file. Both fully cleared.

  G9            ig_param path confirmed           PASS                   FrmPRForeclosure: no ig_param flags, no CustID blocks --- confirmed. Indentcancellation: no ig_param flags, no CustID blocks --- confirmed. No orphaned flags. G9 PASS both forms.

  **OVERALL**   9 PASS · 0 FAIL                   PASS                   Both FrmPRForeclosure.frm and Indentcancellation.frm Stage 0 FULLY APPROVED by TL-Dev Sasi --- 19 May 2026. G5 OCX noted (CD-02-F1, CD-03-F2). G7 partial finding on Indentcancellation (AF-04-F2) --- SPINRISE mandatory fix confirmed.
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Compliance Audit Findings --- Both Forms

Audit performed against Blueprint v6.0 and VB6 source code. Both forms Stage 0 FULLY APPROVED by TL-Dev Sasi --- 19 May 2026.

+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Compliance Audit Findings --- FrmPRForeclosure.frm (3 findings --- all RESOLVED)**                                                                                                                                                                                                                                                                                                                                                            |
+=======================+========================================================================================================================================+=======================+========================================================================================================================================================================================================================================================+
| **Finding**           | **Issue**                                                                                                                              | **Risk**              | **Resolution / CD**                                                                                                                                                                                                                                    |
+-----------------------+----------------------------------------------------------------------------------------------------------------------------------------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-01**             | G4 --- SQL string concatenation in Billdisplay (original code)                                                                         | HIGH                  | RESOLVED ✔ Stage 0 confirmed by Sasi: parameterized ADODB.Command applied (FIX G4-1 through G4-4) in cleaned code. SPINRISE: Dapper \@parameter binding throughout. Zero string-concat SQL. CD-01-F1 raised.                                           |
+-----------------------+----------------------------------------------------------------------------------------------------------------------------------------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-02**             | G7 --- 5 trivial subs without error handlers (ChkByPass_Click, CmdCancel_Click, CmdShow_Click, DTPicker1_CallbackKeyDown, Form_Resize) | MED                   | RESOLVED ✔ Stage 0 confirmed by Sasi: all 5 subs contain no DB or significant logic --- no handler required. 8 subs with meaningful DB operations all have On Error GoTo handlers confirmed. SPINRISE: all C# API endpoints in try-catch with Serilog. |
+-----------------------+----------------------------------------------------------------------------------------------------------------------------------------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-03**             | G5 --- fpSpread OCX (fpSPR80.OCX) dependency                                                                                           | HIGH                  | NOTED ✔ Stage 0 confirmed by Sasi: Tracked as G5 per Blueprint v6. SPINRISE: replace with Ant Design Table with checkbox column. CD-02-F1 raised.                                                                                                      |
+-----------------------+----------------------------------------------------------------------------------------------------------------------------------------+-----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Compliance Audit Findings --- Indentcancellation.frm (4 findings: AF-01 RESOLVED, AF-02 to AF-04 NOTED as VB6 backlog)**                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
+==================================+=====================================================================================================================+==================================+=======================================================================================================================================================================================================================================================================================================================================================================================================+
| **Finding**                      | **Issue**                                                                                                           | **Risk**                         | **Resolution / CD**                                                                                                                                                                                                                                                                                                                                                                                   |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-01**                        | G8 --- On Error Resume Next in original (implicit silent error-swallowing in Command1_Click and several other subs) | HIGH                             | RESOLVED ✔ Stage 0 confirmed by Sasi: On Error GoTo Err0 with db.RollbackTrans present in Command1_Click in cleaned code. SPINRISE: all C# endpoints in try-catch + Serilog.                                                                                                                                                                                                                          |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-02**                        | G4 --- SQL concatenation throughout all subs (Command1_Click, bindcontls, undoLookup, ScopeLookup)                  | HIGH                             | NOTED ✔ G4 backlog per Blueprint v6. Not fixed in VB6 (Stage 0 scope). SPINRISE: Dapper \@parameter binding + SPs for all lookup queries. CD-01-F2 raised.                                                                                                                                                                                                                                            |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-03**                        | G5 --- Three OCX dependencies (MSDATGRD, MSMASK32, MSCOMCTL)                                                        | MED                              | NOTED ✔ Stage 0: tracked as G5. SPINRISE: Ant Design Table, React DatePicker, React layout. CD-02-F2 raised.                                                                                                                                                                                                                                                                                          |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **AF-04**                        | G7 --- 5 subs with DB operations have no error handler (bindcontls, IndType, undoLookup, ScopeLookup, stock_find)   | HIGH                             | NOTED ✔ G7 finding tracked. VB6 AS-IS retained --- fixing outside Stage 0 scope. SPINRISE mandatory error handling per API method: PrCancellationController.GetEligiblePRs (ScopeLookup), GetDetail (bindcontls), GetIndentTypes (IndType), GetCancelledPRs (undoLookup), GetCurrentStock (stock_find) --- all in try-catch + Serilog. React toast on API error. No silent failures. CD-03-F2 raised. |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

# Critical Defects --- Must Not Be Carried Into SPINRISE

All Critical Defects have confirmed SPINRISE fixes. VB6 defects marked HIGH must not appear in any SPINRISE code.

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **CD No.**       **Defect**                                                                           **Risk**   **SPINRISE Fix**
  ---------------- ------------------------------------------------------------------------------------ ---------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **CD-01 (F1)**   SQL string concatenation --- FrmPRForeclosure (original code)                        HIGH       Dapper \@parameter binding throughout all C# API endpoints. Zero string-built SQL in SPINRISE. Cleaned VB6 already parameterized at Stage 0 (FIX G4-1 to G4-4).

  **CD-02 (F1)**   fpSpread OCX (fpSPR80.OCX) dependency                                                HIGH       Ant Design Table with checkbox column and multi-select row state. No OCX in SPINRISE.

  **CD-03 (F1)**   Recordset leak in loop (rsDept not closed per iteration --- fixed in cleaned code)   MED        Dapper connection lifecycle managed per-request. No open cursors inside loops in C# API.

  **CD-01 (F2)**   SQL string concatenation --- Indentcancellation (all subs --- VB6 backlog)           HIGH       Dapper \@parameter binding in all C# API endpoints. SPs for all lookup queries. Zero string-concat SQL. CEO to confirm VB6 backlog acceptance on record.

  **CD-02 (F2)**   Three OCX dependencies --- Indentcancellation (MSDATGRD, MSMASK32, MSCOMCTL)         HIGH       Ant Design Table (DataGrid), React DatePicker (MaskEdBox date), React layout (StatusBar). Zero OCX in SPINRISE.

  **CD-03 (F2)**   G7 --- 5 subs with DB operations have no error handler (Indentcancellation)          HIGH       SPINRISE mandatory error handling per API method: all five controller endpoints in try-catch + Serilog structured logging. React toast notification on API error. No silent failures anywhere in SPINRISE.
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# DB Migration --- Objects Pending CEO Countersignature

  ------------------------------------------------------------------------------------------------------------------------------------------------
  **⚠ EXECUTION CONTROL: Execute only after CEO countersignature. Not to be run in any live customer database before CEO approval is received.**
  ------------------------------------------------------------------------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Object**                              **Type**                        **Purpose / Notes**
  --------------------------------------- ------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **sp_PR_GetOpenForForeclosure**         SP CREATE --- NEW               Parameters: \@divcode varchar(10), \@prno_filter varchar(20) = NULL. Encapsulates Billdisplay query: SELECT prno, prdate, Depname, prsno, itemcode, Itemname, balance FROM PO_PRH+PO_PRL+In_dep+in_item WHERE balance\>0, FClosed\<\>\'Y\', cancelflag=\'N\', divcode=@divcode. No yfdate/yldate parameter --- foreclosure operates across all financial years (OI-01-F1 closure rationale, confirmed by Sasi Stage 2). Final SP name confirmed: Sasi, 20 May 2026.

  **sp_PR_GetCancellablePRs**             SP CREATE --- NEW               Parameters: \@divcode varchar(10), \@yfdate datetime, \@yldate datetime. Encapsulates ScopeLookup modal query: PRs where CANCELFLAG\<\>\'Y\', APPFLG\<\>\'Y\', QTYORD=0, prno NOT IN PO_ENQL, prdate BETWEEN \@yfdate AND \@yldate, divcode=@divcode. Includes PO_ORD check (CEO confirmed 20-May-2026 --- OI-02-F2): exclude any PR with a PO_ORD record. User message: \'A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR.\' Final SP name confirmed: Sasi, 20 May 2026.

  **sp_PR_GetCancelledPRsForUndo**        SP CREATE --- NEW               Parameters: \@divcode varchar(10), \@yfdate datetime, \@yldate datetime. Encapsulates undoLookup modal query: PRs where CANCELFLAG=\'Y\', PRDATE BETWEEN \@yfdate AND \@yldate, divcode=@divcode. Final SP name confirmed: Sasi, 20 May 2026.

  **LogDet_PO --- schema verify**         Table verify                    Confirm all columns used by both forms exist: divcode, prno, prdate, depcode, Trans_UserId, prsno, itemcode, quantity, username, Trans_date, Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo. CONFIRMED --- all 15 columns verified against DDL. quantity column CONFIRMED numeric(15,3). No ALTER required.

  **PO_PRL.FClosed + PO_PRL.FCloseddt**   Column verify                   CONFIRMED --- PO_PRL.FClosed char(1) NULL and PO_PRL.FCloseddt datetime NULL both exist in DDL. No ALTER required.

  **PO_PRH + PO_PRL row_version**         COLUMN ADD --- ALTER REQUIRED   ALTER TABLE PO_PRH ADD row_version ROWVERSION; ALTER TABLE PO_PRL ADD row_version ROWVERSION. Execute once per database before SPINRISE go-live (after CEO countersignature). Must be consolidated with M01 PR Form and PO Form DB migration scripts --- do not execute independently.
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Open Items (OI-01-F1 to OI-06)

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **OI No.**     **Item**                                                    **Status**   **Resolution**                                                                                                                                                                                                                                                                                                                                                          **Owner**
  -------------- ----------------------------------------------------------- ------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------
  **OI-01-F1**   Financial year guard on foreclosure                         CLOSED       CLOSED by Sasi at Stage 2 (20 May 2026): Year guard NOT required for Foreclosure. A PR raised in a prior financial year may legitimately be foreclosed in the next financial year when fulfilment is no longer expected. Do NOT apply yfdate/yldate filter in sp_PR_GetOpenForForeclosure.                                                                              Sasi

  **OI-02-F1**   Undo-Foreclosure action                                     CLOSED       CLOSED by Sasi at Stage 2 (20 May 2026): VB6 has no undo --- once FClosed=\'Y\' it is permanent. No live customer has requested an Undo-Foreclosure action. Closed unless CEO directs otherwise.                                                                                                                                                                        Sasi / CEO

  **OI-03-F1**   SPINRISE SP name for Billdisplay query                      CLOSED       CLOSED by Sasi at Stage 2 (20 May 2026): Final SP name = sp_PR_GetOpenForForeclosure. Parameters: \@divcode varchar(10), \@prno_filter varchar(20) = NULL. See Section 6.                                                                                                                                                                                               Sasi

  **OI-04-F1**   Print confirmation --- Foreclosure                          CLOSED       CLOSED. No Crystal Reports print in VB6 --- confirmed by Stage 0 code scan. No print function exists in FrmPRForeclosure.frm. No QuestPDF class required. Re-print control NOT APPLICABLE.                                                                                                                                                                              Sasi

  **OI-01-F2**   SPINRISE SP names for ScopeLookup and undoLookup            CLOSED       CLOSED by Sasi at Stage 2 (20 May 2026): SP1 = sp_PR_GetCancellablePRs, SP2 = sp_PR_GetCancelledPRsForUndo. Parameters confirmed. See Section 6.                                                                                                                                                                                                                        Sasi

  **OI-02-F2**   Cancellation guard --- PO raised (beyond enquiry check)     CLOSED       CEO confirmed 20-May-2026: Add PO_ORD check to sp_PR_GetCancellablePRs. User message: \'A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR.\' Incorporated in Section 6.                                                                                                                                                          Sasi / CEO

  **OI-03-F2**   APPFLG field name --- confirm column                        CLOSED       CLOSED --- DDL confirmed: PO_PRH.APPFLG char(1) NULL DEFAULT \'N\'. Column exists. SPINRISE uses PO_PRH.APPFLG unchanged.                                                                                                                                                                                                                                               Sasi

  **OI-04-F2**   Print confirmation --- Cancellation                         CLOSED       CLOSED. No Crystal Reports print in VB6 --- confirmed by Stage 0 code scan. No QuestPDF class required. Re-print control NOT APPLICABLE.                                                                                                                                                                                                                                Sasi

  **OI-05-F2**   IST --- customer pain point on cancellation restrictions    OPEN         IST to confirm whether any active customer has raised a support call regarding PR cancellation restrictions (APPFLG, QTYORD=0, PO_ENQL exclusion). TL-IST Palanivel: no active support calls on record for cancellation restrictions across current customer base. This OI is NON-BLOCKING for Stage 4 --- documented for Sprint planning reference.                    Palanivel (TL-IST)

  **OI-06**      CEO Working Session --- Stage 0 Input (Blueprint v6 §4.2)   OPEN         Raised by Sasi at Stage 2 (20 May 2026): CEO Working Session not held before Stage 1 FSD writing. Per Blueprint v6 §4.2, the working session is the first step of the review chain. CEO to confirm at Stage 4: (a) waived for this FSD, or (b) to be held before Sprint start. NON-BLOCKING for Stage 4 sign-off but must be resolved before developer coding begins.   CEO T. Mani
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Stage 4 Sign-off --- CEO Countersignature Block

+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **CEO countersignature on this block locks FSD v1.1 as the definitive development baseline per Blueprint v6 Section 4.2.**                                                                                     |
|                                                                                                                                                                                                                |
| No developer may begin coding FrmPRForeclosure or Indentcancellation. DB Migration scripts (Section 6) execute only after this gate. OI-06 (CEO Working Session) must be resolved before coding Sprint begins. |
+================================================================================================================================================================================================================+

+----------------------------------------------------+----------------------------------------------------+------------------------------------+----------------------------------------------------+
| **Developer --- Mariyaiya**                        | **TL-Dev --- Sasi (Stage 2)**                      | **TL-IST --- Palanivel (Stage 3)** | **CEO --- T. Mani (Stage 4)**                      |
+====================================================+====================================================+====================================+====================================================+
| Signature: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_      | Signature: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_      | Signature: Palanivel               | Signature: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_      |
|                                                    |                                                    |                                    |                                                    |
| Date: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ | Date: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ | Date: 23/05/26                     | Date: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |
|                                                    |                                                    |                                    |                                                    |
| **Stage 1 COMPLETE**                               | **Stage 2 CLEARED**                                | **Stage 3 CLEARED**                | **Stage 4 AWAITED**                                |
+----------------------------------------------------+----------------------------------------------------+------------------------------------+----------------------------------------------------+

Kalpatharu Software Ltd \| SPINRISE Migration \| M01 PO \| PR Foreclosure & Cancellation \| FSD v1.1 \| 23 May 2026 \| Internal Confidential
