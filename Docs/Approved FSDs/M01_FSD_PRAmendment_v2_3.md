+-----------------------------------------------------------------------+
| **SPINRISE ERP**                                                      |
|                                                                       |
| *Functional Specification Document · Blueprint v6.0 · 18 May 2026*    |
|                                                                       |
| **PR Amendment Entry --- tmpindAment.frm**                            |
|                                                                       |
| M01 Purchase Order · Stage 0: APPROVED 18 May 2026 (TL-Dev: Sasi)     |
|                                                                       |
| FSD v2.3 --- DDL Verified · Review Chain: Developer → TL-Dev Sasi     |
| (Stage 2) → TL-IST Palanivel (Stage 3) → CEO T. Mani (Stage 4)        |
|                                                                       |
| *Kalpatharu Software Ltd · Internal Confidential*                     |
+=======================================================================+

+-----------------------------------------------------------------------+
| **ACTION --- CEO Directive (T. Mani, 18 May 2026) · All Blueprint v6  |
| §4.3 mandatory sections complete**                                    |
|                                                                       |
| 1\. Review chain: FSD submitted through correct chain --- Developer → |
| TL-Dev Sasi (Stage 2) → TL-IST Palanivel (Stage 3) → CEO T. Mani      |
| (Stage 4).                                                            |
|                                                                       |
| 2\. All Blueprint v6 §4.3 mandatory sections complete: Stage 0 Gates, |
| Fields, Business Rules, Pre-GST, Print, Customer Variations, DB       |
| Migration, Critical Defects, Open Items --- all present and complete. |
|                                                                       |
| 3\. Stage 0 FULLY APPROVED by Sasi --- all 8 audit findings resolved, |
| all 35 error handlers added and confirmed by TL-Dev Sasi. Stage 0 is  |
| not conditionally cleared --- it is fully cleared. No developer may   |
| open tmpindAment.frm in VB6 IDE.                                      |
|                                                                       |
| 4\. FSD v2.3 submitted to TL-Dev Sasi for Stage 2 technical review.   |
| Target: Sasi review complete 19 May 2026.                             |
+=======================================================================+

+-----------------------------------------------------------------------+
| **✅ FSD IS READY FOR TL-DEV (SASI) REVIEW**                          |
|                                                                       |
| All 9 Blueprint v6 §4.3 mandatory sections present and complete. 8    |
| audit findings documented (AF-01 to AF-08) --- all 8 resolved and     |
| confirmed at Stage 0 by TL-Dev Sasi. 5 Critical Defects raised (CD-01 |
| to CD-05). OI-01 and OI-03 resolved; OI-02, OI-04 and OI-05 closed.   |
|                                                                       |
| Sasi review focus points: (1) OI-02: CLOSED --- adddelmod() confirmed |
| UI-only (toolbar buttons), zero DB writes, no nested transaction      |
| risk. (2) DbTmp dual connection in Add path (CD-04) --- confirm       |
| Dapper single-connection approach.                                    |
+=======================================================================+

**Compliance Audit Findings (8 issues identified and documented in this
FSD v2.3)**

*Audit performed against Blueprint v6.0 and VB6 source code
(tmpindAment.frm), Stage 0 gate checks 18 May 2026. All 8 findings
resolved. Stage 0 FULLY CLEARED and confirmed by TL-Dev Sasi --- no
conditional sign-off.*

  ---------------------------------------------------------------------------------------------------------
  **Finding**   **Issue**            **Detail**                  **Risk**   **Resolution / CD Raised**
  ------------- -------------------- --------------------------- ---------- -------------------------------
  **AF-01**     **G7 --- 35 subs: no Form_Load (48 body lines),  **HIGH**   RESOLVED ✔ Stage 0 confirmed by
                On Error GoTo        adoPrimaryRS_MoveComplete              TL-Dev Sasi: All 35 On Error
                handler**            (84 BL), bindcontls (53                GoTo handlers added to
                                     BL), grdDataGrid_KeyDown               Form_Load and all affected
                                     (26 BL), and 31 other subs             subs. CD-03 raised. SPINRISE:
                                     with meaningful logic have             all C# API endpoints in
                                     no On Error GoTo handler.              try-catch with Serilog. React
                                     Errors are silently                    toast on API error.
                                     swallowed on DB open,                  
                                     recordset operations, and              
                                     grid events.                           

  **AF-02**     **G6 --- delmodclick Original tmpindAment.frm    **HIGH**   Corrected in cleaned form:
                BeginTrans unmatched had db.BeginTrans at L5555             CommitTrans added after Call
                (original file)**    (delmodclick) with no                  adddelmod(BUTTON), On Error
                                     CommitTrans or                         GoTo delmodclick_Error added,
                                     RollbackTrans anywhere in              RollbackTrans in error label.
                                     the sub. Connection left in            Verified in current cleaned
                                     pending transaction state              file. No CD raised --- fix
                                     on every delmodclick call.             confirmed.

  **AF-03**     **G8 --- 7 bare On   Original file had 7         **MED**    RESOLVED ✔ Stage 0 confirmed by
                Error Resume Next    truncated \"On\" lines                 TL-Dev Sasi: All 7 bare "On"
                lines (original      (remnants of On Error                  fragments corrected --- 4
                file)**              Resume Next) in                        replaced with On Error GoTo
                                     BUTTON_Click, Form_Resize,             \[SubName\]\_Error + error
                                     grdDataGrid_DblClick,                  label; 3 removed (sub already
                                     bindcontls,                            had GoTo handler). Zero active
                                     grdDataGrid_KeyDown,                   OERN in cleaned file.
                                     grdDataGrid_RowColChange,              
                                     and calculation subs.                  

  **AF-04**     **G5 --- SELECT      Original newdocno() used    **HIGH**   RESOLVED ✔ Stage 0 confirmed by
                MAX(amendno) race    SELECT MAX(amendno) from               TL-Dev Sasi: newdocno() fully
                condition in         po_aprh with client-side +1            rewritten to call
                newdocno() (original increment. Two concurrent              usp_GetNextAmendNo SP via
                file)**              sessions could receive the             ADODB.Command with typed
                                     same amendment number.                 parameters. SP uses
                                                                            SERIALIZABLE isolation +
                                                                            UPDLOCK + HOLDLOCK. CD-01
                                                                            documents the SPINRISE SQL
                                                                            SEQUENCE approach.

  **AF-05**     **G4 --- 101 SQL     101 lines in the cleaned    **HIGH**   NOTED ✔ Stage 0 confirmed by
                concatenation lines  form build SQL strings via             TL-Dev Sasi: Tracked as G4
                (backlog)**          & concatenation. Examples:             backlog per Blueprint v6. Not
                                     \"WHERE divcode=\'\"&                  fixed in VB6 (out of Stage 0
                                     divcode &\"\'\" throughout             scope). SPINRISE: Dapper
                                     BUTTON_Click, Query_mode,              \@parameter binding throughout.
                                     bindcontls, delmodclick,               Zero string-built SQL. CD-01
                                     and lookup subs. SQL                   raised.
                                     injection risk.                        

  **AF-06**     **G3 --- 88 comment  Original file had 88        **MED**    All 88 comment lines removed in
                lines including      comment lines including a              cleaned form. Zero comment
                commented business   large CR/11/037                        lines remain. CR/11/037 block
                logic (original      commented-out validation               removed --- logic confirmed
                file)**              block (L2655--L2665),                  superseded by current code.
                                     developer annotations                  
                                     (\'Added BY Raja), and                 
                                     multiple commented-out SQL             
                                     variants.                              

  **AF-07**     **DbTmp second ADO   In BUTTON_Click Case 9 Add  **MED**    CD-04 raised. VB6 AS-IS
                connection in Add    path, a second                         retained --- fixing this would
                save path**          ADODB.Connection object                require significant code
                                     (DbTmp) is opened for                  restructure outside Stage 0
                                     INSERT po_Aprh and INSERT              scope. SPINRISE: single Dapper
                                     po_Aprl, separate from the             IDbConnection + IDbTransaction
                                     main db connection that                for all writes. No parallel
                                     holds BeginTrans. This                 connections.
                                     splits the transaction                 
                                     across two connections.                

  **AF-08**     **G6 ---             BUTTON_Click_Error label in **MED**    RESOLVED: db.RollbackTrans
                BUTTON_Click_Error   original file had no                   added to BUTTON_Click_Error and
                handler missing      db.RollbackTrans. If a                 er1 handlers. Zero OERN. G8
                RollbackTrans        runtime error occurred                 PASS.
                (original file)**    mid-transaction the error              
                                     was displayed but the                  
                                     transaction was left open,             
                                     locking rows.                          
  ---------------------------------------------------------------------------------------------------------

**1 Document Identity**

  ------------------------------------------------------------------------
  **Attribute**      **Value**
  ------------------ -----------------------------------------------------
  **Form Name**      tmpindAment.frm (PR Amendment Entry) · M01 Purchase
                     Order Module

  **VB6 Source Files tmpindAment.frm (primary) │ MDIPO_Enterprise-related
  Analysed**         globals (connectstring, divcode, yfdate, yldate,
                     pdate, head, usrid, uid, EmpCommon) │ Module-level:
                     adddelmod() in bas module

  **Purpose**        Amend a previously saved Purchase Requisition (PR).
                     Creates a new amendment record in PO_APRH / PO_APRL
                     while archiving the original PR header and lines.
                     Tracks all item quantity, rate, cost centre, and date
                     changes.

  **Original Line    6,840 lines (full-form: design code + business logic,
  Count**            per Blueprint v6 §5.2 line-count rule)

  **Cleaned Line     5,699 lines · Reduction: 996 lines (14.9%) ·
  Count**            Breakdown: 88 comment lines removed, 7 bare On Error
                     Resume Next fixed, all CustID blocks confirmed
                     absent, dead code removed

  **Stage 0          FULLY APPROVED --- 18 May 2026 · TL-Dev: Sasi · 9
  Sign-off**         Blueprint v6 gates checked · All 8 audit findings
                     resolved. All 35 error handlers added and confirmed
                     by Sasi. G7 and G8 fully cleared. No conditional
                     sign-off. No developer may open tmpindAment.frm in
                     VB6 IDE.

  **FSD Version**    v1.0: Initial draft --- field table and basic
                     business rules. v1.0 (DDL): DDL verified against live
                     CREATE TABLE. Full Blueprint v6 format applied: Audit
                     Findings (AF-01--AF-08), DB Migration section, all
                     mandatory sections restructured to match approved
                     format. v2.0: CEO feedback corrections applied
                     18-May-2026 --- G7+G8 fully cleared (35 handlers
                     added), Rate field numeric(9,4), Rate_Find() replaced
                     with 3-option rate selector, RATE_SOURCE +
                     RATE_JUSTIFICATION columns added, OI-04 CLOSED. v2.1:
                     Sasi Stage 2 corrections applied 19-May-2026 ---
                     Original line count corrected to 6,840, AF-08 updated
                     (plain db.RollbackTrans, zero OERN), OI-02 CLOSED
                     (adddelmod() UI-only, no DB writes, no nested
                     transaction risk). Stage 2 cleared by Sasi. v2.2: CEO
                     directive correction applied 22-May-2026 --- 3-option
                     rate selector removed from Amendment screen (Last PO
                     Rate and Average Rate do not exist on Amendment
                     screen). Rate field pre-populated from PO_APRL
                     (RATE_SOURCE = ORIGINAL). Manual user override sets
                     RATE_SOURCE = MANUAL and makes RATE_JUSTIFICATION
                     mandatory. BackDate rule updated. OI-05 added and
                     CLOSED --- no maximum amendment count enforced at any
                     live customer. Submitted to Sasi for Stage 2
                     re-confirmation. v2.3: Sasi Stage 2 re-confirmation
                     corrections applied 22-May-2026 --- Finding 1:
                     ig_param terminology corrected throughout Section 5
                     and audit rows. EmpCommon, PurTypeFlg, BackDate are
                     global variables set at application login from
                     po_para (M01 PO module parameter table) --- not
                     ig_param reads inside this form. Finding 2: BackDate
                     validation corrected --- VB6 MaskEdBox1_LostFocus
                     (L4408--L4415) restricts Amendment Date to equal
                     pdate for ALL customers equally. No BackDate
                     conditional exists in this form. Previous
                     Kumaragiri-specific BackDate=N/Y customer variation
                     entry removed. SPINRISE rule updated accordingly.

  **Review Chain     CEO Working Session → Stage 1 Developer (Mariyaiya.M)
  (Blueprint v6      → Stage 2 TL-Dev Sasi (1 day) → Stage 3 TL-IST
  §4.2)**            Palanivel (1 day) → Stage 4 CEO T. Mani (same day) ·
                     Target: 5 working days

  **Submit-to-Sasi   19 May 2026 morning (Blueprint v6 target)
  Target**           

  **Technology       React.js 18 + Ant Design Pro │ ASP.NET Core 8 Web API
  Stack**            (C#) │ Dapper │ MS SQL Server 2019/2022 │ QuestPDF │
                     EPPlus

  **Primary DB       PO_APRH, PO_APRL, PO_PRH, PO_PRL, PO_DOC_PARA,
  Tables**           IN_DEP, IN_ITEM, mm_MACmas, IN_BGRP, in_cc, in_cat,
                     IN_INDENTTYPE, pr_emp, LogDet_PO

  **Key Stored       usp_GetNextAmendNo(@divcode VARCHAR(10), \@v_stdate
  Procedure**        VARCHAR(20), \@v_endate VARCHAR(20), \@newdocno INT
                     OUTPUT) → SERIALIZABLE isolation + UPDLOCK + HOLDLOCK
                     on po_aprh. Returns next amendment number. Returns -1
                     if PO_DOC_PARA row missing.

  **QuestPDF Report  PrAmendmentReport (compact layout \<5 items) │
  Classes**          PrAmendmentFullReport (full layout ≥5 items)

  **Print            Crystal Reports RepPO.rpt (via Cry_PRAmendment /
  Replacement**      Cry_PRAmd_full) → QuestPDF PrAmendmentReport /
                     PrAmendmentFullReport. Parameters: \@DivCode,
                     \@AMDNO, \@AMDDT. Re-print requires REPRINT_FLG
                     permission. All prints logged to PO_PRINT_LOG.

  **Pre-GST Scan**   CLEAN --- zero AED / BED / Cess / Surcharge / VAT /
                     CST references in tmpindAment.frm. No Pre-GST fields
                     written in this form. SCOPECODE and Sub-Cost Centre
                     removed from SPINRISE UI (DB columns retained).

  **OCX / Legacy     CrystalReport1 (Crystal Reports OCX) → QuestPDF │
  Dependencies       MSDataShape / SHAPE recordsets in fnd1() / Query_mode
  (G5)**             → Standard Dapper JOINs │ DataCombo1 (MSDATLST.OCX) →
                     React select │ MaskEdBox (MSMASK32.OCX) → React
                     DatePicker │ DataGrid1 (MSDATGRD.OCX) → Ant Design
                     Table. All noted in CD-05.

  **Architecture     Doc numbers: SQL SEQUENCE via usp_GetNextAmendNo (no
  Standards**        MAX+1) │ All DB via Dapper │ No schema changes to
                     existing tables │ Audit: LogDet_PO (ADD+MOD+DEL,
                     before/after values) │ Concurrency: rowversion on
                     PO_APRH │ Zero CustID branches in SPINRISE │
                     Re-print: REPRINT_FLG + PO_PRINT_LOG

  **PULSE 360        FSD writing → \"Kalsofte SPINRISE FSD\" project ID │
  Logging**          Coding/API → \"Kalsofte SPINRISE Web ERP Dev\" │ IST
                     review → \"Kalsofte SPINRISE Web ERP IST\"
  ------------------------------------------------------------------------

**2 Stage 0 Gate Results (Blueprint v6.0 --- Nine Gates)**

*Blueprint v6 §5.1: Sasi is the only person who can issue Stage 0
sign-off. Stage 0 FULLY APPROVED by TL-Dev Sasi --- all 8 audit findings
resolved, all 35 error handlers confirmed added. No conditional
sign-off. VB6 file not to be re-opened.*

+-------------+------------------+------------------+------------------+-------------------------------------------+
| **Gate**    | **Blueprint v6   | **Count**        | **Result**       | **Evidence & SPINRISE Action**            |
|             | Check**          |                  |                  |                                           |
+=============+==================+==================+==================+===========================================+
| **G1**      | CustID blocks    | 0 active         | **PASS**         | Zero If CustID= / If UCase(CustID)        |
|             | removed          |                  |                  | branches in cleaned code. EmpCommon,      |
|             |                  |                  |                  | PurTypeFlg, BackDate are global variables |
|             |                  |                  |                  | set at application login from po_para --- |
|             |                  |                  |                  | not read from any parameter table inside  |
|             |                  |                  |                  | this form. (Sasi Finding 1, Stage 2       |
|             |                  |                  |                  | re-confirmation.)                         |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G2**      | Dead UI code     | 0                | **PASS**         | Design controls with no active code       |
|             | removed          |                  |                  | references removed. Form design cleaned.  |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G3**      | Commented-out    | 0                | **PASS**         | All 88 comment lines removed (AF-06).     |
|             | code removed     |                  |                  | Includes CR/11/037 commented validation   |
|             |                  |                  |                  | block and developer annotations. Zero     |
|             |                  |                  |                  | comment lines remain.                     |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G4**      | Debug code       | 0                | **PASS**         | Zero Stop / Debug.Print / debug MsgBox in |
|             | removed          |                  |                  | cleaned code.                             |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G5**      | Deprecated API   | 5 OCX + 1 SHAPE  | **PASS**         | CrystalReport1, MSDataShape SHAPE         |
|             | calls flagged    |                  |                  | queries, DataCombo1 (MSDATLST), MaskEdBox |
|             |                  |                  |                  | (MSMASK32), DataGrid1 (MSDATGRD). All     |
|             |                  |                  |                  | noted in CD-05. SPINRISE replaces all     |
|             |                  |                  |                  | with React/Dapper equivalents.            |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G6**      | Transaction      | PASS             | **PASS**         | 2 BeginTrans. BUTTON_Click: 4 CommitTrans |
|             | integrity clean  |                  |                  | paths + 3 RollbackTrans error paths.      |
|             |                  |                  |                  | delmodclick: CommitTrans + RollbackTrans  |
|             |                  |                  |                  | in delmodclick_Error. All paths bounded   |
|             |                  |                  |                  | (AF-02 + AF-08 corrected).                |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G7**      | Error handling   | PARTIAL          | **PASS**         | All 35 subs corrected: On Error GoTo      |
|             | present          |                  |                  | \[SubName\]\_Error added to Form_Load,    |
|             |                  |                  |                  | adoPrimaryRS_MoveComplete, bindcontls,    |
|             |                  |                  |                  | undoLookup, ScopeLookup, and 30 others.   |
|             |                  |                  |                  | G7 fully cleared. SPINRISE: all endpoints |
|             |                  |                  |                  | in try-catch + Serilog.                   |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G8**      | OERN removed --- | 0 active         | **PASS**         | AF-03 corrected: all 7 bare "On"          |
|             | zero tolerance   |                  |                  | fragments replaced or removed. Zero       |
|             |                  |                  |                  | active On Error Resume Next in cleaned    |
|             |                  |                  |                  | file. All 35 subs now have On Error GoTo  |
|             |                  |                  |                  | handlers. Stage 0 FULLY APPROVED.         |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **G9**      | Global variable  | PASS             | **PASS**         | EmpCommon (4 refs), PurTypeFlg (in        |
|             | path confirmed   |                  |                  | bindcontls + IndType), BackDate (in date  |
|             | (po_para source) |                  |                  | validation) --- all present and active in |
|             |                  |                  |                  | cleaned code as global variables set at   |
|             |                  |                  |                  | login from po_para. No orphaned flags. No |
|             |                  |                  |                  | ig_param or in_para reads inside this     |
|             |                  |                  |                  | form.                                     |
+-------------+------------------+------------------+------------------+-------------------------------------------+
| **OVERALL** | **9 PASS · 0 FAIL · NOTE: G5 OCX/SHAPE flagged for SPINRISE replacement (tracked in CD-05)**       |
+-------------+----------------------------------------------------------------------------------------------------+

**3 Field Table (Blueprint v6 format)**

*All fields and controls identified from tmpindAment.frm code. Header
fields + grid line fields in one table. Legacy REMOVED columns marked.
Pre-GST scan: CLEAN.*

  --------------------------------------------------------------------------------------------------------------------------------
  **Field /       **AS-IS VB6              **SPINRISE TO-BE**      **DB Column (table.column    **Validation Rule**  **Status**
  Rule**          (tmpindAment.frm)**                              SQL type)**                                       
  --------------- ------------------------ ----------------------- ---------------------------- -------------------- -------------
  **Division      txtfields(0) --- auto    Read-only. Auto-set     PO_APRH.divcode varchar(2)   Mandatory.           **AS-IS**
  Code**          from global divcode.     from logged-in user     NOT NULL                     Non-editable.        
                  Read-only.               session context.                                                          

  **PR No.**      txtfields(2) --- locked. Read-only. Populated    PO_APRH.prno numeric(6,0)    Mandatory. Must      **AS-IS**
                  Selected via DELMOD      when user selects a PR  NOT NULL                     exist in PO_PRH. No  
                  DataCombo lookup from    from the amendment                                   manual entry.        
                  po_aprh.                 lookup list.                                                              

  **PR Date**     MaskEdBox1(0) --- masked Read-only date          PO_APRH.prdate datetime NOT  Must be valid date   **AS-IS**
                  date input. Disabled     auto-populated on PR    NULL                         within financial     
                  once PR is selected.     selection.                                           year.                

  **Amendment     txtfields(3) ---         Auto-generated by SQL   PO_APRH.amendno numeric(5,0) Auto-generated.      **CHANGED**
  No.**           auto-generated by        Server SEQUENCE via     NULL                         Read-only. SPINRISE: 
                  newdocno() →             usp_GetNextAmendNo SP.                               SQL SEQUENCE ---     
                  usp_GetNextAmendNo SP    Read-only.                                           zero MAX+1.          
                  via ADODB.Command.                                                                                 

  **Amendment     MaskEdBox1(1) ---        React DatePicker.       PO_APRH.amenddate datetime   Mandatory. Must be   **AS-IS**
  Date**          DTPicker2. Defaults to   Defaults to             NULL                         within               
                  pdate (processing date). server-date.                                         yfdate--yldate. HTTP 
                  Financial year bounded.  yfdate--yldate range                                 422 on violation.    
                                           enforced client +                                                         
                                           server.                                                                   

  **Amendment     Txt_Amndreason --- free  Mandatory text area.    PO_APRH.amendreason          Mandatory. Error:    **AS-IS**
  Reason**        text. Mandatory before   React inline error if   varchar(1000) NULL           \"Please enter the   
                  save. Checked in Case 9  blank before Save                                    AmendmentReason\".   
                  before any DB write.     attempt.                                             Max 1000 chars.      

  **Requester     txtfields(1) ---         Employee lookup. If     PO_APRH.REQNAME varchar(25)  Optional. Must exist **AS-IS**
  Name**          employee code (Empno)    EmpCommon=True: global  NULL                         in pr_emp if         
                  from pr_emp. EmpCommon   pr_emp lookup; else                                  entered. Max 25      
                  flag controls lookup     divcode-filtered.                                    chars.               
                  scope.                                                                                             

  **Department    txtfields(5) ---         Dept code with          PO_APRH.depcode varchar(3)   Mandatory on save.   **AS-IS**
  Code**          depcode. Text2           auto-filled description NULL                         Must exist in IN_DEP 
                  auto-fills depname from  label. Lookup from                                   for divcode.         
                  IN_DEP on change.        IN_DEP.                                                                   

  **Department    Text2 --- read-only.     Read-only auto-fill     IN_DEP.depname (display      Read-only.           **AS-IS**
  Name**          Auto-filled from         display label.          only)                        Auto-populated.      
                  IN_DEP.depname on                                                                                  
                  txtfields(5) entry.                                                                                

  **Reference     txtfields(8) ---         Optional free-text      PO_APRH.refno varchar(6)     Optional. Max 6      **AS-IS**
  No.**           optional external        field.                  NULL                         chars.               
                  reference.                                                                                         

  **Section**     Text3 --- optional       Optional text.          PO_APRH.SECTION varchar(20)  Optional. Max 20     **AS-IS**
                  department section.                              NULL                         chars.               

  **Indent Type** Text5 --- PR type        Dropdown from           PO_APRH.ITYPE char(1) NULL   Conditional          **CHANGED**
                  (Capital/Maintenance).   PO_INDENTTYPE.                                       mandatory. Driven by 
                  Bound to IndType combo   Mandatory when                                       global variable      
                  from PO_INDENTTYPE.      PO_PARA.PurTypeFlg=1.                                PurTypeFlg (set at   
                                                                                                login from po_para). 

  **Place of      PLACEOFISS --- bound     Optional. Auto-filled   PO_APRH.PLACEOFISS           Optional. Max 30     **AS-IS**
  Issue**         from adoPrimaryRS.       from PR master on       varchar(30) NULL             chars.               
                  Header-level.            selection.                                                                

  **Budget        budgetBALAMT --- stored  Display-only.           PO_APRH.budgetBALAMT         Read-only.           **AS-IS**
  Balance**       at header level. Display System-calculated       numeric(18,2) NULL           System-maintained.   
                  only.                    budget balance for the                                                    
                                           PR.                                                                       

  **Approval      APP1/APP2/APP3 +         Read-only in amendment  APP1--APP3,                  System-managed by    **CHANGED**
  Fields**        APP1DATE--APP3DATE +     form. SPINRISE approval APP1DATE--APP3DATE,          approval             
                  APP1TIME--APP3TIME ---   workflow populates      APP1TIME--APP3TIME           transaction. Not     
                  set by approval          these.                  varchar(10)/datetime NULL    user-editable here.  
                  workflow.                                                                                          

  **Cancel        cancelflag / canceldt /  Read-only. Managed by   cancelflag char(1), canceldt Read-only in this    **AS-IS**
  Fields**        canreason --- set by     PR Cancellation         datetime, canreason          form.                
                  Indentcanl.frm.          transaction only.       varchar(50) --- all NULL     System-managed.      

  **Scope Code**  SCOPECODE --- not used   REMOVED from SPINRISE   PO_APRH.SCOPECODE varchar(2) REMOVED. DB column   **REMOVED**
                  by any spinning mill     UI. DB column retained  NULL                         retained.            
                  customer. Unpopulated in for legacy data.                                                          
                  all live DBs.                                                                                      

  **Item Code     ItemCodeTextBox ---      Autocomplete lookup     PO_APRL.itemcode varchar(10) Mandatory. Must      **AS-IS**
  (grid)**        validated on LostFocus   from IN_ITEM. React     NOT NULL                     exist in IN_ITEM.    
                  against IN_ITEM.         DataGrid column.                                                          

  **Item          ItemNameTextBox ---      Read-only auto-fill     IN_ITEM.ITEMNAME (display    Read-only.           **AS-IS**
  Description     auto-filled from         from item master.       only)                        Auto-populated.      
  (grid)**        IN_ITEM.ITEMNAME on item                                                                           
                  code entry.                                                                                        

  **UOM (grid)**  IN_ITEM.UOM --- display  Read-only from item     IN_ITEM.UOM (display only)   Read-only.           **AS-IS**
                  only from grid query.    master.                                                                   

  **Rate (grid)** RATE --- numeric.        Rate field              PO_APRL.RATE numeric(9,4)    Optional. Must be    **CHANGED**
                  Rate_Find() auto-fills   pre-populated with      NULL DEFAULT 0               \>= 0. 4 decimal     
                  from item master. User   original PR rate from                                places (CEO          
                  can override. \[VB6      PO_APRL on Amendment                                 standard:            
                  AS-IS\]                  screen load. User may                                numeric(9,4)).       
                                           override via direct                                                       
                                           manual entry.                                                             
                                           RATE_SOURCE defaults to                                                   
                                           'ORIGINAL'. If user                                                       
                                           overrides, RATE_SOURCE                                                    
                                           = 'MANUAL' and                                                            
                                           RATE_JUSTIFICATION is                                                     
                                           mandatory. (CEO                                                           
                                           directive 22-May-2026:                                                    
                                           3-option rate selector                                                    
                                           does not apply to                                                         
                                           Amendment screen. Last                                                    
                                           PO Rate and Average                                                       
                                           Rate options are not                                                      
                                           available on the                                                          
                                           Amendment screen.)                                                        

  **Rate Source   Not present in VB6.      Rate source for         PO_APRL.RATE_SOURCE          Values: ORIGINAL /   **NEW**
  (grid)**        Rate_Find() had no       Amendment screen:       varchar(20) NULL             MANUAL. Mandatory    
                  source tracking.         ORIGINAL (pre-populated                              --- defaults to      
                                           from PO_APRL on load)                                ORIGINAL on          
                                           or MANUAL (user                                      Amendment screen     
                                           override). Stored per                                load.                
                                           line. Read-only after                                                     
                                           save.                                                                     

  **Rate          Not present in VB6.      Mandatory when          PO_APRL.RATE_JUSTIFICATION   Mandatory when       **NEW**
  Justification                            RATE_SOURCE = MANUAL.   varchar(200) NULL            RATE_SOURCE =        
  (grid)**                                 Free text justification                              MANUAL. HTTP 422 if  
                                           for the manually                                     blank and            
                                           entered rate. Not                                    RATE_SOURCE =        
                                           required when                                        MANUAL. Max 200      
                                           RATE_SOURCE = ORIGINAL.                              chars.               

  **Current Stock a.curstk from IN_ITEM    Display only. Read from IN_ITEM.CURSTK (display      Read-only.           **AS-IS**
  (grid)**        --- display only.        IN_ITEM.CURSTK.         only)                        Informational.       

  **Qty Required  QtyReqTextBox ---        Mandatory numeric.      PO_APRL.qtyind numeric(12,3) Mandatory. Must be   **AS-IS**
  (grid)**        QTYIND. Mandatory.       Quantity being amended. NULL                         \> 0. Error:         
                  Validated on LostFocus.                                                       \"Required quantity  
                                                                                                cannot be empty\".   

  **Machine Code  MachineTextBox ---       Machine lookup.         PO_APRL.macno varchar(5)     Optional. Must exist **AS-IS**
  (grid)**        MACNO. Validated against Optional but validated  NULL                         in mm_MACmas if      
                  mm_MACmas if entered.    if entered.                                          entered.             

  **Category      CATCODE from in_cat.     Dropdown from in_cat.   PO_APRL.CATCODE varchar(1)   Optional.            **AS-IS**
  (grid)**                                 Optional.               NULL                                              

  **Cost Centre   CCCODE from in_cc.       Dropdown from in_cc.    PO_APRL.CCCODE numeric(4,0)  Optional.            **AS-IS**
  (grid)**                                 Optional.               NULL                                              

  **Budget Group  BGRPCODE from IN_BGRP.   Dropdown from IN_BGRP.  PO_APRL.BGRPCODE varchar(4)  Optional.            **AS-IS**
  (grid)**                                 Optional.               NULL                                              

  **Required Date REQDDATE --- date        Date picker. Must be    PO_APRL.reqddate datetime    Optional. If entered **AS-IS**
  (grid)**        picker. Defaults to      \>= amendment date.     NULL                         must be \>=          
                  pdate.                                                                        amenddate.           

  **Place of      PLACE --- free text per  Optional text per line  PO_APRL.PLACE varchar(40)    Optional.            **AS-IS**
  Issue (grid)**  line.                    item.                   NULL                                              

  **Approx. Cost  AppCostTextBox ---       Numeric. Approximate    PO_APRL.APPCOST              Optional. Must be    **AS-IS**
  (grid)**        APPCOST. Numeric.        cost per line item.     numeric(11,2) NULL           \>= 0. 2 decimal     
                                                                                                places.              

  **Remarks       REMARKS --- free text.   Optional remarks per    PO_APRL.remarks varchar(50)  Optional. Max 50     **AS-IS**
  (grid)**                                 line.                   NULL                         chars.               

  **Amendment     amdflg --- carries       System field. Carried   PO_APRL.amdflg char(1) NULL  System-managed. Not  **AS-IS**
  Flag (grid)**   forward from original    over from source PR                                  user-editable.       
                  PO_PRL row.              line.                                                                     

  **Qty Approved  QTYREQD --- set by       Read-only. Populated by PO_APRL.qtyreqd              Read-only in         **AS-IS**
  (grid)**        approval workflow.       approval transaction.   numeric(12,3) NULL           amendment form.      
                  Display only here.                                                                                 

  **PR Status     prstatus --- char(1).    Read-only. O=Ordered,   PO_APRL.prstatus char(1)     Read-only.           **AS-IS**
  (grid)**        Set by downstream        E=Enquired,             NULL                         System-managed.      
                  transactions.            R/C=Received,                                                             
                                           X=Cancelled,                                                              
                                           Z=Foreclosed.                                                             

  **Amendment No. amendno --- links line   System field. Written   PO_APRL.amendno numeric(5,0) System-managed.      **AS-IS**
  (grid)**        to po_aprh amendment     on save.                NULL                                              
                  record.                                                                                            

  **Amendment     amenddate --- stored     System field. Written   PO_APRL.amenddate datetime   System-managed.      **AS-IS**
  Date (grid)**   with each amended line.  on save.                NULL                                              

  **Amendment     amendslno --- line       System field. Written   PO_APRL.amendslno            System-managed.      **AS-IS**
  Slno (grid)**   position within the      on save.                numeric(5,0) NULL                                 
                  amendment.                                                                                         

  **Pre-GST       Not present in           REMOVED. Not applicable N/A                          No action required.  **REMOVED**
  Fields**        tmpindAment.frm --- scan to PR Amendment.                                                          
                  confirmed zero                                                                                     
                  AED/BED/Cess/VAT/CST                                                                               
                  references.                                                                                        

  **workdet /     In SELECT queries only.  Not in INSERT or API    PO_APRL.workdet,             Never inserted by    **REMOVED**
  reason (grid)** Never in INSERT. Legacy  response. Retained in   PO_APRL.reason (read-only    SPINRISE.            
                  columns.                 DB for legacy reads.    legacy)                                           
  --------------------------------------------------------------------------------------------------------------------------------

**4 Business Rules (Save Sequence · Transaction Boundaries · All
Rules)**

  -------------------------------------------------------------------------------------------------------------------------------------------------
  **Rule /        **AS-IS VB6 Logic**          **SPINRISE TO-BE**                            **Trigger**       **DB Impact**          **Status**
  Event**                                                                                                                             
  --------------- ---------------------------- --------------------------------------------- ----------------- ---------------------- -------------
  **Pre-save      Txt_Amndreason validated     React inline validation. Cannot call Save API Case 9 click      None                   **CHANGED**
  validation**    first. If empty: MsgBox +    if reason is blank.                                                                    
                  SetFocus + Exit Sub.                                                                                                

  **Amendment     PArs.Open SELECT COUNT(\*)   SPINRISE: Show amendment count as             Add mode entry    READ PO_APRH           **CHANGED**
  count check**   from Po_Aprh WHERE prno. If  informational display only --- no hard block,                                          
                  AmendCount \>= 1: MsgBox     no confirmation required. AmendNo MsgBox in                                            
                  \"Already Amended N times,   VB6 is informational only; SPINRISE retains                                            
                  Do You Wish To Continue?\".  this as a count badge. No ig_param flag                                                
                                               needed. (CEO directive 22-May-2026: OI-05                                              
                                               CLOSED --- no maximum amendment count                                                  
                                               enforced at any live customer.)                                                        

  **Min 1 line    adoSecondaryRS.RecordCount   Client-side validation. Toast/inline error.   Save              None                   **AS-IS**
  item**          \<= 0 → MsgBox \"Purchase    API also validates.                                                                    
                  Requisition Requires at                                                                                             
                  least one Item\".                                                                                                   

  **No blank      IsNull(adoSecondaryRS(9)) →  Mandatory grid-level validation. Highlight    Save --- per row  None                   **AS-IS**
  quantity**      MsgBox \"Required quantity   blank QTYIND cells. API rejects.                                                       
                  cannot be empty\" + grid                                                                                            
                  focus.                                                                                                              

  **PayCalc lock  yfdate / yldate global       API: amenddate must be within yfdate--yldate. Date change; API  None                   **AS-IS**
  (financial year bounds DTPicker1/2.          HTTP 422 on violation.                        save                                     
  guard)**        MaskEdBox1 validation on                                                                                            
                  LostFocus.                                                                                                          

  **Save sequence 1.Validate reason+lines+qty. 1.Validate. 2.usp_GetNextAmendNo (SEQUENCE).  Case 9 ---        INSERT PO_APRH +       **CHANGED**
  (Add)**         2.newdocno()→SP.             3.BEGIN TRANSACTION. 4.INSERT PO_APRH. 5.Bulk Opt=\"add\"       PO_APRL, DELETE        
                  3.DbTmp.Execute INSERT       INSERT PO_APRL. 6.DELETE PO_PRL WHERE                           PO_PRH + PO_PRL,       
                  po_Aprh. 4.Loop INSERT       prno+prdate. 7.DELETE PO_PRH WHERE                              INSERT LogDet_PO       
                  po_Aprl. 5.db.Execute DELETE prno+prdate. 8.INSERT LogDet_PO. 9.COMMIT.                                             
                  po_prl. 6.db.Execute DELETE                                                                                         
                  po_prh. 7.adoPrimaryRS                                                                                              
                  update. 8.db.CommitTrans.                                                                                           
                  9.LogDet_PO INSERT.                                                                                                 

  **Save sequence If amendno exists in         Dapper: diff grid vs DB. UPDATE existing,     Case 9 ---        UPDATE/INSERT/DELETE   **CHANGED**
  (Modify)**      po_aprl: UPDATE. Else        INSERT new, DELETE removed --- one            Opt=\"mod\"       PO_APRL, INSERT        
                  INSERT. DELETE removed       transaction. Log all MOD to LogDet_PO with                      LogDet_PO              
                  lines. db.CommitTrans.       before/after values.                                                                   

  **Delete (line  SS1 = \"DELETE FROM PO_APRL  Confirm dialog. DELETE PO_APRL row. INSERT    delmodok_Click;   DELETE PO_APRL, INSERT **AS-IS**
  level)**        WHERE ... AND amendno=...\"  LogDet_PO (DEL, before values).               Case 3            LogDet_PO              
                  via db.Execute.                                                                                                     

  **Transaction   BeginTrans L1971.            All writes inside Dapper                      All save paths    All DML tables         **CHANGED**
  integrity**     CommitTrans                  BeginTransaction/CommitAsync/RollbackAsync.                                            
                  L2454/2576/2636/2687.        No partial saves. Rollback on any exception.                                           
                  RollbackTrans                                                                                                       
                  L2650/2717--2723.                                                                                                   
                  delmodclick BeginTrans                                                                                              
                  L4871, CommitTrans L4874,                                                                                           
                  RollbackTrans L4877.                                                                                                
                  BUTTON_Click_Error: scoped                                                                                          
                  RollbackTrans added (AF-08).                                                                                        

  **Audit trail** db.Execute INSERT LogDet_PO  INSERT LogDet_PO inside same Dapper           After each DML    INSERT LogDet_PO       **CHANGED**
                  after each save. ADD         transaction as PO_APRH/PO_APRL DML. ADD +                                              
                  operations only in VB6.      MOD + DEL all logged. MOD logs before/after                                            
                                               values. Atomic.                                                                        

  **Re-print      CrystalReport1 RepPO.rpt     QuestPDF PrAmendmentReport (\<5 lines) /      Case 13 (print    INSERT PO_PRINT_LOG    **CHANGED**
  control**       with \@DivCode, \@AMDNO,     PrAmendmentFullReport (\>=5 lines). Re-print  button)                                  
                  \@AMDDT. Two layouts based   requires REPRINT_FLG. All prints logged to                                             
                  on line count.               PO_PRINT_LOG.                                                                          

  **Row-level     adOpenStatic +               SELECT PO_APRL WITH (UPDLOCK, ROWLOCK) before Mod save          PO_APRL (UPDLOCK)      **CHANGED**
  locking**       adLockBatchOptimistic. No    DELETE in modify transaction. rowversion on                                            
                  pessimistic lock on modify.  PO_APRH per Blueprint v6 §12.                                                          

  **Document      newdocno() →                 SQL Server SEQUENCE wrapped in                Add save          SELECT + INSERT        **CHANGED**
  number          usp_GetNextAmendNo SP        usp_GetNextAmendNo. Not in INSERT column list                   PO_APRH                
  generation**    (ADODB.Command, typed        --- auto-generated.                                                                    
                  params). SERIALIZABLE +                                                                                             
                  UPDLOCK + HOLDLOCK.                                                                                                 
  -------------------------------------------------------------------------------------------------------------------------------------------------

**5 Customer Variations (Global Variable Configuration --- Zero CustID
Blocks in SPINRISE)**

*All customer-specific logic via global variables set at application
login from po_para (M01 PO module parameter table). Zero CustID branches
in cleaned code or SPINRISE.*

  -----------------------------------------------------------------------------------------------------------------------------------------------------
  **Global Variable  **VB6 Variable**       **Behaviour When Active**          **Replaced AS-IS VB6   **SPINRISE Config / TO-BE**        **G9 Status**
  (po_para source)**                                                           Condition**                                               
  ------------------ ---------------------- ---------------------------------- ---------------------- ---------------------------------- --------------
  **EmpCommon**      EmpCommon (Boolean     If True: pr_emp lookup is global   Replaced: EmpCommon    Global variable set at application **✅ G9**
                     global)                (all divisions). If False:         boolean branches (4    login from po_para (M01 PO module  
                                            filtered by divcode.               occurrences) in        parameter table). SPINRISE reads   
                                                                               bindcontls +           EmpCommon global at form load. No  
                                                                               indentreplist          ig_param read inside this form.    

  **PurTypeFlg**     PO_PARA.PurTypeFlg (in If 1: ITYPE (Indent Type) field is Replaced:              Global variable set at application **✅ G9**
                     bindcontls + IndType)  mandatory. If 0: optional.         PO_PARA.PurTypeFlg     login from po_para (M01 PO module  
                                                                               conditional in         parameter table). SPINRISE reads   
                                                                               IndType + bindcontls   PurTypeFlg global at form load.    
                                                                                                      Conditional mandatory on ITYPE     
                                                                                                      field in React. No ig_param read   
                                                                                                      inside this form.                  

  **BackDate**       in_para.backdate ---   Global variable set at application VB6                    SPINRISE server-side validation:   **✅ G9**
                     referenced in date     login from po_para (M01 PO module  MaskEdBox1_LostFocus   Amendment Date must equal current  
                     validation. However    parameter table). VB6 code         (L4408--L4415):        processing date (pdate) for all    
                     code scan of           (MaskEdBox1_LostFocus              Amendment Date must    customers. No BackDate flag        
                     MaskEdBox1_LostFocus   L4408--L4415) restricts Amendment  equal pdate ---        conditional. HTTP 422 if Amendment 
                     (L4408--L4415)         Date to equal pdate for ALL        applies to ALL         Date does not equal pdate.         
                     confirms: Amendment    customers --- no BackDate          customers equally. No                                     
                     Date must equal pdate  conditional exists in this form.   BackDate conditional                                      
                     for ALL customers. No  SPINRISE Amendment Date validation in this form. Previous                                    
                     BackDate conditional   rule: Amendment Date must equal    FSD entry documenting                                     
                     exists inside this     processing date (pdate) for all    customer-specific                                         
                     form. Both conditions  customers. No customer-specific    restriction was                                           
                     (greater than pdate    variation applies in M01. Previous INCORRECT for M01.                                        
                     and less than pdate)   FSD entry documenting BackDate=N / (Sasi Finding 2, Stage                                    
                     fire for all customers BackDate=Y customer split was      2 re-confirmation.)                                       
                     equally.               INCORRECT for M01 and is hereby                                                              
                                            corrected. (Sasi Finding 2, Stage                                                            
                                            2 re-confirmation.)                                                                          

  **Multi-Vertical   Not in this form.      CLOSED --- CEO approved            N/A --- not            CLOSED. Implement using            **RESOLVED**
  (Budget            CLOSED --- CEO         Architecture Proposal 18-May-2026. implemented yet        PO_PARA.purchase_budget_ctrl_flg = 
  Category)**        approved 18-May-2026.  Pattern:                                                  Y pattern. Blueprint v1.2 Section  
                                            PO_PARA.purchase_budget_ctrl_flg =                        5.4.1 to be updated by Abinandan.  
                                            Y.                                                                                           
  -----------------------------------------------------------------------------------------------------------------------------------------------------

**6 DB Migration (Execute Once Per Database --- After CEO
Countersignature)**

  -----------------------------------------------------------------------
  **⚠ EXECUTION CONTROL: Execute only after CEO countersignature. Not to
  be run in any live customer database before CEO approval is received.**
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------

  -------------------------------------------------------------------------------------------
  **Object**               **Type**       **Action**           **Purpose / Notes**
  ------------------------ -------------- -------------------- ------------------------------
  **usp_GetNextAmendNo**   Stored         CREATE --- deploy    Generates next amendment
                           Procedure      before SPINRISE      number atomically.
                                          go-live              SERIALIZABLE isolation +
                                                               UPDLOCK + HOLDLOCK on po_aprh.
                                                               Returns -1 if PO_DOC_PARA row
                                                               missing. Parameters: \@divcode
                                                               VARCHAR(10), \@v_stdate
                                                               VARCHAR(20), \@v_endate
                                                               VARCHAR(20), \@newdocno INT
                                                               OUTPUT.

  **PO_PRINT_LOG**         Table          CREATE if not exists Logs every print event for
                                          --- deploy before    re-print control. Columns:
                                          go-live              divcode, amendno, amenddate,
                                                               printed_by, printed_on,
                                                               reprint_flag. Required by
                                                               BR-11 re-print control.

  **LogDet_PO (MOD/DEL     Table ALTER    Add before_values,   SPINRISE logs before/after
  support)**                              after_values columns values for MOD operations.
                                          (nvarchar) if not    Confirm with DBA whether
                                          present              existing LogDet_PO schema
                                                               supports this or needs ALTER.

  **rowversion on          Column ADD     ALTER TABLE PO_APRH  Required for concurrency
  PO_APRH**                               ADD rowversion       control per Blueprint v6 §12.
                                          ROWVERSION ---       Prevents lost updates on
                                          deploy before        concurrent amendment saves.
                                          go-live              

  **PO_APRL.RATE_SOURCE    Column ADD     ALTER TABLE PO_APRL  Required by CEO rate directive
  and RATE_JUSTIFICATION** (x2)           ADD RATE_SOURCE      (22-May-2026). RATE_SOURCE
                                          varchar(20) NULL;    stores ORIGINAL (pre-populated
                                          ALTER TABLE PO_APRL  from PO_APRL on Amendment
                                          ADD                  screen load) or MANUAL (user
                                          RATE_JUSTIFICATION   override). RATE_JUSTIFICATION
                                          varchar(200) NULL;   mandatory when RATE_SOURCE =
                                                               MANUAL.
  -------------------------------------------------------------------------------------------

**7 Critical Defects (CD-01 to CD-05 --- Must Not Be Carried Into
SPINRISE)**

*All CDs have confirmed SPINRISE fixes. VB6 defects marked HIGH must not
appear in any SPINRISE code.*

  -------------------------------------------------------------------------------------------------------
  **CD No**   **Defect**      **Detail**                  **Risk**   **SPINRISE Fix**
  ----------- --------------- --------------------------- ---------- ------------------------------------
  **CD-01**   **SQL string    101 lines in cleaned form   **HIGH**   Dapper \@parameter binding
              concatenation   build SQL via & operator:              throughout all C# endpoints. Zero
              (101 lines)**   \"WHERE divcode=\'\"&                  string-built SQL in SPINRISE.
                              divcode &\"\'\" throughout             SafeStr() helper removed entirely.
                              BUTTON_Click, Query_mode,              
                              bindcontls, delmodclick,               
                              lookup subs.                           

  **CD-02**   **Crystal       RepPO.rpt loaded via        **HIGH**   QuestPDF PrAmendmentReport (compact,
              Reports         KALFOLDERDATA path. Two                \<5 lines) and PrAmendmentFullReport
              dependency**    templates: Cry_PRAmendment             (full, \>=5 lines). Confirmed class
                              (\<5 items) and                        names. Re-print via REPRINT_FLG +
                              Cry_PRAmd_full (\>=5                   PO_PRINT_LOG.
                              items). Parameters:                    
                              \@DivCode, \@AMDNO,                    
                              \@AMDDT.                               

  **CD-03**   **G7/G8 ---     Form_Load (48 BL),          **HIGH**   SPINRISE: all C# API endpoints in
              Form_Load + 35  adoPrimaryRS_MoveComplete              try-catch with Serilog structured
              subs without    (84 BL), bindcontls (53                logging. React toast on API error.
              error handler** BL), grdDataGrid_KeyDown               VB6: all 35 handlers added --- Stage
                              (26 BL), undoLookup (89                0 fully cleared.
                              BL), ScopeLookup (92 BL),              
                              and 29 others. All have                
                              meaningful DB or grid                  
                              operations but no On Error             
                              GoTo. Silent failure on any            
                              error.                                 

  **CD-04**   **DbTmp dual    Case 9 Add path opens a     **MED**    SPINRISE: single Dapper
              ADO connection  second ADODB.Connection                IDbConnection + IDbTransaction for
              in Add save     (DbTmp) for INSERT po_Aprh             all writes in one atomic operation.
              path**          and INSERT po_Aprl,                    No parallel connections.
                              separate from the main db              
                              connection that holds                  
                              db.BeginTrans. Splits the              
                              transaction across two                 
                              connections.                           

  **CD-05**   **OCX / legacy  CrystalReport1 (Crystal     **HIGH**   React DatePicker, Ant Design Table,
              technology      Reports), MSDataShape SHAPE            React select, standard Dapper JOINs
              dependencies    recordsets in                          replacing SHAPE syntax. Zero OCX in
              (G5)**          fnd1()/Query_mode,                     SPINRISE.
                              DataCombo1 (MSDATLST.OCX),             
                              MaskEdBox (MSMASK32.OCX),              
                              DataGrid1 (MSDATGRD.OCX).              
                              All require Windows COM                
                              registration.                          
  -------------------------------------------------------------------------------------------------------

**8 Open Items (OI-01 to OI-05)**

*OI-01 and OI-03 resolved. OI-02 closed --- adddelmod() is UI-only
(toolbar buttons), zero DB writes, no nested transaction risk. OI-04
closed. OI-05 closed --- no maximum amendment count enforced at any live
customer (CEO directive 22-May-2026).*

  -------------------------------------------------------------------------------------------------------------------------------
  **OI No**   **Item**           **Resolution**                     **Status**     **Owner**   **DB / Schema Impact**
  ----------- ------------------ ---------------------------------- -------------- ----------- ----------------------------------
  **OI-01**   **newdocno() SP    RESOLVED: usp_GetNextAmendNo       **RESOLVED**   Sasi        usp_GetNextAmendNo --- no schema
              deployment**       written and available. Deploy                                 change needed. SP deployed once
                                 after CEO countersignature per                                per DB.
                                 Section 6 execution control.                                  

  **OI-02**   **delmodclick      CLOSED: adddelmod() is UI-only     **CLOSED**     Sasi        No schema impact. adddelmod()
              transaction        (toolbar buttons). Zero DB writes.                            confirmed UI-only --- no DB
              pattern**          No nested transaction risk.                                   writes, no nested transaction
                                 Confirmed by Sasi --- Stage 2                                 risk.
                                 cleared.                                                      

  **OI-03**   **G8 error         RESOLVED: All 35 error handlers    **RESOLVED**   Sasi        All handlers added. Stage 0 fully
              handlers --- 35    added (On Error GoTo                                          cleared. No further action
              subs**             \[SubName\]\_Error). Stage 0 fully                            required.
                                 cleared by Sasi 18 May 2026.                                  

  **OI-04**   **Multi-vertical   CLOSED --- CEO approved            **CLOSED**     CEO T. Mani CLOSED. CEO approved 18-May-2026.
              architecture       Architecture Proposal 18-May-2026.                            Pattern:
              (Budget            Pattern:                                                      PO_PARA.purchase_budget_ctrl_flg =
              Category)**        PO_PARA.purchase_budget_ctrl_flg =                            Y. Blueprint v1.2 §5.4.1 ---
                                 Y. Blueprint v1.2 Section 5.4.1 to                            Abinandan.
                                 be updated by Abinandan.                                      

  **OI-05**   **Amendment count  CLOSED --- CEO directive           **CLOSED**     CEO T. Mani CLOSED. No schema impact. No
              --- no maximum     22-May-2026. No maximum amendment                             ig_param flag. No hard block in
              limit**            count enforced at any live                                    SPINRISE. Count badge only.
                                 customer. AmendNo MsgBox in VB6 is                            
                                 informational only. SPINRISE                                  
                                 retains it as an informational                                
                                 count badge. No hard block. No                                
                                 ig_param flag needed.                                         
  -------------------------------------------------------------------------------------------------------------------------------

**9 Review Chain & Sign-off**

*Blueprint v6 §4.2: CEO Working Session → Developer → TL-Dev Sasi (Stage
2) → TL-IST Palanivel (Stage 3) → CEO T. Mani (Stage 4). Target: 5
working days.*

  ------------------------------------------------------------------------------------
  **Role**      **Name**      **Date**    **Status**        **Notes**
  ------------- ------------- ----------- ----------------- --------------------------
  **Developer   Mariyaiya.M   18 May 2026 **✅ FSD v2.3     All Blueprint v6 §4.3
  --- Stage 1**                           Complete**        sections complete. 8 audit
                                                            findings documented. DDL
                                                            verified against live
                                                            CREATE TABLE. Submitted to
                                                            Sasi.

  **TL-Dev ---  Sasi          23 May 2026 **✅ Stage 2      Stage 0 FULLY APPROVED 18
  Stage 2**                               CLEARED**         May 2026. Stage 2 TL-Dev
                                                            review CLEARED by Sasi 23
                                                            May 2026 --- 13/13 checks
                                                            PASS, zero issues. FSD
                                                            v2.3 forwarded to TL-IST
                                                            Palanivel and CEO
                                                            simultaneously per
                                                            Blueprint v6 review chain.

  **TL-IST ---  Palanivel     Target: 20  **⏳ Stage 3      Review after Sasi Stage 2.
  Stage 3**                   May 2026    Active**          Focus: customer variations
                                                            (§5 --- EmpCommon,
                                                            PurTypeFlg, BackDate), IST
                                                            findings, amendment count
                                                            MsgBox business rule,
                                                            LogDet_PO before/after
                                                            values. IST one-page note
                                                            submitted in parallel.

  **CEO ---     T. Mani       23 May 2026 **✅              CEO countersignature given
  Stage 4**                               Countersigned**   23 May 2026. FSD v2.3 is
                                                            now locked development
                                                            baseline per Blueprint v6
                                                            §4.2. DB Migration (§6)
                                                            approved for execution.
                                                            Stage 3 TL-IST Palanivel
                                                            review in progress ---
                                                            target findings by 25 May
                                                            2026.
  ------------------------------------------------------------------------------------

*Kalpatharu Software Ltd · SPINRISE Migration · M01 PO · PR Amendment
Entry · FSD v2.3 · 18 May 2026 · Internal Confidential*
