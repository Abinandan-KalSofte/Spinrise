+:---------------------------------------------------------------------:+
| **SPINRISE ERP**                                                      |
|                                                                       |
| Functional Specification Document · Blueprint v6.0 · 21 May 2026      |
|                                                                       |
| **PR First Level Approval (frmindentapp.frm)**                        |
|                                                                       |
| M01 Purchase Order · Stage 0: FULLY APPROVED · Submitted for Stage 2  |
| Review                                                                |
|                                                                       |
| FSD v1.1 · Review Chain: Developer → TL-Dev Sasi (Stage 2) → TL-IST   |
| Palanivel (Stage 3) → CEO T. Mani (Stage 4) · Kalpatharu Software Ltd |
| · Internal Confidential                                               |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **ACTION --- FSD Submission · Blueprint v6 §4.3 mandatory sections    |
| complete**                                                            |
|                                                                       |
| 1\. Review chain: FSD submitted through correct chain --- Developer → |
| TL-Dev Sasi (Stage 2) → TL-IST Palanivel (Stage 3) → CEO T. Mani      |
| (Stage 4).                                                            |
|                                                                       |
| 2\. All Blueprint v6 §4.3 mandatory sections complete: Stage 0 Gates, |
| Fields, Business Rules, Pre-GST, Print, Customer Variations, DB       |
| Migration, Critical Defects, Open Items --- all present.              |
|                                                                       |
| 3\. Stage 0 FULLY APPROVED by Sasi --- 21 May 2026. All 9 gates       |
| confirmed. 22 On Error GoTo handlers verified across the form. No     |
| developer may open frmindentapp.frm in VB6 IDE.                       |
|                                                                       |
| 4\. CEO Working Session confirmed waived per T. Mani email 21 May     |
| 2026. Three CEO directives incorporated: (a) Crystal print/save       |
| separation (CD-05), (b) po_para single-read caching (CD-06), (c) form |
| scope confirmed as First Level only. Submitted to TL-Dev Sasi for     |
| Stage 2 review.                                                       |
+-----------------------------------------------------------------------+

+:-----------------+:-----------------+:----------------------------------------+:-----------------+:-------------------------------------+
| **Compliance Audit Findings (5 findings --- Stage 0 FULLY APPROVED by TL-Dev Sasi 21 May 2026)**                                        |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+
| **Finding**      | **Issue**        | **Detail**                              | **Risk**         | **Resolution / CD Raised**           |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+
| **AF-01**        | **G4 --- SQL     | All SQL in BUTTON_Click, DepLookup,     | **HIGH**         | NOTED ✔ Stage 0 confirmed by Sasi:   |
|                  | string           | checkrs queries, adoPrimaryRS SHAPE     |                  | G4 PASS (cleaned code). CD-01        |
|                  | concatenation    | queries, UPDATE/INSERT statements use & |                  | raised. SPINRISE: (1) Dapper         |
|                  | throughout**     | string concatenation --- SQL injection  |                  | \@parameter binding throughout. (2)  |
|                  |                  | risk throughout. All 8 po_para reads    |                  | All 8 po_para reads replaced by a    |
|                  |                  | use SELECT \* FROM po_para WHERE        |                  | single parameterised Dapper call at  |
|                  |                  | divcode=\[divcode variable\] --- string |                  | page load --- result cached in a C#  |
|                  |                  | concatenation in every sub that reads   |                  | DTO (PoParaDto) for the session.     |
|                  |                  | parameters.                             |                  | Zero repeated SELECT \* on po_para   |
|                  |                  |                                         |                  | in SPINRISE.                         |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+
| **AF-02**        | **G5 --- Eight   | MSDATGRD.OCX (grddatagrid),             | **HIGH**         | NOTED ✔ Tracked as G5 per Blueprint  |
|                  | OCX/COM          | MSDATLST.OCX, MSMASK32.OCX (MaskEdBox   |                  | v6. SPINRISE: Ant Design Table       |
|                  | dependencies**   | x2), MSCOMCTL.OCX (stbar), TABCTL32.OCX |                  | (grddatagrid/ubGrid1), React         |
|                  |                  | (SSTab), MSCOMCT2.OCX (DTPicker),       |                  | DatePicker (DTPicker/MaskEdBox),     |
|                  |                  | listacx.ocx (ubGrid1), Crystl32.OCX     |                  | React layout (StatusBar/SSTab),      |
|                  |                  | (CrystalReport1) --- all Windows COM.   |                  | QuestPDF (CrystalReport1 /           |
|                  |                  | Cannot run in browser.                  |                  | RepPO.rpt). CD-03 raised.            |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+
| **AF-03**        | **G7 ---         | stock_find performs a DB lookup on      | **MED**          | NOTED ✔ Stage 0 confirmed by Sasi:   |
|                  | stock_find DB    | in_item with no On Error GoTo handler   |                  | CD-02 raised. SPINRISE:              |
|                  | lookup has no    | --- silent failure on DB error returns  |                  | PrApprovalController.GetCurrentStock |
|                  | error handler**  | 0. Command1/2/4_Click confirmed no DB   |                  | (stock_find equivalent) in           |
|                  |                  | ops by Sasi. ChkAll_Click is grid       |                  | try-catch; log error + return 0 on   |
|                  |                  | iteration only.                         |                  | DB failure with React toast          |
|                  |                  |                                         |                  | notification.                        |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+
| **CD-06**        | **G4 --- po_para | All 8 po_para reads across multiple     | **MED**          | NOTED ✔ CD-05 raised. SPINRISE:      |
|                  | read repeated 8  | subs use SELECT \* FROM po_para WHERE   |                  | single parameterised Dapper call at  |
|                  | times via string | divcode=\[divcode variable\] --- string |                  | page load --- WHERE divcode =        |
|                  | concatenation**  | concatenation AND repeated DB           |                  | \@divcode --- result cached in       |
|                  |                  | round-trips. CEO directive (21 May      |                  | PoParaDto for session. Zero repeated |
|                  |                  | 2026): SPINRISE should read po_para     |                  | DB round-trips.                      |
|                  |                  | once at page load and cache in a DTO.   |                  |                                      |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+
| **CD-05**        | **G6 --- Crystal | Crystal print call (L2187--2190:        | **MED**          | NOTED ✔ Stage 0 confirmed by Sasi:   |
|                  | print call       | Cry_PO_IndentcrTransPrint.CrystalPrint) |                  | G6 PASS --- transaction boundary is  |
|                  | positioned after | is called after CommitTrans inside      |                  | clean (print is already OUTSIDE the  |
|                  | CommitTrans**    | BUTTON_Click. CEO directive (21 May     |                  | transaction block). CD-05 raised per |
|                  |                  | 2026): if print fails after             |                  | CEO directive. SPINRISE: print       |
|                  |                  | CommitTrans, approval record is already |                  | action fully separated as a          |
|                  |                  | committed --- rollback not possible.    |                  | dedicated API endpoint. Save →       |
|                  |                  | Pattern identified.                     |                  | CommitTrans → separate print call.   |
|                  |                  |                                         |                  | If print fails, approval record      |
|                  |                  |                                         |                  | stands and user is notified to       |
|                  |                  |                                         |                  | reprint.                             |
+------------------+------------------+-----------------------------------------+------------------+--------------------------------------+

+:------------------------------------+:-----------------------------------------------+
| **1 Document Identity**                                                              |
+-------------------------------------+------------------------------------------------+
| **Form Name**                       | frmindentapp.frm (PR First Level Approval      |
|                                     | Entry) · M01 Purchase Order Module             |
+-------------------------------------+------------------------------------------------+
| **VB6 Source File**                 | frmindentapp.frm (primary) │ Globals:          |
|                                     | connectstring, divcode, yfdate, yldate, pdate, |
|                                     | head, uid, UserName, LocalIP, LocalHost,       |
|                                     | ModuleNo, adddelmod(), dep (approval level)    |
+-------------------------------------+------------------------------------------------+
| **Purpose**                         | First Level Approval form for Purchase         |
|                                     | Requisitions. CEO confirmed (21 May 2026):     |
|                                     | frmindentapp.frm is the First Level approval   |
|                                     | form only. Users with First Level authority    |
|                                     | review PR line items, set approved quantities  |
|                                     | (QTYREQD, FirstAppQty), record app1 on PO_PRH, |
|                                     | and set FirstApp=\'Y\' on PO_PRL lines. After  |
|                                     | First Level approval, PRSTATUS transitions to  |
|                                     | \'F\' (First Approved). Second Level (and any  |
|                                     | further levels) are handled by a separate form |
|                                     | --- see OI-08. Supports Delete-First-Approval  |
|                                     | (undo First Level only). Print (RepPO.rpt)     |
|                                     | triggered post-commit as a separate action.    |
|                                     | Unapproved PRs cannot proceed to enquiry or    |
|                                     | ordering.                                      |
+-------------------------------------+------------------------------------------------+
| **Original Line Count**             | Original: 4,481 lines · Cleaned: 4,030 lines · |
|                                     | Reduction: 451 lines (10.1%) · Breakdown:      |
|                                     | ubGrid1 dead hidden grid removed, legacy       |
|                                     | text-mode Print #A block removed, dead         |
|                                     | annotation comments removed. Full-form line    |
|                                     | count (design code + business logic combined)  |
|                                     | per Blueprint v6 §5.2.                         |
+-------------------------------------+------------------------------------------------+
| **Stage 0 Sign-off**                | FULLY APPROVED --- 21 May 2026 · TL-Dev: Sasi  |
|                                     | · Original: 4,481 lines · Cleaned: 4,030 lines |
|                                     | · Reduction: 451 lines (10.1%) · 22 On Error   |
|                                     | GoTo handlers confirmed. All 9 gates cleared.  |
|                                     | No developer may open frmindentapp.frm in VB6  |
|                                     | IDE.                                           |
+-------------------------------------+------------------------------------------------+
| **FSD Version**                     | v1.1: Corrected FSD --- frmindentapp.frm (PR   |
|                                     | First Level Approval). Stage 0 FULLY APPROVED  |
|                                     | by TL-Dev Sasi (21 May 2026). All Blueprint v6 |
|                                     | §4.3 mandatory sections complete: Document     |
|                                     | Identity, Stage 0 Gates, Field Table (with     |
|                                     | Mandatory flag + Default value), Business      |
|                                     | Rules, Pre-GST, Print Replacement, Customer    |
|                                     | Variations, DB Migration, Critical Defects,    |
|                                     | Open Items, Review Chain. Submitted to TL-Dev  |
|                                     | Sasi for Stage 2 review 21 May 2026.           |
+-------------------------------------+------------------------------------------------+
| **Review Chain**                    | CEO Working Session → Stage 1 Developer →      |
|                                     | Stage 2 TL-Dev Sasi (1 day) → Stage 3 TL-IST   |
|                                     | Palanivel (1 day) → Stage 4 CEO T. Mani (same  |
|                                     | day) · Target: 5 working days                  |
+-------------------------------------+------------------------------------------------+
| **Technology Stack**                | React.js 18 + Ant Design Pro │ ASP.NET Core 8  |
|                                     | Web API (C#) │ Dapper │ MS SQL Server          |
|                                     | 2019/2022 │ QuestPDF │ EPPlus                  |
+-------------------------------------+------------------------------------------------+
| **Primary DB Tables**               | PO_PRH, PO_PRL, In_dep, In_item, mm_MACmas,    |
|                                     | In_Scc, LogDet_PO, PO_INDENTTYPE (indirect),   |
|                                     | pr_emp (indirect)                              |
+-------------------------------------+------------------------------------------------+
| **Key Stored Procedures**           | None in VB6 --- all SQL is inline string       |
|                                     | concatenation. SPINRISE introduces new SPs for |
|                                     | First Level Approval:                          |
|                                     | sp_PR_GetPendingFirstApproval (listing),       |
|                                     | sp_PR_GetFirstApprovedForDeletion              |
|                                     | (delete-approval listing). Final SP names      |
|                                     | confirmed by Sasi at Stage 2. See OI-02.       |
+-------------------------------------+------------------------------------------------+
| **Crystal Reports Print**           | RepPO.rpt (KALFOLDERDATA path) · Parameters:   |
|                                     | \@Divcode, \@Prno, \@PrDate · Triggered after  |
|                                     | Direct (final level) approval only --- blocked |
|                                     | if DirectApp is not \'Y\'. SPINRISE            |
|                                     | replacement: QuestPDF class PrApprovalReport.  |
|                                     | See Section 5.                                 |
+-------------------------------------+------------------------------------------------+
| **Pre-GST Scan**                    | CLEAN --- zero AED / BED / Cess / Surcharge /  |
|                                     | VAT / CST references in frmindentapp.frm.      |
|                                     | Confirmed at Stage 0 by Sasi.                  |
+-------------------------------------+------------------------------------------------+
| **OCX / Legacy Dependencies (G5)**  | MSDATGRD.OCX (grddatagrid) → Ant Design Table  |
|                                     | │ MSMASK32.OCX (MaskEdBox) → React DatePicker  |
|                                     | │ MSCOMCTL.OCX (stbar StatusBar) → React       |
|                                     | layout │ TABCTL32.OCX (SSTab Tab control) →    |
|                                     | Ant Design Tabs or single panel │ MSCOMCT2.OCX |
|                                     | (DTPicker) → React DatePicker │ listacx.ocx    |
|                                     | (ubGrid1) → Ant Design Table (editable) │      |
|                                     | Crystl32.OCX (CrystalReport1) → QuestPDF.      |
|                                     | CD-03 raised.                                  |
+-------------------------------------+------------------------------------------------+
| **Architecture Standards**          | No document numbers generated (approval        |
|                                     | transaction --- no SEQUENCE required) │ All DB |
|                                     | via Dapper │ No schema changes to existing     |
|                                     | tables │ Audit: LogDet_PO                      |
|                                     | (Trans_Mod=\'MODIFY\' for approve;             |
|                                     | Trans_Mod=\'DELETE\' for delete-approval) │    |
|                                     | Concurrency: rowversion on PO_PRH and PO_PRL   |
|                                     | confirmed present in live DDL (verified        |
|                                     | 27-May-2026, Sasi). No ALTER TABLE required.   |
|                                     | OI-03 CLOSED. │ Division-scoped: all queries   |
|                                     | filtered by divcode │ User-level enforced at   |
|                                     | API level (see CD-05)                          |
+-------------------------------------+------------------------------------------------+
| **PULSE 360 Logging**               | FSD writing → \'Kalsofte SPINRISE FSD\'        |
|                                     | project ID │ Coding/API → \'Kalsofte SPINRISE  |
|                                     | Web ERP Dev\' │ IST review → \'Kalsofte        |
|                                     | SPINRISE Web ERP IST\'                         |
+-------------------------------------+------------------------------------------------+

+:------------------+:------------------+:-------------------+:------------------+:---------------------------+
| **2 Stage 0 Gate Results (Blueprint v6.0 --- Nine Gates)**                                                  |
+-------------------------------------------------------------------------------------------------------------+
| Blueprint v6 §5.1: Sasi is the only person who can issue Stage 0 sign-off. FULLY APPROVED by TL-Dev Sasi    |
| --- 21 May 2026. All 9 gates confirmed. 22 On Error GoTo handlers verified. No developer may open           |
| frmindentapp.frm in VB6 IDE.                                                                                |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **Gate**          | **Blueprint v6    | **Count**          | **Result**        | **Evidence & SPINRISE      |
|                   | Check**           |                    |                   | Action**                   |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G1**            | CustID blocks     | 0 active           | **PASS**          | Zero If CustID= branches   |
|                   | removed           |                    |                   | found in frmindentapp.frm. |
|                   |                   |                    |                   | Zero CustID in SPINRISE.   |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G2**            | Dead UI code      | 0                  | **PASS**          | PASS ✔ Stage 0 confirmed   |
|                   | removed           |                    |                   | by Sasi: ubGrid1           |
|                   |                   |                    |                   | (Visible=False) --- hidden |
|                   |                   |                    |                   | helper grid confirmed dead |
|                   |                   |                    |                   | UI, removed. Legacy        |
|                   |                   |                    |                   | text-mode print (Print #A) |
|                   |                   |                    |                   | --- dead print path,       |
|                   |                   |                    |                   | removed. SPINRISE: no dead |
|                   |                   |                    |                   | controls.                  |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G3**            | Commented-out     | 0                  | **PASS**          | PASS ✔ Stage 0 confirmed   |
|                   | code removed      |                    |                   | by Sasi: zero              |
|                   |                   |                    |                   | commented-out              |
|                   |                   |                    |                   | business-logic lines in    |
|                   |                   |                    |                   | cleaned code. Annotation   |
|                   |                   |                    |                   | comments for FIX markers   |
|                   |                   |                    |                   | retained by Sasi\'s        |
|                   |                   |                    |                   | direction. G3 PASS.        |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G4**            | Debug code        | 0 debug            | **PASS**          | PASS ✔ Stage 0 confirmed   |
|                   | removed           |                    |                   | by Sasi: zero Stop /       |
|                   |                   |                    |                   | MsgBox debug / Print debug |
|                   |                   |                    |                   | statements. SQL string     |
|                   |                   |                    |                   | concatenation is a G4 risk |
|                   |                   |                    |                   | --- NOTED (CD-01). All 8   |
|                   |                   |                    |                   | po_para reads use string   |
|                   |                   |                    |                   | concatenation --- CD-01    |
|                   |                   |                    |                   | and SPINRISE caching note  |
|                   |                   |                    |                   | added. G4 PASS (cleaned    |
|                   |                   |                    |                   | code); SPINRISE must use   |
|                   |                   |                    |                   | parameterised Dapper +     |
|                   |                   |                    |                   | po_para DTO.               |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G5**            | Deprecated API    | 8 OCX              | **PASS**          | PASS ✔ Stage 0 confirmed   |
|                   | calls flagged     |                    |                   | by Sasi: MSDATGRD.OCX      |
|                   |                   |                    |                   | (grddatagrid),             |
|                   |                   |                    |                   | MSDATLST.OCX, MSMASK32.OCX |
|                   |                   |                    |                   | (MaskEdBox x2),            |
|                   |                   |                    |                   | MSCOMCTL.OCX (stbar),      |
|                   |                   |                    |                   | TABCTL32.OCX (SSTab),      |
|                   |                   |                    |                   | MSCOMCT2.OCX (DTPicker),   |
|                   |                   |                    |                   | listacx.ocx (ubGrid1),     |
|                   |                   |                    |                   | Crystl32.OCX --- all       |
|                   |                   |                    |                   | flagged as G5. CD-03       |
|                   |                   |                    |                   | raised. SPINRISE: Ant      |
|                   |                   |                    |                   | Design Table, React        |
|                   |                   |                    |                   | DatePicker, React layout,  |
|                   |                   |                    |                   | QuestPDF.                  |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G6**            | Transaction       | PASS               | **PASS**          | PASS ✔ Stage 0 confirmed   |
|                   | integrity clean   |                    |                   | by Sasi: BeginTrans before |
|                   |                   |                    |                   | all approval-level DML     |
|                   |                   |                    |                   | loops, CommitTrans on      |
|                   |                   |                    |                   | success, RollbackTrans in  |
|                   |                   |                    |                   | BUTTON_Click_Error --- all |
|                   |                   |                    |                   | paths bounded. No          |
|                   |                   |                    |                   | double-commit. No empty    |
|                   |                   |                    |                   | pair. CRITICAL NOTE:       |
|                   |                   |                    |                   | Crystal print call         |
|                   |                   |                    |                   | (L2187--2190) is OUTSIDE   |
|                   |                   |                    |                   | the transaction block ---  |
|                   |                   |                    |                   | after CommitTrans. Sasi    |
|                   |                   |                    |                   | confirmed: print is        |
|                   |                   |                    |                   | post-commit. SPINRISE must |
|                   |                   |                    |                   | keep print fully separated |
|                   |                   |                    |                   | from save transaction (see |
|                   |                   |                    |                   | CD-05 and Business Rules   |
|                   |                   |                    |                   | §4).                       |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G7**            | Error handling    | 22 handlers        | **PASS**          | PASS ✔ Stage 0 confirmed   |
|                   | present           |                    |                   | by Sasi: 22 On Error GoTo  |
|                   |                   |                    |                   | handlers across the form   |
|                   |                   |                    |                   | --- excellent coverage.    |
|                   |                   |                    |                   | BUTTON_Click               |
|                   |                   |                    |                   | (BUTTON_Click_Error),      |
|                   |                   |                    |                   | Form_Load (Loaderr),       |
|                   |                   |                    |                   | delmodok_Click             |
|                   |                   |                    |                   | (delmodok_Click_Error),    |
|                   |                   |                    |                   | Command5_Click             |
|                   |                   |                    |                   | (Command5_Click_Error),    |
|                   |                   |                    |                   | FooterCmd_Click            |
|                   |                   |                    |                   | (FooterCmd_Click_Error),   |
|                   |                   |                    |                   | Form_Resize (unloaderr),   |
|                   |                   |                    |                   | adoPrimaryRS_MoveComplete  |
|                   |                   |                    |                   | (Error handler),           |
|                   |                   |                    |                   | grdDataGrid_AfterColUpdate |
|                   |                   |                    |                   | (Error handler),           |
|                   |                   |                    |                   | grdDataGrid_DblClick       |
|                   |                   |                    |                   | (Error handler),           |
|                   |                   |                    |                   | grdDataGrid_RowColChange   |
|                   |                   |                    |                   | (Error handler),           |
|                   |                   |                    |                   | Form_KeyDown               |
|                   |                   |                    |                   | (Form_KeyDown_Error),      |
|                   |                   |                    |                   | ubGrid1_AfterEdit (Error   |
|                   |                   |                    |                   | handler), DepLookup        |
|                   |                   |                    |                   | (DepLookup_Error), plus    |
|                   |                   |                    |                   | inline GoTo er1/Er/er      |
|                   |                   |                    |                   | handlers. Subs without     |
|                   |                   |                    |                   | handler: stock_find (DB    |
|                   |                   |                    |                   | lookup --- MED risk),      |
|                   |                   |                    |                   | ChkAll_Click (grid         |
|                   |                   |                    |                   | iteration), Command1_Click |
|                   |                   |                    |                   | (modal OK), Command2_Click |
|                   |                   |                    |                   | (modal cancel),            |
|                   |                   |                    |                   | Command4_Click (modal      |
|                   |                   |                    |                   | cancel) --- confirmed no   |
|                   |                   |                    |                   | DB ops in Command1/2/4.    |
|                   |                   |                    |                   | stock_find lack of handler |
|                   |                   |                    |                   | NOTED --- CD-02. SPINRISE: |
|                   |                   |                    |                   | all C# methods try-catch + |
|                   |                   |                    |                   | Serilog.                   |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G8**            | OERN removed      | 0 active           | **PASS**          | Zero On Error Resume Next  |
|                   |                   |                    |                   | found in frmindentapp.frm  |
|                   |                   |                    |                   | --- confirmed by grep      |
|                   |                   |                    |                   | scan.                      |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **G9**            | ig_param path     | 0 flags            | **PASS**          | Zero ig_param flags found. |
|                   | confirmed         |                    |                   | No orphaned flags. G9      |
|                   |                   |                    |                   | PASS.                      |
+-------------------+-------------------+--------------------+-------------------+----------------------------+
| **OVERALL**       | 9 PASS · 0 FAIL · | ---                | **PASS**          | FULLY APPROVED by TL-Dev   |
|                   | G4 SQL            |                    |                   | Sasi --- 21 May 2026. 22   |
|                   | concatenation     |                    |                   | On Error GoTo handlers     |
|                   | NOTED (CD-01) ·   |                    |                   | confirmed. No developer    |
|                   | G5 OCX flagged    |                    |                   | may open frmindentapp.frm  |
|                   | (CD-03) · G7      |                    |                   | in VB6 IDE.                |
|                   | stock_find        |                    |                   |                            |
|                   | handler gap NOTED |                    |                   |                            |
|                   | (CD-02) · Crystal |                    |                   |                            |
|                   | print/save        |                    |                   |                            |
|                   | separation NOTED  |                    |                   |                            |
|                   | (CD-05) · po_para |                    |                   |                            |
|                   | caching NOTED     |                    |                   |                            |
|                   | (CD-05)           |                    |                   |                            |
+-------------------+-------------------+--------------------+-------------------+----------------------------+

+:--------------+:--------------------+:------------------------+:-----------------+:--------------+:--------------+:-------------------+:--------------+
| **3 Field Table --- frmindentapp · Header Area**                                                                                                      |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Field /     | **AS-IS VB6**       | **SPINRISE TO-BE**      | **DB Column      | **Mandatory** | **Default**   | **Validation       | **Status**    |
| Rule**        |                     |                         | (table.column)** |               |               | Rule**             |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Form        | Purchase            | Purchase Requisition    | --- (display     | O ---         | ---           | Display only       | **AS-IS**     |
| Caption**     | Requisition         | Approval (React page    | only)            | Optional      |               |                    |               |
|               | Approval (window    | title)                  |                  |               |               |                    |               |
|               | title)              |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **PR No.      | Text box;           | Read-only field;        | PO_PRH.prno      | **M ---       | Blank --- set | Display only after | **AS-IS**     |
| (txtfields    | DataField=prno;     | populated after PR      | numeric(6,0) NOT | Mandatory**   | by lookup     | lookup             |               |
| 2)**          | right-aligned;      | selection from listing  | NULL             |               |               |                    |               |
|               | auto-populated from | modal                   |                  |               |               |                    |               |
|               | LookUp modal or     |                         |                  |               |               |                    |               |
|               | navigation          |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **PR Date     | MaskEdBox ---       | Read-only date display  | PO_PRH.prdate    | **M ---       | Blank --- set | Display only       | **CHANGED**   |
| (MaskEdBox1   | masked date         | after lookup; formatted | datetime NOT     | Mandatory**   | by lookup     |                    |               |
| index 0)**    | dd/MM/yyyy;         | dd/mm/yyyy              | NULL             |               |               |                    |               |
|               | DataField=prdate;   |                         |                  |               |               |                    |               |
|               | read-only after     |                         |                  |               |               |                    |               |
|               | lookup              |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Approve     | MaskEdBox ---       | Read-only if already    | PO_PRH.app1date  | **M ---       | pdate         | Must be \<= pdate. | **CHANGED**   |
| Date          | masked date         | approved; editable on   | / app2date /     | Mandatory**   | (current      | Error: \'Date      |               |
| (MaskEdBox1   | dd/MM/yyyy;         | approval action;        | app3date         |               | process date) | should be Equal to |               |
| index 1)**    | DataField=app1date; | defaults to current     | datetime NULL    |               |               | Current Date Or    |               |
|               | shows date of first | date (pdate); validated |                  |               |               | Max Purchase       |               |
|               | approval if already | against pdate (MsgBox   |                  |               |               | Requisition        |               |
|               | set; user enters    | if future date entered) |                  |               |               | Date\'.            |               |
|               | approve date on     |                         |                  |               |               |                    |               |
|               | save                |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Dept Code   | Text box;           | Read-only after lookup; | PO_PRH.depcode   | **M ---       | Blank --- set | Display only; key  | **AS-IS**     |
| (txtfields    | DataField=depcode;  | passed as parameter in  | varchar(3) NULL  | Mandatory**   | by lookup     | in DB updates      |               |
| 5)**          | auto-populated from | API                     |                  |               |               |                    |               |
|               | lookup; used as     |                         |                  |               |               |                    |               |
|               | WHERE key in all    |                         |                  |               |               |                    |               |
|               | UPDATEs             |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Dept Name   | Text box;           | Read-only auto-fill     | In_dep.Depname   | O ---         | Blank ---     | Display only       | **AS-IS**     |
| (Text2)**     | DataField=depname;  | from In_dep.Depname     | varchar          | Optional      | auto-fill     |                    |               |
|               | auto-filled from    |                         |                  |               |               |                    |               |
|               | IN_DEP join in      |                         |                  |               |               |                    |               |
|               | adoPrimaryRS        |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Ref No.     | Text box;           | Read-only after lookup  | PO_PRH.refno     | O ---         | Blank         | Display only       | **AS-IS**     |
| (txtfields    | DataField=refno;    |                         | varchar(20) NULL | Optional      |               |                    |               |
| 8)**          | MaxLength=20        |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Section     | Text box;           | Read-only after lookup  | PO_PRH.section   | O ---         | Blank         | Display only       | **AS-IS**     |
| (Text3)**     | DataField=section;  |                         | varchar(20) NULL | Optional      |               |                    |               |
|               | auto-filled from    |                         |                  |               |               |                    |               |
|               | PO_PRH.section      |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Sub Cost    | Text box;           | Read-only after lookup  | PO_PRH.SubCost   | O ---         | Blank         | Display only       | **AS-IS**     |
| (txtfields    | DataField=SubCost;  |                         | varchar NULL     | Optional      |               |                    |               |
| 3)**          | auto-filled from    |                         |                  |               |               |                    |               |
|               | PO_PRH.SubCost      |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **SubCost     | Text box;           | Read-only; joined from  | In_Scc.SccName   | O ---         | Blank         | Display only       | **AS-IS**     |
| Centre Name   | DataField=SccName;  | In_Scc.SccName on       | varchar          | Optional      |               |                    |               |
| (Text5)**     | auto-filled from    | SubCost+DivCode+DepCode |                  |               |               |                    |               |
|               | In_Scc join         |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **Approval    | Frame7 with 3       | Read-only badges (SM /  | PO_PRH.app1,     | O ---         | Blank (NULL = | Display only.      | **CHANGED**   |
| Level         | CheckBoxes (Index   | FM / GM) showing        | app2, app3       | Optional      | no approval   | Driven by          |               |
| (Check1:      | 0=GM, 1=FM, 2=SM)   | approval level already  | varchar NULL     |               | yet)          | app1/app2/app3 IS  |               |
| SM/FM/GM)**   | --- read-only       | granted; driven by      |                  |               |               | NOT NULL.          |               |
|               | display indicating  | app1, app2, app3 values |                  |               |               |                    |               |
|               | which approval      | from PO_PRH             |                  |               |               |                    |               |
|               | levels have been    |                         |                  |               |               |                    |               |
|               | recorded; not       |                         |                  |               |               |                    |               |
|               | user-editable       |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **app1 / app2 | Not shown on form   | Not shown on form; set  | PO_PRH.app1 /    | **M ---       | NULL          | Set to \'Y\' on    | **AS-IS**     |
| / app3**      | face; set           | via API based on user   | app2 / app3      | Mandatory**   |               | approve; set to    |               |
|               | programmatically in | level                   | varchar(1) NULL  |               |               | NULL on            |               |
|               | BUTTON_Click Save:  |                         |                  |               |               | delete-approval    |               |
|               | \'Y\' value written |                         |                  |               |               |                    |               |
|               | to app1, app2, or   |                         |                  |               |               |                    |               |
|               | app3 depending on   |                         |                  |               |               |                    |               |
|               | user level          |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+
| **DIVCODE     | DataField=DIVCODE   | Not displayed; passed   | PO_PRH.DIVCODE   | **M ---       | Session       | Not user-editable; | **AS-IS**     |
| (hidden       | on a hidden text    | from session context to | varchar(10) NOT  | Mandatory**   | divcode       | session-controlled |               |
| DataField)**  | box bound to        | all API calls           | NULL             |               |               |                    |               |
|               | adoPrimaryRS ---    |                         |                  |               |               |                    |               |
|               | ensures division    |                         |                  |               |               |                    |               |
|               | filtering           |                         |                  |               |               |                    |               |
+---------------+---------------------+-------------------------+------------------+---------------+---------------+--------------------+---------------+

+:-----------------+:--------------------------------------+:----------------+:----------------------+:--------------+:---------------------+:---------------+:--------------+
| **3 Field Table --- frmindentapp · Detail Grid (grddatagrid / ubGrid1 --- PO_PRL lines)**                                                                                  |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Field / Rule** | **AS-IS VB6**                         | **SPINRISE      | **DB Column           | **Mandatory** | **Default**          | **Validation   | **Status**    |
|                  |                                       | TO-BE**         | (table.column)**      |               |                      | Rule**         |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **PR No.**       | PO_PRL.prno --- grid column           | Read-only grid  | PO_PRL.prno numeric   | **M ---       | Blank --- from       | Display only   | **AS-IS**     |
|                  |                                       | column          |                       | Mandatory**   | header               |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **PR Date**      | PO_PRL.prdate --- grid column         | Read-only grid  | PO_PRL.prdate         | **M ---       | Blank --- from       | Display only   | **AS-IS**     |
|                  |                                       | column          | datetime              | Mandatory**   | header               |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **PR Sl. No.     | PO_PRL.prsno --- grid column; also in | Read-only grid  | PO_PRL.prsno numeric  | **M ---       | Blank --- from query | Display only;  | **AS-IS**     |
| (PRSNO)**        | ubGrid1 col 18 (SNO)                  | column; used as |                       | Mandatory**   |                      | key for row    |               |
|                  |                                       | key in UPDATE   |                       |               |                      | UPDATE         |               |
|                  |                                       | WHERE clause    |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Item Code**    | in_item.itemcode --- inner join       | Read-only grid  | in_item.itemcode      | **M ---       | Blank --- from query | Display only;  | **AS-IS**     |
|                  | column                                | column; used as | varchar(10)           | Mandatory**   |                      | key for row    |               |
|                  |                                       | key in UPDATE   |                       |               |                      | UPDATE         |               |
|                  |                                       | WHERE clause    |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Item           | in_item.itemname --- inner join       | Read-only grid  | in_item.Itemname      | O ---         | Blank --- from query | Display only   | **AS-IS**     |
| Description**    |                                       | column          | varchar               | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **UOM / Unit**   | in_item.Cuom / UOM --- inner join     | Read-only grid  | in_item.Cuom varchar  | O ---         | Blank --- from query | Display only   | **AS-IS**     |
|                  |                                       | column          |                       | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Rate**         | ISNULL(t.RATE,0) --- from PO_PRL /    | Editable for    | PO_PRL.rate           | O ---         | ISNULL(in_item.RATE, | Numeric \>= 0; | **CHANGED**   |
|                  | in_item; editable in ubGrid1 for      | First Approval  | numeric(15,5) │       | Optional      | 0)                   | value =        |               |
|                  | First Approval save (rate and value   | level only;     | PO_PRL.value          |               |                      | QTYREQD × rate |               |
|                  | written back)                         | auto-calculated | numeric(15,5)         |               |                      |                |               |
|                  |                                       | value = Qty     |                       |               |                      |                |               |
|                  |                                       | Approved × Rate |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Machine**      | mm_MACmas.Description --- left join   | Read-only grid  | mm_MACmas.Description | O ---         | Blank --- left join  | Display only   | **AS-IS**     |
|                  | on mac_no + depcode + divcode         | column          | varchar               | Optional      | (NULL if no machine) |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Current        | in_item.curstk / T.curstock ---       | Read-only       | IN_ITEM.CURSTK        | O ---         | ISNULL(curstk, 0)    | Display only   | **AS-IS**     |
| Stock**          | ISNULL(...,0)                         | numeric         | decimal(20,3) NULL    | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Qty Required   | PO_PRL.QTYIND --- ISNULL(...,0) ---   | Read-only       | PO_PRL.QTYIND         | **M ---       | ISNULL(QTYIND, 0)    | Display only   | **AS-IS**     |
| (QTYIND)**       | original requested quantity           | numeric, 3      | numeric(12,3)         | Mandatory**   |                      |                |               |
|                  |                                       | decimal         |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Qty Approved   | PO_PRL.QTYREQD --- editable in        | Editable for    | PO_PRL.QTYREQD        | **M ---       | Defaults to QTYIND   | Numeric \>= 0; | **CHANGED**   |
| (QTYREQD)**      | ubGrid1; written on First Approval    | First Approval  | numeric(12,3)         | Mandatory**   | value from PR line   | must be \<=    |               |
|                  | save (QTYREQD = FirstAppQty for this  | level; stored   |                       |               |                      | QTYIND. Blank  |               |
|                  | level)                                | as approved     |                       |               |                      | = not          |               |
|                  |                                       | quantity        |                       |               |                      | approved.      |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **FirstApp Qty   | Editable in ubGrid1 col 10; written   | Editable for    | PO_PRL.FirstAppQty    | **M ---       | 0.000                | Numeric \>= 0; | **AS-IS**     |
| (FirstAppQty)**  | to PO_PRL.FirstAppQty on First        | First Approval  | numeric(12,3) NULL │  | Mandatory**   |                      | FirstApp=\'Y\' |               |
|                  | Approval save. PO_PRL.FirstApp set to | level only      | PO_PRL.FirstApp       |               |                      | written        |               |
|                  | \'Y\' on save (triggers PRSTATUS →    |                 | char(1) NULL          |               |                      | atomically     |               |
|                  | \'F\').                               |                 |                       |               |                      | with           |               |
|                  |                                       |                 |                       |               |                      | FirstAppQty in |               |
|                  |                                       |                 |                       |               |                      | same           |               |
|                  |                                       |                 |                       |               |                      | transaction    |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **SecondApp Qty  | Editable in ubGrid1 col 11; written   | Display only in | PO_PRL.SecondAppQty   | O ---         | 0.000 --- written by | Display only   | **CHANGED**   |
| (SecondAppQty)** | on Second Approval save (out of scope | this form ---   | numeric(12,3) NULL    | Optional      | second level form    | in this form   |               |
|                  | for this form)                        | written by      |                       |               |                      |                |               |
|                  |                                       | Second Level    |                       |               |                      |                |               |
|                  |                                       | approval form   |                       |               |                      |                |               |
|                  |                                       | (see OI-08)     |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **ThirdApp Qty   | Editable in ubGrid1 col 12; written   | Display only in | PO_PRL.ThirdAppQty    | O ---         | 0.000 --- written by | Display only   | **CHANGED**   |
| (ThirdAppQty)**  | on Third Approval save (out of scope  | this form ---   | numeric(12,3) NULL    | Optional      | third level form     | in this form   |               |
|                  | for this form)                        | written by      |                       |               |                      |                |               |
|                  |                                       | Third Level     |                       |               |                      |                |               |
|                  |                                       | approval form   |                       |               |                      |                |               |
|                  |                                       | (see OI-08)     |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Qty Ordered**  | PO_PRL.QTYord --- ISNULL(...,0)       | Read-only       | PO_PRL.QTYord         | O ---         | ISNULL(QTYord, 0)    | Display only   | **AS-IS**     |
|                  |                                       | numeric, 3      | numeric(12,3)         | Optional      |                      |                |               |
|                  |                                       | decimal         |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Qty Received** | PO_PRL.qtyrec --- ISNULL(...,0)       | Read-only       | PO_PRL.qtyrec         | O ---         | ISNULL(qtyrec, 0)    | Display only   | **AS-IS**     |
|                  |                                       | numeric, 3      | numeric(12,3)         | Optional      |                      |                |               |
|                  |                                       | decimal         |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Required       | PO_PRL.reqddate --- display only;     | Read-only date  | PO_PRL.reqddate       | O ---         | NULL                 | Display only   | **AS-IS**     |
| Date**           | format dd/mm/yy in grid               | column          | datetime NULL         | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **PR Status**    | CASE PRSTATUS: O=ORDERED, E=ENQUIRED, | Status badge;   | PO_PRL.PRSTATUS       | O ---         | NULL (REQUESTED)     | Read-only;     | **AS-IS**     |
|                  | R/C=RECEIVED. If NULL: check          | read-only;      | char(1) NULL │        | Optional      |                      | system-managed |               |
|                  | FirstApp/SecondApp/ThirdApp/DirectApp | system-managed. | PO_PRL.FirstApp /     |               |                      |                |               |
|                  | flags for approval level label.       | PRSTATUS=\'F\'  | SecondApp / ThirdApp  |               |                      |                |               |
|                  |                                       | after First     | / DirectApp char(1)   |               |                      |                |               |
|                  |                                       | Level approval. | NULL                  |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Place of       | PO_PRL.place --- display only         | Read-only grid  | PO_PRL.place varchar  | O ---         | NULL                 | Display only   | **AS-IS**     |
| Issue**          |                                       | column          | NULL                  | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Approx. Cost** | PO_PRL.appcost --- ISNULL(...,0);     | Read-only       | PO_PRL.appcost        | O ---         | ISNULL(appcost, 0)   | Display only   | **AS-IS**     |
|                  | format ######0.00                     | numeric, 2      | numeric(11,2)         | Optional      |                      |                |               |
|                  |                                       | decimal         |                       |               |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Remarks**      | PO_PRL.remarks --- display only       | Read-only grid  | PO_PRL.remarks        | O ---         | NULL                 | Display only   | **AS-IS**     |
|                  |                                       | column          | varchar NULL          | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **BGRPCODE       | PO_PRL.BGRPCODE --- display only      | Read-only grid  | PO_PRL.BGRPCODE       | O ---         | NULL                 | Display only   | **AS-IS**     |
| (Budget Group)** |                                       | column          | varchar NULL          | Optional      |                      |                |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+
| **Pre-GST        | Not present --- preliminary scan      | Not applicable  | N/A                   | O ---         | N/A                  | No action      | **REMOVED**   |
| Fields**         | shows zero AED/BED/Cess/VAT/CST       |                 |                       | Optional      |                      | required       |               |
+------------------+---------------------------------------+-----------------+-----------------------+---------------+----------------------+----------------+---------------+

+:--------------+:-----------------------------------------+:-----------------------------------------+:---------------+:--------------+:--------------+
| **4 Business Rules (Approval Sequence · Transaction Boundaries · All Rules)**                                                                        |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Rule /      | **AS-IS VB6 Logic**                      | **SPINRISE TO-BE**                       | **Trigger**    | **DB Impact** | **Status**    |
| Event**       |                                          |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **User level  | BUTTON_Click Add (Case 0): queries       | API reads user level from                | BUTTON_Click   | READ          | **CHANGED**   |
| check on      | parameter table; sets dep variable       | session/parameter table. Returns HTTP    | Index=0 (Add)  | parameter     |               |
| Add/Modify**  | (department filter for user). Checks     | 403 if user does not match expected      | / Index=1      | table         |               |
|               | user level --- if not set, MsgBox \'Set  | approval level. Client shows error       | (Modify)       | (implicit)    |               |
|               | User Level In Parameter Form\'. Add      | message.                                 |                |               |               |
|               | shows checkrs listing for level=1 (no    |                                          |                |               |               |
|               | approvals yet). Modify shows listing for |                                          |                |               |               |
|               | user\'s current approval level.          |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Listing     | BUTTON_Click Add (Case 0): checkrs query | Dapper SP                                | Add / Modify   | READ PO_PRH,  | **CHANGED**   |
| query ---     | opens 3 variants by approval level: (1)  | (sp_PR_GetPending\[Level\]Approval)      | --- listing    | PO_PRL,       |               |
| level-aware** | All                                      | returns PRs eligible for the user\'s     | step           | in_dep,       |               |
|               | FirstApp/SecondApp/ThirdApp/DirectApp IS | approval level. React modal table shows  |                | in_item       |               |
|               | NULL = unapproved; (2) FirstApp NOT      | results. If 0 records: toast \'No        |                |               |               |
|               | NULL, rest NULL = pending SecondApp; (3) | Records Found\'.                         |                |               |               |
|               | FirstApp+SecondApp NOT NULL, ThirdApp    |                                          |                |               |               |
|               | NULL = pending ThirdApp. Lookup modal    |                                          |                |               |               |
|               | shows matching PRs.                      |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **PR          | After LookUp modal selection:            | Dapper: two queries --- header           | PR selected    | READ PO_PRH,  | **CHANGED**   |
| selection     | adoPrimaryRS SHAPE query loads PO_PRH    | (PO_PRH+IN_DEP+In_Scc) + lines           | from lookup    | PO_PRL,       |               |
| (adoPrimaryRS | header (divcode, prno, prdate, depcode,  | (PO_PRL+IN_ITEM+mm_MACmas). Compose into |                | In_dep,       |               |
| SHAPE)**      | depname, refno, itype, section, reqname, | C# DTO. Return as JSON. React binds      |                | In_item,      |               |
|               | app1/2/3, SubCost, SccName) + child      | header fields and Ant Design Table for   |                | mm_MACmas,    |               |
|               | PO_PRL lines (itemcode, description,     | lines.                                   |                | In_Scc        |               |
|               | UOM, rate, machine, curstock, QTYIND,    |                                          |                |               |               |
|               | QTYREQD, FirstAppQty, SecondAppQty,      |                                          |                |               |               |
|               | ThirdAppQty, QTYord, qtyrec, reqddate,   |                                          |                |               |               |
|               | PRSTATUS, place, appcost, remarks,       |                                          |                |               |               |
|               | BGRPCODE, prsno). 4 SHAPE variants by    |                                          |                |               |               |
|               | approval level active for user.          |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Approve     | On Save: MaskEdBox1(1).Text (approve     | API validates approve date \<= pdate     | Save ---       | None          | **AS-IS**     |
| date          | date) must equal pdate (process date) or | from session. Returns HTTP 422 if        | before DB      |               |               |
| validation**  | the maximum PR date. If date is future   | invalid date. React shows validation     | writes         |               |               |
|               | date: MsgBox \'Date should be Equal to   | message.                                 |                |               |               |
|               | Current Date Or Max Purchase Requisition |                                          |                |               |               |
|               | Date\'.                                  |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **First Level | UPDATE PO_PRH SET appflg=\'Y\',          | Dapper: UPDATE PO_PRH (appflg, app1,     | Save --- First | UPDATE        | **AS-IS**     |
| Approval ---  | app1=@app1_code, APP1DATE=@approvedate,  | APP1DATE, APP1TIME). Loop approved       | Approval       | PO_PRH,       |               |
| DB writes     | APP1TIME=@time WHERE                     | lines: UPDATE PO_PRL (QTYREQD,           |                | UPDATE PO_PRL |               |
| (this form    | divcode+prno+prdate. Then loop all       | FirstAppQty, rate, value). All inside    |                | (per line)    |               |
| only)**       | ubGrid1 rows: UPDATE PO_PRL SET          | BeginTransaction.                        |                |               |               |
|               | QTYREQD=@qty, FirstAppQty=@firstappqty,  |                                          |                |               |               |
|               | rate=@rate, value=@qty\*@rate WHERE      |                                          |                |               |               |
|               | prno+prdate+itemcode+prsno. CEO          |                                          |                |               |               |
|               | confirmed (21 May 2026): this form       |                                          |                |               |               |
|               | handles First Level only. Second Level   |                                          |                |               |               |
|               | and above are handled by a separate form |                                          |                |               |               |
|               | (see OI-08).                             |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Second      | frmindentapp.frm confirmed as First      | SPINRISE: Second Level approval form     | N/A ---        | N/A ---       | REMOVED       |
| Level         | Level approval form only (CEO 21 May     | will have its own FSD. This FSD covers   | separate FSD   | separate form |               |
| Approval and  | 2026). Second Level, Third Level, and    | First Level only. See OI-08 for          |                |               |               |
| above --- OUT | Direct (final) approval --- if handled   | multi-level workflow confirmation.       |                |               |               |
| OF SCOPE for  | by a separate form (e.g. INDAPP.frm) --- |                                          |                |               |               |
| this FSD**    | are out of scope for this document.      |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Audit log   | Inside BeginTrans, after all PO_PRL      | Dapper INSERT LogDet_PO per approved     | Save --- per   | INSERT        | **AS-IS**     |
| --- INSERT    | UPDATEs, INSERT LogDet_PO per line:      | line inside same BeginTransaction.       | line           | LogDet_PO     |               |
| LogDet_PO**   | (divcode, prno, prdate, itemcode,        | Trans_Mod=\'MODIFY\'. Atomic.            |                | (per line)    |               |
|               | depcode, Trans_UserId, prsno,            |                                          |                |               |               |
|               | quantity=QTYREQD, username,              |                                          |                |               |               |
|               | Trans_date=Now, Trans_Name=\'Purchase    |                                          |                |               |               |
|               | Requisition Approval\',                  |                                          |                |               |               |
|               | Trans_Mod=\'MODIFY\', Trans_IPADD,       |                                          |                |               |               |
|               | Trans_Host, UOM, rate, macno, SubCost,   |                                          |                |               |               |
|               | moduleNo, docno=prno, docdt=prdate).     |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Transaction | db.BeginTrans → UPDATE PO_PRH → loop     | Dapper BeginTransaction wrapping UPDATE  | Save (any      | All DML in    | **AS-IS**     |
| boundary ---  | (UPDATE PO_PRL + INSERT LogDet_PO per    | PO_PRH + all PO_PRL UPDATEs + all        | level)         | single        |               |
| approval**    | line) → db.CommitTrans. RollbackTrans in | LogDet_PO INSERTs. RollbackAsync on any  |                | transaction   |               |
|               | BUTTON_Click_Error handler.              | exception.                               |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Delete      | BUTTON_Click Delete: Lookup shows PRs    | Dapper: Three delete-level paths. Each   | Delete ---     | UPDATE        | **AS-IS**     |
| First Level   | where FirstApp IS NOT NULL AND DirectApp | resets the appropriate PO_PRH and PO_PRL | approval       | PO_PRH,       |               |
| Approval ---  | IS NULL. User selects a PR. Delete path: | approval columns inside                  | rollback       | UPDATE        |               |
| DB writes     | (a) Delete First only                    | BeginTransaction. INSERT LogDet_PO       |                | PO_PRL,       |               |
| (this form    | (app1+SecondApp+ThirdApp all NULL after  | Trans_Mod=\'DELETE\'. No physical row    |                | INSERT        |               |
| only)**       | delete): UPDATE PO_PRH SET appflg=\'N\', | deletion.                                |                | LogDet_PO     |               |
|               | app1/2/3=null, app1/2/3date=null,        |                                          |                |               |               |
|               | app1/2/3time=null. UPDATE PO_PRL SET     |                                          |                |               |               |
|               | qtyreqd=null, FirstAppQty=0,             |                                          |                |               |               |
|               | FirstApp=null, Prstatus=null WHERE       |                                          |                |               |               |
|               | DirectApp IS NULL. (b) Delete Second     |                                          |                |               |               |
|               | (ThirdApp is NULL after): UPDATE PO_PRH  |                                          |                |               |               |
|               | reset. UPDATE PO_PRL SET qtyreqd=null,   |                                          |                |               |               |
|               | SecondAppQty=0, SecondApp=null,          |                                          |                |               |               |
|               | Prstatus=\'F\' WHERE DirectApp IS NULL   |                                          |                |               |               |
|               | AND ThirdApp IS NULL. (c) Delete Third:  |                                          |                |               |               |
|               | UPDATE PO_PRL SET qtyreqd=null,          |                                          |                |               |               |
|               | ThirdAppQty=0, ThirdApp=null,            |                                          |                |               |               |
|               | Prstatus=\'S\' WHERE DirectApp IS NULL   |                                          |                |               |               |
|               | AND ThirdApp IS NOT NULL. INSERT         |                                          |                |               |               |
|               | LogDet_PO Trans_Mod=\'DELETE\' per row.  |                                          |                |               |               |
|               | db.CommitTrans.                          |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Print ---   | Crystal print call                       | SPINRISE: (1) POST                       | Post-save      | READ PO_PRH,  | **CHANGED**   |
| separated     | (Cry_PO_IndentcrTransPrint.CrystalPrint, | /api/pr-approval/{prno}/{prdate}/approve | (separate      | PO_PRL (for   |               |
| from save     | L2187--2190) is called after             | → saves, commits, returns success. (2)   | action)        | report data   |               |
| transaction   | db.CommitTrans in BUTTON_Click. Print is | Separate POST                            |                | only; no DML  |               |
| (CEO          | already outside the transaction block in | /api/pr-approval/{prno}/{prdate}/print → |                | in print      |               |
| directive 21  | VB6. CEO directive: SPINRISE must make   | generates QuestPDF PrApprovalReport.     |                | endpoint)     |               |
| May 2026)**   | this separation explicit --- print must  | Print button enabled only after          |                |               |               |
|               | be a dedicated separate API call. Save → | successful save. If print endpoint       |                |               |               |
|               | CommitTrans → client receives success →  | fails: React toast \'Approval saved.     |                |               |               |
|               | user clicks Print → separate print API   | Print failed --- use Reprint.\' Reprint  |                |               |               |
|               | call. If print fails, the approval       | allowed at any time after approval.      |                |               |               |
|               | record stands (already committed). User  |                                          |                |               |               |
|               | is notified to reprint. Blocked if       |                                          |                |               |               |
|               | DirectApp\<\>\'Y\' on all PO_PRL lines   |                                          |                |               |               |
|               | (MsgBox \'Final Level Approval not       |                                          |                |               |               |
|               | completed\' in VB6).                     |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **po_para     | All 8 po_para reads across multiple subs | SPINRISE: Read po_para ONCE at page load | Page load      | READ po_para  | **CHANGED**   |
| reads ---     | (Form_Load, BUTTON_Click variants,       | in a single parameterised Dapper call:   | (once)         | (once only)   |               |
| caching (CEO  | DepLookup, stock_find, and others) use   | SELECT \* FROM po_para WHERE divcode =   |                |               |               |
| directive 21  | SELECT \* FROM po_para WHERE             | \@divcode. Map to a PoParaDto cached in  |                |               |               |
| May 2026)**   | divcode=\'\...\' --- string              | controller/service layer for the         |                |               |               |
|               | concatenation AND repeated DB            | lifetime of the request (or React        |                |               |               |
|               | round-trips per sub. CEO directive:      | session state). All subs that currently  |                |               |               |
|               | redundant round-trips identified.        | call po_para individually will read from |                |               |               |
|               |                                          | PoParaDto in memory. Zero repeated       |                |               |               |
|               |                                          | SELECT \* on po_para in SPINRISE.        |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Cancel /    | BUTTON_Click(10): SetGridHead,           | Reset toolbar action --- no DB write.    | Cancel /       | None          | **AS-IS**     |
| Reset**       | Opt=\'Qry\', NEWFORM(). No DB write.     | Returns to Query mode.                   | Ctrl+Backspace |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Keyboard    | Ctrl+M=Modify, Ctrl+S=Save,              | Implement equivalent keyboard shortcuts  | Any time       | None          | **AS-IS**     |
| shortcuts**   | Ctrl+Backspace=Cancel, Ctrl+Q=Exit,      | in React.                                |                |               |               |
|               | Esc=Quit. F10 (Print). Implemented in    |                                          |                |               |               |
|               | Form_KeyDown with On Error GoTo          |                                          |                |               |               |
|               | Form_KeyDown_Error.                      |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Division    | All queries and UPDATEs filtered by      | divcode from session context ---         | All operations | All DML       | **AS-IS**     |
| scope**       | global divcode.                          | enforced at API level.                   |                | tables        |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+
| **Financial   | Listing queries filter prdate BETWEEN    | yfdate + yldate from session context.    | Listing        | READ only     | **AS-IS**     |
| year scope**  | yfdate AND yldate. Direct approval       | Applied as parameters in SP listing      | queries        |               |               |
|               | (Delete) listing also uses               | queries.                                 |                |               |               |
|               | yfdate/yldate.                           |                                          |                |               |               |
+---------------+------------------------------------------+------------------------------------------+----------------+---------------+---------------+

+:------------------------------------+:-----------------------------------------------+
| **5 Print Replacement (Crystal Reports → QuestPDF)**                                 |
+-------------------------------------+------------------------------------------------+
| **VB6 Report File**                 | RepPO.rpt (located at KALFOLDERDATA path)      |
+-------------------------------------+------------------------------------------------+
| **VB6 Parameters**                  | \@Divcode │ \@Prno │ \@PrDate                  |
+-------------------------------------+------------------------------------------------+
| **Trigger Condition**               | Triggered in BUTTON_Click after db.CommitTrans |
|                                     | only when DirectApp=\'Y\' found on at least    |
|                                     | one PO_PRL row. Blocked with MsgBox otherwise. |
+-------------------------------------+------------------------------------------------+
| **QuestPDF Class Name**             | PrApprovalReport (SPINRISE replacement class)  |
+-------------------------------------+------------------------------------------------+
| **Report Content**                  | PR header: PR No., PR Date, Department, Ref    |
|                                     | No., Section, Sub Cost Centre, Requester.      |
|                                     | Lines: SNO, Item Code, Description, UOM, Qty   |
|                                     | Required, Qty Approved, Rate, Remarks.         |
|                                     | Approval stamp: Approver name, Approval Date,  |
|                                     | Approval Level.                                |
+-------------------------------------+------------------------------------------------+
| **Re-print Control**                | Re-print control: PO_PRINT_LOG not applicable  |
|                                     | to this form. No schema action required. See   |
|                                     | OI-04.                                         |
+-------------------------------------+------------------------------------------------+
| **Additional Print**                | VB6 also has a legacy text-mode print (Print   |
|                                     | #A to file \'ind.txt\' then \'type             |
|                                     | ind.txt\>prn\') --- to be assessed at Stage 0. |
|                                     | SPINRISE: replace entirely with                |
|                                     | PrApprovalReport QuestPDF output.              |
+-------------------------------------+------------------------------------------------+

+:------------------------------------+:-----------------------------------------------+
| **6 Customer Variations**                                                            |
+-------------------------------------+------------------------------------------------+
| **Approval Level Config**           | The dep variable (department/user-level        |
|                                     | filter) and approval level routing (SM/FM/GM)  |
|                                     | are read from a parameter table at Form_Load.  |
|                                     | This is the SPINRISE configuration point ---   |
|                                     | not a CustID block. SPINRISE reads user        |
|                                     | approval level from user session at API. No    |
|                                     | customer-specific code branching.              |
+-------------------------------------+------------------------------------------------+
| **SPINRISE Config**                 | Standard approval behaviour for all customers. |
|                                     | No customer-specific logic.                    |
+-------------------------------------+------------------------------------------------+

+:--------------------------------------+:-------------------+:-------------------+:-------------------------------+
| **6 DB Migration (Execute Once Per Database --- After CEO Countersignature)**                                    |
+------------------------------------------------------------------------------------------------------------------+
| **⚠ EXECUTION CONTROL: Execute only after CEO countersignature. Not to be run in any live customer database      |
| before CEO approval is received.**                                                                               |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **Object**                            | **Type**           | **Action**         | **Purpose / Notes**            |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **sp_PR_GetPendingFirstApproval**     | Stored Procedure   | CREATE --- deploy  | Parameters: \@divcode          |
|                                       | --- NEW            | before go-live     | varchar(10), \@dep varchar.    |
|                                       |                    |                    | Note: Year guard NOT required  |
|                                       |                    |                    | --- no \@yfdate / \@yldate     |
|                                       |                    |                    | parameters. Encapsulates       |
|                                       |                    |                    | listing query: PRs where       |
|                                       |                    |                    | FirstApp IS NULL AND SecondApp |
|                                       |                    |                    | IS NULL AND ThirdApp IS NULL   |
|                                       |                    |                    | AND DirectApp IS NULL AND      |
|                                       |                    |                    | cancelflag\<\>\'Y\' AND        |
|                                       |                    |                    | FClosed\<\>\'Y\',              |
|                                       |                    |                    | divcode=@divcode. Department   |
|                                       |                    |                    | filter \@dep applied per user  |
|                                       |                    |                    | level.                         |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **sp_PR_GetFirstApprovedForDeletion** | Stored Procedure   | CREATE --- deploy  | Parameters: \@divcode          |
|                                       | --- NEW            | before go-live     | varchar(10). Note: Year guard  |
|                                       |                    |                    | NOT required --- no \@yfdate / |
|                                       |                    |                    | \@yldate parameters. PRs where |
|                                       |                    |                    | FirstApp IS NOT NULL AND       |
|                                       |                    |                    | DirectApp IS NULL AND          |
|                                       |                    |                    | cancelflag\<\>\'Y\'. Supports  |
|                                       |                    |                    | Delete-Approval listing.       |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **LogDet_PO --- schema verify**       | Table --- verify   | Confirm columns    | Approval INSERT uses: divcode, |
|                                       | existing columns   | present            | prno, prdate, itemcode,        |
|                                       |                    |                    | depcode, Trans_UserId, prsno,  |
|                                       |                    |                    | quantity, username,            |
|                                       |                    |                    | Trans_date, Trans_Name,        |
|                                       |                    |                    | Trans_Mod, Trans_IPADD,        |
|                                       |                    |                    | Trans_Host, UOM, rate, macno,  |
|                                       |                    |                    | SubCost, moduleNo, docno,      |
|                                       |                    |                    | docdt. Verify all 21 columns   |
|                                       |                    |                    | exist in live DDL. Confirm     |
|                                       |                    |                    | quantity column numeric        |
|                                       |                    |                    | precision (numeric(15,3) per   |
|                                       |                    |                    | confirmed DDL).                |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **PO_PRL.FirstApp / SecondApp /       | Columns ---        | Verify in DDL      | Confirm char(1) NULL --- all   |
| ThirdApp / DirectApp**                | CONFIRM EXISTS     |                    | four approval flag columns. No |
|                                       |                    |                    | ALTER required if present.     |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **PO_PRL.FirstAppQty / SecondAppQty / | Columns ---        | Verify in DDL      | Confirm numeric(12,3) NULL --- |
| ThirdAppQty**                         | CONFIRM EXISTS     |                    | three approval quantity        |
|                                       |                    |                    | columns. No ALTER required if  |
|                                       |                    |                    | present.                       |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **PO_PRH.app1 / app2 / app3 /         | Columns ---        | Verify in DDL      | Confirm app1/app2/app3 varchar |
| appflg**                              | CONFIRM EXISTS     |                    | NULL and appflg char(1) NULL.  |
|                                       |                    |                    | No ALTER required if present.  |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **PO_PRH.app1date / app2date /        | Columns ---        | Verify in DDL      | Confirm datetime NULL. No      |
| app3date**                            | CONFIRM EXISTS     |                    | ALTER required if present.     |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **PO_PRH.app1time / app2time /        | Columns ---        | Verify in DDL      | Confirm varchar or time NULL.  |
| app3time**                            | CONFIRM EXISTS     |                    | No ALTER required if present.  |
+---------------------------------------+--------------------+--------------------+--------------------------------+
| **PO_PRL.SecondAppUser /              | Columns ---        | Verify in DDL      | Written by SecondApp and       |
| ThirdAppUser**                        | CONFIRM EXISTS     |                    | ThirdApp save paths. Confirm   |
|                                       |                    |                    | varchar NULL in live DDL.      |
|                                       |                    |                    | Raise OI if missing --- may    |
|                                       |                    |                    | require ALTER TABLE PO_PRL ADD |
|                                       |                    |                    | SecondAppUser varchar(50)      |
|                                       |                    |                    | NULL, ThirdAppUser varchar(50) |
|                                       |                    |                    | NULL.                          |
+---------------------------------------+--------------------+--------------------+--------------------------------+

+:------------------+:------------------+:----------------------------+:------------------+:------------------------------+
| **7 Critical Defects (Must Not Be Carried Into SPINRISE)**                                                              |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD No**         | **Defect**        | **Detail**                  | **Risk**          | **SPINRISE Fix**              |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-01**         | **SQL string      | All DB queries in           | **HIGH**          | Dapper \@parameter binding    |
|                   | concatenation     | BUTTON_Click (checkrs open, |                   | throughout all C# API         |
|                   | throughout**      | adoPrimaryRS SHAPE          |                   | endpoints. SPs for all lookup |
|                   |                   | queries), UPDATE PO_PRH,    |                   | and listing queries. Zero     |
|                   |                   | UPDATE PO_PRL, INSERT       |                   | string-concat SQL in          |
|                   |                   | LogDet_PO, and DepLookup    |                   | SPINRISE.                     |
|                   |                   | use & string concatenation  |                   |                               |
|                   |                   | --- SQL injection risk      |                   |                               |
|                   |                   | throughout the entire form. |                   |                               |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-02**         | **G7 --- subs     | stock_find performs a DB    | **MED**           | SPINRISE: All API methods     |
|                   | with DB ops have  | lookup (in_item) with no On |                   | (GetEligiblePRs, GetPRDetail, |
|                   | no error          | Error GoTo handler. Silent  |                   | ApprovePR, DeleteApproval) in |
|                   | handler**         | failure returns 0 without   |                   | try-catch with Serilog        |
|                   |                   | logging. Command5_Click has |                   | structured logging. No silent |
|                   |                   | On Error GoTo but must be   |                   | failures. React toast         |
|                   |                   | verified for all paths.     |                   | notification on API error.    |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-03**         | **Eight OCX/COM   | grddatagrid (MSDATGRD.OCX), | **HIGH**          | Ant Design Table with         |
|                   | dependencies**    | ubGrid1 (listacx.ocx),      |                   | editable qty columns (grid),  |
|                   |                   | MaskEdBox (MSMASK32.OCX     |                   | React DatePicker (date        |
|                   |                   | x2), DTPicker               |                   | fields), React layout (status |
|                   |                   | (MSCOMCT2.OCX), stbar       |                   | bar / tabs), QuestPDF (print  |
|                   |                   | (MSCOMCTL.OCX), SSTab       |                   | --- see Section 5). Zero OCX  |
|                   |                   | (TABCTL32.OCX),             |                   | in SPINRISE.                  |
|                   |                   | CrystalReport1              |                   |                               |
|                   |                   | (Crystl32.OCX) --- all      |                   |                               |
|                   |                   | Windows COM. Cannot run in  |                   |                               |
|                   |                   | browser.                    |                   |                               |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-04**         | **SHAPE recordset | adoPrimaryRS uses OLE DB    | **HIGH**          | SPINRISE: Two separate Dapper |
|                   | / MSDataShape     | SHAPE command (MSDataShape  |                   | queries --- header query      |
|                   | provider**        | provider) for parent-child  |                   | (PO_PRH+IN_DEP+In_Scc) and    |
|                   |                   | hierarchy --- Windows-only  |                   | lines query                   |
|                   |                   | ADO feature with no web     |                   | (PO_PRL+IN_ITEM+mm_MACmas)    |
|                   |                   | equivalent.                 |                   | --- composed into a C# DTO    |
|                   |                   |                             |                   | and returned as JSON to       |
|                   |                   |                             |                   | React. No SHAPE in SPINRISE.  |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-05**         | **Crystal print   | CEO directive 21 May 2026:  | **HIGH**          | SPINRISE: Save and Print are  |
|                   | action must be    | Crystal print call          |                   | two separate API endpoints.   |
|                   | separated from    | (L2187--2190) is called     |                   | POST                          |
|                   | save              | after CommitTrans. If print |                   | /api/pr-approval/\.../approve |
|                   | transaction**     | fails post-commit, approval |                   | commits the approval. POST    |
|                   |                   | record is already committed |                   | /api/pr-approval/\.../print   |
|                   |                   | --- rollback not possible.  |                   | generates QuestPDF. Client    |
|                   |                   | SPINRISE must not couple    |                   | calls save first, then offers |
|                   |                   | print to the save API call. |                   | print. If print fails,        |
|                   |                   |                             |                   | approval record stands. User  |
|                   |                   |                             |                   | notified to reprint.          |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-06**         | **po_para read    | All 8 po_para reads use     | **MED**           | SPINRISE: single              |
|                   | repeated 8 times  | SELECT \* FROM po_para      |                   | parameterised Dapper call at  |
|                   | with string       | WHERE divcode=\'\...\'      |                   | page load --- WHERE divcode = |
|                   | concatenation**   | string concatenation.       |                   | \@divcode --- result mapped   |
|                   |                   | Redundant repeated DB       |                   | to PoParaDto. All subs        |
|                   |                   | round-trips per sub. CEO    |                   | consume PoParaDto in memory.  |
|                   |                   | directive 21 May 2026: read |                   | Zero repeated DB round-trips. |
|                   |                   | once, cache in DTO.         |                   | Zero string-concat in po_para |
|                   |                   |                             |                   | reads.                        |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+
| **CD-07**         | **Approval level  | The dep variable and        | **MED**           | SPINRISE: User approval level |
|                   | hard-coded to     | user-level parameter are    |                   | read from user                |
|                   | user variable     | set at Form_Load from a     |                   | session/parameter table at    |
|                   | (dep)**           | parameter table. Approval   |                   | API level. API enforces level |
|                   |                   | routing                     |                   | eligibility before any DB     |
|                   |                   | (First/Second/Third/Direct) |                   | write. Return HTTP 403 if     |
|                   |                   | is driven by user-level     |                   | user level does not match the |
|                   |                   | checks with MsgBox \'Not    |                   | expected approval stage.      |
|                   |                   | Approved User Level\' on    |                   |                               |
|                   |                   | mismatch. Hard-coded level  |                   |                               |
|                   |                   | branching in BUTTON_Click.  |                   |                               |
+-------------------+-------------------+-----------------------------+-------------------+-------------------------------+

+:--------------+:------------------+:----------------------------------+:--------------+:--------------+:-----------------+
| **8 Open Items**                                                                                                         |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI No**     | **Item**          | **Resolution**                    | **Status**    | **Owner**     | **DB / Schema    |
|               |                   |                                   |               |               | Impact**         |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-01**     | **CEO Working     | Confirmed waived by CEO T. Mani   | **CLOSED**    | CEO T. Mani   | No schema        |
|               | Session**         | (email 21 May 2026). Stage 1 FSD  |               |               | impact.          |
|               |                   | preparation may commence. Submit  |               |               |                  |
|               |                   | to Sasi latest by 22 May 2026.    |               |               |                  |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-02**     | **SPINRISE SP     | Only TWO SPs apply to First Level | **CLOSED**    | Sasi (Stage   | CREATE new SPs   |
|               | names for         | Approval.                         |               | 2)            | per Section 6.   |
|               | approval listing  | sp_PR_GetPendingSecondApproval    |               |               | No existing VB6  |
|               | queries**         | and sp_PR_GetPendingThirdApproval |               |               | SPs.             |
|               |                   | removed --- these belong to       |               |               |                  |
|               |                   | Second and Third Level Approval   |               |               |                  |
|               |                   | forms only. Confirmed SPs: (1)    |               |               |                  |
|               |                   | sp_PR_GetPendingFirstApproval --- |               |               |                  |
|               |                   | \@divcode varchar(10), \@dep      |               |               |                  |
|               |                   | varchar. Note: Year guard NOT     |               |               |                  |
|               |                   | required. No \@yfdate / \@yldate  |               |               |                  |
|               |                   | parameters. (2)                   |               |               |                  |
|               |                   | sp_PR_GetFirstApprovedForDeletion |               |               |                  |
|               |                   | --- \@divcode varchar(10). Note:  |               |               |                  |
|               |                   | Year guard NOT required. No       |               |               |                  |
|               |                   | \@yfdate / \@yldate parameters.   |               |               |                  |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-03**     | **Concurrency --- | PO_PRH.row_version ROWVERSION NOT | **CLOSED**    | Sasi / CEO    | No schema action |
|               | rowversion on     | NULL and PO_PRL.row_version       |               |               | required. Both   |
|               | PO_PRH / PO_PRL** | ROWVERSION NOT NULL confirmed     |               |               | columns          |
|               |                   | present in live DDL --- verified  |               |               | confirmed        |
|               |                   | 27-May-2026 (Sasi). No ALTER      |               |               | present in live  |
|               |                   | TABLE required.                   |               |               | DDL.             |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-04**     | **Re-print        | PO_PRINT_LOG not applicable to PR | CLOSED        | Sasi (Stage   | No schema action |
|               | control ---       | First Level Approval. No schema   |               | 2)            | required for     |
|               | RepPO.rpt**       | action required for this form.    |               |               | this form.       |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-05**     | **DirectApp ---   | VB6 code references               | **OPEN**      | Sasi / CEO    | If DirectApp is  |
|               | fourth approval   | DirectApp=\'Y\' as a \'Final      |               |               | set in this      |
|               | level**           | Level Approved\' state (PRSTATUS  |               |               | form: additional |
|               |                   | label) and as the condition for   |               |               | UPDATE PO_PRL    |
|               |                   | print unlock. However, no         |               |               | SET              |
|               |                   | BUTTON_Click path in the visible  |               |               | DirectApp=\'Y\'  |
|               |                   | code sets DirectApp=\'Y\'.        |               |               | inside the       |
|               |                   | Confirm whether DirectApp is set  |               |               | approval         |
|               |                   | by a separate form (e.g. a GM     |               |               | transaction for  |
|               |                   | direct-approval path) or whether  |               |               | the              |
|               |                   | it is set in this form at a       |               |               | highest-level    |
|               |                   | specific user level.              |               |               | approver. Schema |
|               |                   |                                   |               |               | confirm:         |
|               |                   |                                   |               |               | PO_PRL.DirectApp |
|               |                   |                                   |               |               | char(1) NULL.    |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-06**     | **IST ---         | IST to confirm whether any active | **OPEN**      | Palanivel     | No schema        |
|               | customer pain     | customer has raised a support     |               | (TL-IST)      | impact.          |
|               | points on         | call regarding approval level     |               |               |                  |
|               | approval levels** | restrictions (e.g. bypassing      |               |               |                  |
|               |                   | Second approval, partial approval |               |               |                  |
|               |                   | of lines). IST one-page note due  |               |               |                  |
|               |                   | in parallel with Stage 3 review.  |               |               |                  |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-07**     | **Delete-Approval | VB6 Delete path supports both     | **OPEN**      | CEO T. Mani / | No schema        |
|               | --- line-level vs | line-level deletion               |               | Sasi          | change. Logic    |
|               | header delete     | (grddatagrid.Columns used per     |               |               | choice only.     |
|               | scope**           | row) and full-header reset (all   |               |               |                  |
|               |                   | lines in the PR). Confirm with    |               |               |                  |
|               |                   | CEO whether SPINRISE should       |               |               |                  |
|               |                   | support per-line delete-approval  |               |               |                  |
|               |                   | or header-level only.             |               |               |                  |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+
| **OI-08**     | **PR Approval     | CEO confirmed: frmindentapp.frm   | **OPEN**      | Palanivel     | No schema        |
|               | workflow ---      | is the First Level approval form  |               | (TL-IST) /    | change. SPINRISE |
|               | multi-level scope | only. Multi-level workflow        |               | Sasi          | API must enforce |
|               | (CEO directive 21 | questions to be confirmed by      |               |               | correct level    |
|               | May 2026)**       | Palanivel (TL-IST): (1) How many  |               |               | sequencing.      |
|               |                   | approval levels are in the PR     |               |               | Second Level     |
|               |                   | workflow? (2) Which form handles  |               |               | approval form    |
|               |                   | Second Level approval ---         |               |               | will require its |
|               |                   | INDAPP.frm or another form? (3)   |               |               | own FSD.         |
|               |                   | What is the PRSTATUS transition   |               |               |                  |
|               |                   | at each level (REQUESTED → FIRST  |               |               |                  |
|               |                   | LEVEL APPROVED → SECOND LEVEL     |               |               |                  |
|               |                   | APPROVED → ...)? (4) Can a PR     |               |               |                  |
|               |                   | proceed to enquiry after First    |               |               |                  |
|               |                   | Level only, or must all levels be |               |               |                  |
|               |                   | completed? (5) Is Direct (final)  |               |               |                  |
|               |                   | level approval a separate form or |               |               |                  |
|               |                   | a path in the same form for       |               |               |                  |
|               |                   | certain user levels?              |               |               |                  |
+---------------+-------------------+-----------------------------------+---------------+---------------+------------------+

+:-----------------+:-----------------+:-----------------+:-----------------+:-----------------+
| **9 Review Chain & Sign-off**                                                                |
+----------------------------------------------------------------------------------------------+
| Blueprint v6 §4.2: CEO Working Session → Developer → TL-Dev Sasi (Stage 2) → TL-IST          |
| Palanivel (Stage 3) → CEO T. Mani (Stage 4). Target: 5 working days.                         |
+------------------+------------------+------------------+------------------+------------------+
| **Role**         | **Name**         | **Date**         | **Status**       | **Notes**        |
+------------------+------------------+------------------+------------------+------------------+
| **CEO Working    | T. Mani (CEO)    | 21 May 2026      | **✅ Confirmed   | CEO email 21 May |
| Session ---      |                  |                  | Waived**         | 2026: Stage 1    |
| Stage 0 Input**  |                  |                  |                  | FSD preparation  |
|                  |                  |                  |                  | may commence.    |
|                  |                  |                  |                  | Three directives |
|                  |                  |                  |                  | issued:          |
|                  |                  |                  |                  | print/save       |
|                  |                  |                  |                  | separation,      |
|                  |                  |                  |                  | po_para caching, |
|                  |                  |                  |                  | First Level      |
|                  |                  |                  |                  | scope            |
|                  |                  |                  |                  | confirmation.    |
+------------------+------------------+------------------+------------------+------------------+
| **Developer ---  | Mariyaiya        | 21 May 2026      | **✅ FSD v1.1    | All Blueprint v6 |
| Stage 1**        |                  |                  | Complete**       | §4.3 mandatory   |
|                  |                  |                  |                  | sections         |
|                  |                  |                  |                  | complete. Stage  |
|                  |                  |                  |                  | 0 FULLY APPROVED |
|                  |                  |                  |                  | by Sasi. CEO     |
|                  |                  |                  |                  | directives       |
|                  |                  |                  |                  | incorporated.    |
|                  |                  |                  |                  | Submitted to     |
|                  |                  |                  |                  | Sasi for Stage 2 |
|                  |                  |                  |                  | review 21 May    |
|                  |                  |                  |                  | 2026.            |
+------------------+------------------+------------------+------------------+------------------+
| **TL-Dev ---     | Sasi             | Target: 22 May   | ⏳ Awaited       | Stage 0 FULLY    |
| Stage 2**        |                  | 2026             |                  | APPROVED 21 May  |
|                  |                  |                  |                  | 2026. Stage 2    |
|                  |                  |                  |                  | technical        |
|                  |                  |                  |                  | review: DB       |
|                  |                  |                  |                  | columns, SP      |
|                  |                  |                  |                  | names,           |
|                  |                  |                  |                  | architecture,    |
|                  |                  |                  |                  | po_para caching, |
|                  |                  |                  |                  | print/save       |
|                  |                  |                  |                  | separation       |
|                  |                  |                  |                  | pattern,         |
|                  |                  |                  |                  | multi-level      |
|                  |                  |                  |                  | workflow OI-08.  |
+------------------+------------------+------------------+------------------+------------------+
| **TL-IST ---     | Palanivel        | Target: 23 May   | ⏳ Awaited       | Domain review.   |
| Stage 3**        |                  | 2026             |                  | Approval level   |
|                  |                  |                  |                  | configuration    |
|                  |                  |                  |                  | (SM/FM/GM        |
|                  |                  |                  |                  | checkbox),       |
|                  |                  |                  |                  | customer pain    |
|                  |                  |                  |                  | points, IST      |
|                  |                  |                  |                  | findings.        |
+------------------+------------------+------------------+------------------+------------------+
| **CEO --- Stage  | T. Mani          | Target: 23 May   | ⏳ Pending       | CEO              |
| 4**              |                  | 2026             |                  | countersignature |
|                  |                  |                  |                  | = locked         |
|                  |                  |                  |                  | development      |
|                  |                  |                  |                  | baseline. No     |
|                  |                  |                  |                  | coding before    |
|                  |                  |                  |                  | this gate. DB    |
|                  |                  |                  |                  | Migration (§6)   |
|                  |                  |                  |                  | only after this  |
|                  |                  |                  |                  | gate.            |
+------------------+------------------+------------------+------------------+------------------+

Kalpatharu Software Ltd · SPINRISE Migration · M01 PO · PR First Level
Approval (frmindentapp.frm) · FSD v1.1 · 21 May 2026 · Internal
Confidential
