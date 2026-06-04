+:----------------------:+:------------------------------:+
| **SPINRISE ERP**                                        |
|                                                         |
| Functional Specification Document                       |
|                                                         |
| PR Amendment Entry \| tmpindAment.frm \| M01 Purchase   |
| Order Module \| FSD v2.3                                |
+------------------------+--------------------------------+
| **Document**           | SPINRISE FSD --- PR Amendment  |
|                        | Entry                          |
+------------------------+--------------------------------+
| **Form**               | tmpindAment.frm (PR Amendment  |
|                        | Entry) \| M01 Purchase Order   |
+------------------------+--------------------------------+
| **Blueprint Version**  | Blueprint v6.0                 |
+------------------------+--------------------------------+
| **FSD Version**        | v2.3 (DDL Verified --- Final   |
|                        | Locked Baseline)               |
+------------------------+--------------------------------+
| **Stage 0 Sign-off**   | FULLY APPROVED --- 18 May 2026 |
|                        | \| TL-Dev: Sasi \| No          |
|                        | conditional sign-off           |
+------------------------+--------------------------------+
| **Current Stage**      | STAGE 4 --- CEO Review &       |
|                        | Countersignature \| T. Mani \| |
|                        | 23 May 2026                    |
+------------------------+--------------------------------+
| **Technology Stack**   | React.js 18 + Ant Design Pro   |
|                        | \| ASP.NET Core 8 Web API (C#) |
|                        | \| Dapper \| MS SQL Server     |
|                        | 2019/2022 \| QuestPDF \|       |
|                        | EPPlus                         |
+------------------------+--------------------------------+
| **Review Chain**       | Developer → TL-Dev Sasi (Stage |
|                        | 2) → TL-IST Palanivel (Stage   |
|                        | 3) → CEO T. Mani (Stage 4)     |
+------------------------+--------------------------------+
| **Organisation**       | Kalpatharu Software Ltd \|     |
|                        | SPINRISE Migration \| Internal |
|                        | Confidential                   |
+------------------------+--------------------------------+
| **Expert Review Date** | 23 May 2026 \| TL-IST          |
|                        | Palanivel \| Spinning Vertical |
|                        | ERP Expertise                  |
+------------------------+--------------------------------+

+---------------------------------------------+
| **✅ VERDICT: FSD v2.3 is technically       |
| sound, fully gate-cleared, and ready for    |
| CEO Stage 4 countersignature.**             |
|                                             |
| All 9 Blueprint v6 gates PASS. All 8 audit  |
| findings resolved. Stage 2 TL-Dev cleared   |
| 13/13 checks with zero issues. Stage 3      |
| TL-IST review active. DB Migration gated on |
| CEO countersignature.                       |
+---------------------------------------------+

+:---------:+:----------:+:--------:+:--------:+:---------:+:------:+
| **9 / 9   | **8        | **5      | **35     | **14.9%** | **0    |
| PASS**    | Resolved** | Raised** | Added**  |           | Open** |
|           |            |          |          | Code      |        |
| Blueprint | Audit      | Critical | Error    | Reduction | Open   |
| Gates     | Findings   | Defects  | Handlers |           | Items  |
+-----------+------------+----------+----------+-----------+--------+

# Expert Commentary --- TL-IST Spinning Vertical ERP Perspective

+---------------------------------------------+
| **🏆 Overall Assessment**                   |
|                                             |
| FSD v2.3 represents one of the most         |
| thorough PR Amendment module specifications |
| reviewed in Spinning Vertical ERP migration |
| work. The documentation rigorously maps     |
| every VB6 construct to its SPINRISE         |
| equivalent. The v2.3 corrections ---        |
| ig_param → po_para global variable          |
| clarification (Sasi Finding 1) and the      |
| BackDate validation correction (Sasi        |
| Finding 2) --- significantly improve the    |
| accuracy of the specification and directly  |
| prevent downstream miscoding in the         |
| SPINRISE implementation.                    |
+---------------------------------------------+

+---------------------------------------------+
| **⚙️ Transaction Integrity (AF-02, AF-08)   |
| --- Critical for Spinning Mill Operations** |
|                                             |
| In spinning mill environments, amendment    |
| transactions directly affect procurement    |
| commitments for raw material, accessories,  |
| and spare parts. The unmatched BeginTrans   |
| in delmodclick (AF-02) and the missing      |
| RollbackTrans in BUTTON_Click_Error (AF-08) |
| would have left connections in pending      |
| states during production downtime or        |
| network events --- a serious operational    |
| risk in mills running 24/7 production       |
| shifts. Both are fully resolved and         |
| verified in the cleaned form.               |
+---------------------------------------------+

+---------------------------------------------+
| **⚡ Race Condition in Amendment Number     |
| Generation (AF-04) --- HIGH Priority for    |
| Multi-User Spinning Mills**                 |
|                                             |
| SELECT MAX(amendno) + 1 in a multi-user     |
| spinning mill environment with concurrent   |
| amendment entry from procurement, planning, |
| and store teams is a well-known production  |
| defect pattern. Duplicate amendment numbers |
| cause downstream reconciliation failures in |
| GRN and invoice matching. The resolution    |
| using usp_GetNextAmendNo with SERIALIZABLE  |
| isolation, UPDLOCK and HOLDLOCK is          |
| architecturally correct and future-proof.   |
| The SPINRISE SQL SEQUENCE approach (CD-01)  |
| eliminates this risk permanently.           |
+---------------------------------------------+

+---------------------------------------------+
| **💰 Rate Field Design --- Amendment Screen |
| Specific Rule (v2.3 CEO Correction ---      |
| Commended)**                                |
|                                             |
| The v2.3 correction is architecturally      |
| precise: on the Amendment screen, only the  |
| original PO rate is available               |
| (RATE_SOURCE=ORIGINAL auto-populated from   |
| PO_APRL). This is correct for spinning mill |
| procurement --- amendment is a              |
| variance-capture transaction, not a         |
| rate-selection transaction. The mandatory   |
| RATE_JUSTIFICATION when a user manually     |
| overrides the rate provides the audit       |
| evidence needed for cost variance reviews   |
| and management reporting. The RATE_SOURCE   |
| and RATE_JUSTIFICATION columns are          |
| best-practice design for spinning vertical  |
| ERP audit compliance.                       |
+---------------------------------------------+

+---------------------------------------------+
| **🔧 ig_param Correction (v2.3) ---         |
| Prevents Downstream Configuration Errors**  |
|                                             |
| The v2.3 correction that EmpCommon,         |
| PurTypeFlg and BackDate are global          |
| variables set at application login from     |
| po_para --- NOT ig_param reads inside this  |
| form --- is critical for spinning mill      |
| multi-customer deployments. Misidentifying  |
| these as ig_param reads would have caused   |
| SPINRISE developers to implement runtime    |
| database configuration lookups inside the   |
| form, adding unnecessary database calls and |
| potential mis-configuration risk. The       |
| correction in v2.3 prevents this error from |
| entering the codebase.                      |
+---------------------------------------------+

+---------------------------------------------+
| **📅 BackDate Validation Correction (v2.3)  |
| --- All Customers Equal**                   |
|                                             |
| The v2.3 correction removing the            |
| Kumaragiri-specific BackDate=N/Y customer   |
| variation is important: the VB6 code scan   |
| confirms MaskEdBox1_LostFocus               |
| (L4408--L4415) restricts Amendment Date to  |
| equal pdate for ALL customers equally, with |
| no conditional branch. Including a          |
| non-existent customer-specific variation in |
| the FSD would have introduced a phantom     |
| feature requirement into SPINRISE           |
| development --- potentially causing a       |
| BackDate parameter flag to be implemented   |
| where none is needed. The correction        |
| reduces codebase complexity and eliminates  |
| a potential source of customer-specific     |
| code branches in SPINRISE, which is         |
| explicitly prohibited under Blueprint v6.   |
+---------------------------------------------+

+---------------------------------------------+
| **📋 VB6 Backlog Items --- Expert Position  |
| on CD-01, CD-04**                           |
|                                             |
| The 101 SQL concatenation lines (CD-01) and |
| DbTmp dual connection (CD-04) are correctly |
| classified as VB6 backlog. Attempting to    |
| fix these in Stage 0 would have introduced  |
| regression risk in a 6,840-line form that   |
| services live customer data across multiple |
| spinning mills. The AS-IS retention is the  |
| right call. SPINRISE\'s Dapper              |
| parameterisation and single-connection      |
| transaction model completely eliminate both |
| defects in the new implementation --- which |
| is the correct migration strategy.          |
+---------------------------------------------+

+---------------------------------------------+
| **✅ Pre-GST Scan --- Verified Clean for    |
| Post-GSTN Spinning Mills**                  |
|                                             |
| The confirmed absence of                    |
| AED/BED/Cess/VAT/CST references is          |
| important for spinning mills that have been |
| on GSTN since July 2017. Carrying Pre-GST   |
| field logic into SPINRISE would create      |
| incorrect tax reporting risk. The SCOPECODE |
| field removal from the SPINRISE UI (with DB |
| column retention for legacy reads) is the   |
| correct migration pattern --- it protects   |
| historical data integrity while presenting  |
| a clean modern interface to end users.      |
+---------------------------------------------+

# FSD v2.1 → v2.3 Changes --- What Is New in This Submission

  ------------ --------------------- ------------------------- ------------
  **Change     **v2.1/v2.2 (Prior    **v2.3 Correction         **Status**
  Area**       FSD)**                Applied**                 

  **Finding 1  Section 5 referenced  Corrected: These are      ✅
  (Sasi Stage  ig_param reads inside global variables set at   
  2)**         form. BackDate,       application login from    
               EmpCommon, PurTypeFlg po_para (M01 PO module    
               described as ig_param parameter table). No      
               reads.                ig_param reads inside     
                                     this form. All Customer   
                                     Variation rows (§5)       
                                     updated.                  

  **Finding 2  BackDate field had    CORRECTED:                ✅
  (Sasi Stage  Kumaragiri-specific   MaskEdBox1_LostFocus      
  2)**         customer variation    (L4408--L4415) confirmed  
               entry in §5           --- Amendment Date must   
               (BackDate=N /         equal pdate for ALL       
               BackDate=Y            customers equally. No     
               conditional split).   BackDate conditional in   
                                     this form. Incorrect      
                                     customer variation entry  
                                     removed.                  

  **Rate Field 3-option rate         CORRECTED by CEO          ✅
  (CEO v2.2)** selector (Last PO     directive 22-May-2026:    
               Rate / Average Rate / Last PO Rate and Average  
               Manual) applied to    Rate do not exist on      
               Amendment screen.     Amendment screen. Rate    
                                     pre-populated from        
                                     PO_APRL                   
                                     (RATE_SOURCE=ORIGINAL).   
                                     Manual override sets      
                                     RATE_SOURCE=MANUAL,       
                                     RATE_JUSTIFICATION        
                                     mandatory.                

  **OI-05 (CEO No open item for      ADDED and CLOSED: No      ✅
  v2.2)**      amendment count       maximum amendment count   
               limit.                enforced at any live      
                                     customer. VB6 AmendNo     
                                     MsgBox is informational   
                                     only. SPINRISE retains as 
                                     count badge. No ig_param  
                                     flag needed.              

  **Stage 2    Stage 2 cleared at    Stage 2 RE-CONFIRMED      ✅
  Re-confirm   v2.1 for original     22-May-2026 after v2.2    
  (Sasi        corrections.          CEO corrections --- 13/13 
  v2.3)**                            checks PASS, zero issues. 
                                     FSD v2.3 forwarded to     
                                     TL-IST + CEO              
                                     simultaneously.           
  ------------ --------------------- ------------------------- ------------

# Expert Observations --- Points Requiring CEO Attention at Stage 4

  ---------- -------------------- ----------------------------------
  **Type**   **Subject**          **Expert Observation / CEO
                                  Attention Required**

  **⚠️       **CD-04: DbTmp dual  The Add save path opens a second
  CONCERN    connection retained  ADO connection (DbTmp) for INSERT
  1**        AS-IS in VB6**       to po_Aprh and po_Aprl, separate
                                  from the main transaction
                                  connection. VB6 defect
                                  intentionally left unfixed
                                  (outside Stage 0 scope). CEO
                                  should acknowledge this known
                                  architectural risk in the VB6
                                  legacy codebase and confirm
                                  acceptance on record. SPINRISE fix
                                  is confirmed: single Dapper
                                  IDbConnection + IDbTransaction for
                                  all writes.

  **⚠️       **CD-01: 101 SQL     101 lines build SQL via string
  CONCERN    concatenation lines  concatenation in the VB6 form.
  2**        --- VB6 backlog      Logged as G4 backlog per Blueprint
             acceptance on        v6 --- not in Stage 0 scope.
             record**             SPINRISE uses Dapper \@parameter
                                  binding with zero string-built
                                  SQL. CEO should confirm the VB6
                                  backlog acceptance position is on
                                  record against the Stage 4
                                  sign-off, consistent with the
                                  migration go/no-go policy.

  **📌 NOTE  **DB Migration       Section 6 explicitly states:
  3**        execution gated on   Execute only after CEO
             CEO                  countersignature --- not to be run
             countersignature**   in any live customer database
                                  before CEO approval is received.
                                  Five DB objects are pending
                                  deployment. CEO countersignature
                                  of 23 May 2026 directly unblocks
                                  all migration scripts.

  **📌 NOTE  **Blueprint v1.2     OI-04 is closed with CEO approval
  4**        §5.4.1 update        18-May-2026. Pattern confirmed as
             (Abinandan) ---      PO_PARA.purchase_budget_ctrl_flg =
             confirm completion** Y. The Blueprint v1.2 §5.4.1
                                  update assigned to Abinandan has
                                  not been confirmed completed.
                                  Downstream module FSDs will
                                  inherit this pattern. CEO should
                                  verify before sign-off.

  **📌 NOTE  **v2.3 Correction:   Previous FSD versions documented a
  5**        BackDate validation  Kumaragiri-specific BackDate=N/Y
             --- ALL customers    customer variation. Sasi Stage 2
             equal**              re-confirmation (v2.3) corrects
                                  this: MaskEdBox1_LostFocus
                                  (L4408--L4415) restricts Amendment
                                  Date to equal pdate for ALL
                                  customers equally. No BackDate
                                  conditional exists inside this
                                  form. SPINRISE validation rule is:
                                  Amendment Date must equal pdate
                                  for all customers. No ig_param
                                  flag needed.

  **📌 NOTE  **Rate Field ---     CEO v2.2 directive: 3-option rate
  6**        v2.3 Amendment       selector (Last PO Rate / Average
             Screen Specific      Rate / Manual) does NOT apply to
             Rule**               Amendment screen --- these options
                                  do not exist on Amendment screen.
                                  v2.3 correctly reflects: Rate
                                  pre-populated from PO_APRL at load
                                  (RATE_SOURCE=ORIGINAL). User
                                  manual override →
                                  RATE_SOURCE=MANUAL +
                                  RATE_JUSTIFICATION mandatory. This
                                  rule is specific to the Amendment
                                  screen and differs from the PO
                                  Entry screen.
  ---------- -------------------- ----------------------------------

# CEO Stage 4 --- Actions Required

  -------- ------------------ -----------------------------------
  **\#**   **CEO Action       **Detail**
           Required**         

  **1**    **Countersign FSD  Your signature on Section 9 (Review
           v2.3 to lock the   Chain & Sign-off) locks FSD v2.3 as
           development        the definitive development baseline
           baseline**         per Blueprint v6 §4.2. No developer
                              may begin coding the M01 PR
                              Amendment module before this gate
                              is passed. Note: CEO
                              countersignature already given 23
                              May 2026 --- this formally
                              documents the locked baseline.

  **2**    **Authorise DB     Five DB objects require CEO
           Migration scripts  countersignature before execution
           (Section 6) for    on any live customer database: (1)
           customer           usp_GetNextAmendNo SP, (2)
           databases**        PO_PRINT_LOG table CREATE, (3)
                              LogDet_PO ALTER
                              (before_values/after_values), (4)
                              rowversion column on PO_APRH, (5)
                              RATE_SOURCE + RATE_JUSTIFICATION
                              columns on PO_APRL.

  **3**    **Formally confirm 101 SQL concatenation lines (CD-01)
           acceptance of VB6  and the DbTmp dual-connection
           backlog items      (CD-04) are intentionally left as
           (CD-01, CD-04)**   VB6 backlog --- outside Stage 0
                              scope and NOT to be carried into
                              SPINRISE. Please formally confirm
                              this is the accepted migration
                              policy on record against the Stage
                              4 sign-off.

  **4**    **Confirm          OI-04 is closed with CEO approval
           Blueprint v1.2     18-May-2026. Multi-vertical pattern
           Section 5.4.1      (PO_PARA.purchase_budget_ctrl_flg =
           update (Abinandan) Y) is agreed. Verify Abinandan has
           is complete**      completed the Blueprint v1.2 §5.4.1
                              documentation update before Stage 4
                              sign-off, as downstream module FSDs
                              will inherit this pattern.

  **5**    **Acknowledge v2.3 v2.2 CEO directive: 3-option rate
           Rate Field         selector does not apply to
           correction         Amendment screen (Last PO Rate and
           (CEO-directed)**   Average Rate do not exist here).
                              v2.3 correctly implements: Rate
                              pre-populated from PO_APRL
                              (RATE_SOURCE=ORIGINAL); manual
                              override = RATE_SOURCE=MANUAL with
                              mandatory RATE_JUSTIFICATION.
                              Please confirm this is the intended
                              behaviour.

  **6**    **Confirm Stage 3  Stage 3 TL-IST Palanivel review is
           TL-IST findings    in progress (target findings by 25
           timeline**         May 2026). If Stage 3 raises
                              material findings after CEO
                              countersignature, a v2.4 amendment
                              may be required. CEO should confirm
                              whether Stage 3 findings can be
                              absorbed into v2.3 or will trigger
                              a new FSD version.
  -------- ------------------ -----------------------------------

# Review Chain & Sign-off Status

  ------------- ------------- ---------- ----------------- ------------------
  **Role**      **Name**      **Date**   **Status**        **Notes**

  **Stage 1 --- Mariyaiya.M   18 May     **✅ COMPLETE**   FSD v2.3 complete.
  Developer**                 2026                         All Blueprint v6
                                                           §4.3 sections. 8
                                                           audit findings
                                                           documented. DDL
                                                           verified against
                                                           live CREATE TABLE.
                                                           Submitted to Sasi.

  **Stage 2 --- Sasi          23 May     **✅ CLEARED**    Stage 0 FULLY
  TL-Dev**                    2026                         APPROVED 18 May
                                                           2026. Stage 2
                                                           CLEARED 23 May
                                                           2026 --- 13/13
                                                           checks PASS, zero
                                                           issues. Stage 2
                                                           re-confirmation
                                                           after v2.2 CEO
                                                           corrections also
                                                           CLEARED. FSD v2.3
                                                           forwarded to
                                                           TL-IST Palanivel
                                                           and CEO
                                                           simultaneously.

  **Stage 3 --- Palanivel     Target: 25 **⏳ IN           Review of FSD
  TL-IST**                    May 2026   PROGRESS**        v2.3. Focus:
                                                           customer
                                                           variations (§5 ---
                                                           EmpCommon,
                                                           PurTypeFlg,
                                                           BackDate), IST
                                                           findings,
                                                           amendment count
                                                           MsgBox business
                                                           rule, LogDet_PO
                                                           before/after
                                                           values. IST
                                                           one-page note
                                                           submitted in
                                                           parallel.

  **Stage 4 --- T. Mani       23 May     **✅              CEO
  CEO**                       2026       COUNTERSIGNED**   countersignature
                                                           given 23 May 2026.
                                                           FSD v2.3 is now
                                                           locked development
                                                           baseline per
                                                           Blueprint v6 §4.2.
                                                           DB Migration (§6)
                                                           approved for
                                                           execution. Stage 3
                                                           TL-IST Palanivel
                                                           review in progress
                                                           --- target
                                                           findings by 25 May
                                                           2026.
  ------------- ------------- ---------- ----------------- ------------------

# Stage 4 Sign-off --- CEO Countersignature Block

  ----------------------------------------------
  **⚠️ EXECUTION CONTROL:** CEO countersignature
  on this block locks FSD v2.3 as the definitive
  development baseline per Blueprint v6 §4.2. No
  developer may begin coding M01 PR Amendment.
  DB Migration scripts (Section 6) execute only
  after this gate. CEO countersignature given 23
  May 2026.

  ----------------------------------------------

+-----------------+-----------+---------------+--------------------------------------------------------+
| **Stage 1 ---   | **Stage 2 | **Stage 3 --- | **Stage 4 --- CEO**                                    |
| Developer**     | ---       | TL-IST**      |                                                        |
|                 | TL-Dev**  |               |                                                        |
+-----------------+-----------+---------------+--------------------------------------------------------+
| **Mariyaiya.M** | **Sasi**  | **Palanivel** | **T. Mani**                                            |
|                 |           |               |                                                        |
| Date: 18 May    | Date: 23  | Date: Target  | Date: 23 May 2026                                      |
| 2026            | May 2026  | 25 May 2026   |                                                        |
|                 |           |               | **Status: ✅ COUNTERSIGNED**                           |
| **Status: ✅    | **Status: | **Status: ⏳  |                                                        |
| COMPLETE**      | ✅        | IN PROGRESS** | CEO countersignature 23 May 2026 --- FSD v2.3 locked   |
|                 | CLEARED** |               | as definitive development baseline per Blueprint v6    |
| FSD v2.3        |           | Focus:        | §4.2. DB Migration §6 approved for execution.          |
| complete. All 9 | Stage 0   | Customer      |                                                        |
| Blueprint v6    | FULLY     | variations    | Signature:                                             |
| §4.3 sections.  | APPROVED. | (§5 ---       | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |
| 8 audit         | Stage 2   | EmpCommon,    |                                                        |
| findings        | CLEARED   | PurTypeFlg,   |                                                        |
| documented. DDL | 13/13     | BackDate),    |                                                        |
| verified.       | checks    | amendment     |                                                        |
|                 | PASS. FSD | count rule,   |                                                        |
|                 | v2.3      | LogDet_PO     |                                                        |
|                 | forwarded | before/after, |                                                        |
|                 | to        | rate field    |                                                        |
|                 | TL-IST +  | correction.   |                                                        |
|                 | CEO.      |               |                                                        |
+-----------------+-----------+---------------+--------------------------------------------------------+

# Stage 0 Gate Results --- Blueprint v6.0 (Nine Gates)

Blueprint v6 §5.1: Sasi is the only person who can issue Stage 0
sign-off. Stage 0 FULLY APPROVED by TL-Dev Sasi --- all 8 audit findings
resolved, all 35 error handlers confirmed added. No conditional
sign-off. VB6 file not to be re-opened.

+---------------+---------------+---------------+----------------------------+
| **Gate**      | **Blueprint   | **Result**    | **Evidence & SPINRISE      |
|               | v6 Check**    |               | Action**                   |
+---------------+---------------+---------------+----------------------------+
| **G1**        | CustID blocks | **PASS**      | Zero If CustID= / If       |
|               | removed       |               | UCase(CustID) branches in  |
|               |               |               | cleaned code. EmpCommon,   |
|               |               |               | PurTypeFlg, BackDate are   |
|               |               |               | global variables set at    |
|               |               |               | application login from     |
|               |               |               | po_para (M01 PO module     |
|               |               |               | parameter table) --- not   |
|               |               |               | ig_param reads inside this |
|               |               |               | form. (Sasi Finding 1,     |
|               |               |               | Stage 2 re-confirmation    |
|               |               |               | v2.3.)                     |
+---------------+---------------+---------------+----------------------------+
| **G2**        | Dead UI code  | **PASS**      | Design controls with no    |
|               | removed       |               | active code references     |
|               |               |               | removed. Form design       |
|               |               |               | cleaned.                   |
+---------------+---------------+---------------+----------------------------+
| **G3**        | Commented-out | **PASS**      | All 88 comment lines       |
|               | code removed  |               | removed (AF-06). Includes  |
|               |               |               | CR/11/037 commented        |
|               |               |               | validation block and       |
|               |               |               | developer annotations.     |
|               |               |               | Zero comment lines remain. |
+---------------+---------------+---------------+----------------------------+
| **G4**        | Debug code    | **PASS**      | Zero Stop / Debug.Print /  |
|               | removed       |               | debug MsgBox in cleaned    |
|               |               |               | code.                      |
+---------------+---------------+---------------+----------------------------+
| **G5**        | Deprecated    | **PASS\***    | CrystalReport1,            |
|               | API calls     |               | MSDataShape SHAPE queries, |
|               | flagged       |               | DataCombo1 (MSDATLST),     |
|               |               |               | MaskEdBox (MSMASK32),      |
|               |               |               | DataGrid1 (MSDATGRD) ---   |
|               |               |               | all noted in CD-05.        |
|               |               |               | SPINRISE replaces all with |
|               |               |               | React/Dapper equivalents.  |
|               |               |               | (\*5 OCX noted for         |
|               |               |               | SPINRISE replacement.)     |
+---------------+---------------+---------------+----------------------------+
| **G6**        | Transaction   | **PASS**      | 2 BeginTrans.              |
|               | integrity     |               | BUTTON_Click: 4            |
|               | clean         |               | CommitTrans + 3            |
|               |               |               | RollbackTrans error paths. |
|               |               |               | delmodclick: CommitTrans + |
|               |               |               | RollbackTrans in           |
|               |               |               | delmodclick_Error. All     |
|               |               |               | paths bounded (AF-02 +     |
|               |               |               | AF-08 corrected and        |
|               |               |               | verified).                 |
+---------------+---------------+---------------+----------------------------+
| **G7**        | Error         | **PASS**      | All 35 subs corrected: On  |
|               | handling      |               | Error GoTo                 |
|               | present       |               | \[SubName\]\_Error added   |
|               |               |               | to Form_Load,              |
|               |               |               | adoPrimaryRS_MoveComplete, |
|               |               |               | bindcontls, undoLookup,    |
|               |               |               | ScopeLookup and 30 others. |
|               |               |               | G7 fully cleared.          |
|               |               |               | SPINRISE: all endpoints in |
|               |               |               | try-catch + Serilog.       |
+---------------+---------------+---------------+----------------------------+
| **G8**        | OERN removed  | **PASS**      | AF-03 corrected: all 7     |
|               | --- zero      |               | bare \'On\' fragments      |
|               | tolerance     |               | replaced or removed. Zero  |
|               |               |               | active On Error Resume     |
|               |               |               | Next in cleaned file. All  |
|               |               |               | 35 subs have On Error GoTo |
|               |               |               | handlers. Stage 0 FULLY    |
|               |               |               | APPROVED.                  |
+---------------+---------------+---------------+----------------------------+
| **G9**        | Global        | **PASS**      | EmpCommon (4 refs),        |
|               | variable path |               | PurTypeFlg (bindcontls +   |
|               | confirmed     |               | IndType), BackDate (date   |
|               | (po_para      |               | validation) --- all        |
|               | source)       |               | present as global          |
|               |               |               | variables set at login     |
|               |               |               | from po_para. No ig_param  |
|               |               |               | or in_para reads inside    |
|               |               |               | this form. No orphaned     |
|               |               |               | flags. (Sasi Stage 2       |
|               |               |               | re-confirmation v2.3.)     |
+---------------+---------------+---------------+----------------------------+
| **OVERALL: 9 PASS \| 0 FAIL \| NOTE: G5 OCX/SHAPE flagged for SPINRISE     |
| replacement (tracked in CD-05)**                                           |
+----------------------------------------------------------------------------+

# Compliance Audit Findings (AF-01 to AF-08) --- All Resolved

Audit performed against Blueprint v6.0 and VB6 source code
(tmpindAment.frm), Stage 0 gate checks 18 May 2026. All 8 findings
resolved. Stage 0 FULLY CLEARED and confirmed by TL-Dev Sasi --- no
conditional sign-off.

  ------------- -------------------- ---------- ----------------------------
  **Finding**   **Issue**            **Risk**   **Resolution (Stage 0
                                                confirmed by Sasi)**

  **AF-01**     G7 --- 35 subs: no   **HIGH**   RESOLVED ✔ Stage 0 confirmed
                On Error GoTo                   by TL-Dev Sasi: All 35 On
                handler                         Error GoTo handlers added to
                                                Form_Load and all affected
                                                subs. CD-03 raised.
                                                SPINRISE: all C# API
                                                endpoints in try-catch with
                                                Serilog. React toast on API
                                                error.

  **AF-02**     G6 --- delmodclick   **HIGH**   RESOLVED ✔ CommitTrans added
                BeginTrans unmatched            after Call
                (original file)                 adddelmod(BUTTON). On Error
                                                GoTo delmodclick_Error
                                                added. RollbackTrans in
                                                error label. Verified in
                                                cleaned file. No CD raised
                                                --- fix confirmed.

  **AF-03**     G8 --- 7 bare On     **MED**    RESOLVED ✔ Stage 0 confirmed
                Error Resume Next               by TL-Dev Sasi: 4 replaced
                lines (original                 with On Error GoTo + error
                file)                           label; 3 removed (sub
                                                already had GoTo handler).
                                                Zero active OERN in cleaned
                                                file.

  **AF-04**     G5 --- SELECT        **HIGH**   RESOLVED ✔ Stage 0 confirmed
                MAX(amendno) race               by TL-Dev Sasi: newdocno()
                condition in                    fully rewritten to call
                newdocno()                      usp_GetNextAmendNo SP via
                                                ADODB.Command with typed
                                                parameters. SP uses
                                                SERIALIZABLE + UPDLOCK +
                                                HOLDLOCK. CD-01 documents
                                                the SPINRISE SQL SEQUENCE
                                                approach.

  **AF-05**     G4 --- 101 SQL       **HIGH**   NOTED ✔ Stage 0 confirmed by
                concatenation lines             TL-Dev Sasi: Tracked as G4
                (backlog)                       backlog per Blueprint v6.
                                                Not fixed in VB6 (out of
                                                Stage 0 scope). SPINRISE:
                                                Dapper \@parameter binding
                                                throughout. Zero
                                                string-built SQL. CD-01
                                                raised.

  **AF-06**     G3 --- 88 comment    **MED**    RESOLVED ✔ All 88 comment
                lines including                 lines removed in cleaned
                commented business              form. Zero comment lines
                logic                           remain. CR/11/037 block
                                                removed --- logic confirmed
                                                superseded by current code.

  **AF-07**     DbTmp second ADO     **MED**    CD-04 raised. VB6 AS-IS
                connection in Add               retained --- fixing would
                save path                       require significant
                                                restructure outside Stage 0
                                                scope. SPINRISE: single
                                                Dapper IDbConnection +
                                                IDbTransaction for all
                                                writes. No parallel
                                                connections.

  **AF-08**     G6 ---               **MED**    RESOLVED ✔ db.RollbackTrans
                BUTTON_Click_Error              added to BUTTON_Click_Error
                handler missing                 and er1 handlers. Zero OERN.
                RollbackTrans                   G8 PASS.
                (original file)                 
  ------------- -------------------- ---------- ----------------------------

# Critical Defects (CD-01 to CD-05) --- Must Not Carry Into SPINRISE

All Critical Defects have confirmed SPINRISE fixes. VB6 defects marked
HIGH must not appear in any SPINRISE code.

  ----------- --------------- ---------- ----------------------------
  **CD No**   **Defect**      **Risk**   **SPINRISE Fix Confirmed**

  **CD-01**   SQL string      **HIGH**   Dapper \@parameter binding
              concatenation              throughout all C# endpoints.
              (101 lines)                Zero string-built SQL in
                                         SPINRISE. SafeStr() helper
                                         removed entirely.

  **CD-02**   Crystal Reports **HIGH**   QuestPDF PrAmendmentReport
              dependency                 (compact, \<5 lines) and
              (RepPO.rpt)                PrAmendmentFullReport (full,
                                         \>=5 lines). Confirmed class
                                         names. Re-print via
                                         REPRINT_FLG + PO_PRINT_LOG.

  **CD-03**   G7/G8 ---       **HIGH**   SPINRISE: all C# API
              Form_Load + 35             endpoints in try-catch with
              subs without               Serilog structured logging.
              error handler              React toast on API error.
                                         VB6: all 35 handlers added
                                         --- Stage 0 fully cleared.

  **CD-04**   DbTmp dual ADO  **MED**    SPINRISE: single Dapper
              connection in              IDbConnection +
              Add save path              IDbTransaction for all
                                         writes in one atomic
                                         operation. No parallel
                                         connections. VB6 AS-IS
                                         retained as known backlog.

  **CD-05**   OCX / legacy    **HIGH**   React DatePicker, Ant Design
              technology                 Table, React select,
              dependencies               standard Dapper JOINs
              (G5)                       replacing SHAPE syntax. Zero
                                         OCX in SPINRISE.
  ----------- --------------- ---------- ----------------------------

# Key SPINRISE Changes --- CEO-Directed Decisions & v2.3 Final Baseline

  -------------------- ---------------------------------- ------------------
  **Area**             **Decision / Change (v2.3 Final)** **Status**

  **Rate Field         Rate pre-populated from PO_APRL on **CEO-Directed**
  (Amendment Screen)** Amendment screen load              
                       (RATE_SOURCE=ORIGINAL). Manual     
                       user override →                    
                       RATE_SOURCE=MANUAL,                
                       RATE_JUSTIFICATION mandatory.      
                       NOTE: 3-option selector (Last PO   
                       Rate / Average Rate) does NOT      
                       apply to Amendment screen --- CEO  
                       directive v2.2/v2.3.               

  **Document Numbers** SQL SEQUENCE via                   **Changed**
                       usp_GetNextAmendNo --- zero MAX+1  
                       race condition. SERIALIZABLE       
                       isolation + UPDLOCK + HOLDLOCK.    

  **Print Module**     Crystal Reports → QuestPDF.        **Changed**
                       PrAmendmentReport (\<5 lines) +    
                       PrAmendmentFullReport (\>=5        
                       lines). Re-print: REPRINT_FLG +    
                       PO_PRINT_LOG.                      

  **Audit Trail**      ADD + MOD + DEL all logged to      **Changed**
                       LogDet_PO with before/after        
                       values. Atomic with main DML       
                       transaction.                       

  **Multi-vertical**   OI-04 closed. Pattern:             **CEO Approved**
                       PO_PARA.purchase_budget_ctrl_flg = 
                       Y. Blueprint v1.2 §5.4.1 ---       
                       Abinandan.                         

  **Pre-GST Scan**     CLEAN --- zero                     **Clean**
                       AED/BED/Cess/VAT/CST in            
                       tmpindAment.frm. SCOPECODE removed 
                       from SPINRISE UI (DB column        
                       retained for legacy data).         

  **OCX Elimination**  Crystal Reports, MSDATLST,         **Changed**
                       MSMASK32, MSDATGRD, MSDataShape    
                       SHAPE --- all replaced by          
                       React/Dapper equivalents (CD-05).  

  **ig_param → po_para EmpCommon, PurTypeFlg, BackDate    **Corrected v2.3**
  (v2.3 correction)**  are global variables from po_para  
                       login --- NOT ig_param reads       
                       inside this form. Corrected in     
                       v2.3 per Sasi Stage 2              
                       re-confirmation.                   

  **BackDate rule      Amendment Date must equal pdate    **Corrected v2.3**
  (v2.3 correction)**  for ALL customers. No BackDate     
                       conditional exists in this form.   
                       Kumaragiri-specific entry in prior 
                       versions was incorrect --- removed 
                       in v2.3.                           
  -------------------- ---------------------------------- ------------------

# DB Migration --- 5 Objects Pending CEO Countersignature

  ----------------------------------------------
  **⚠️ EXECUTION CONTROL: Execute only after CEO
  countersignature. Not to be run in any live
  customer database before CEO approval is
  received.**

  ----------------------------------------------

  ------------------------ ---------- ----------------------------
  **DB Object**            **Type**   **Purpose / Notes**

  **usp_GetNextAmendNo**   **SP       Generates next amendment
                           CREATE**   number atomically.
                                      SERIALIZABLE isolation +
                                      UPDLOCK + HOLDLOCK on
                                      po_aprh. Returns -1 if
                                      PO_DOC_PARA row missing.
                                      Parameters: \@divcode
                                      VARCHAR(10), \@v_stdate
                                      VARCHAR(20), \@v_endate
                                      VARCHAR(20), \@newdocno INT
                                      OUTPUT.

  **PO_PRINT_LOG**         **TABLE    Logs every print event for
                           CREATE**   re-print control. Columns:
                                      divcode, amendno, amenddate,
                                      printed_by, printed_on,
                                      reprint_flag. Required by
                                      BR-11 re-print control.

  **LogDet_PO (MOD/DEL     **TABLE    Add before_values,
  support)**               ALTER**    after_values columns
                                      (nvarchar) if not present.
                                      SPINRISE logs before/after
                                      values for MOD operations.
                                      Confirm with DBA whether
                                      existing LogDet_PO schema
                                      needs ALTER.

  **rowversion on          **COLUMN   ALTER TABLE PO_APRH ADD
  PO_APRH**                ADD**      rowversion ROWVERSION.
                                      Required for concurrency
                                      control per Blueprint v6
                                      §12. Prevents lost updates
                                      on concurrent amendment
                                      saves.

  **PO_APRL.RATE_SOURCE    **2x       RATE_SOURCE varchar(20) NULL
  and RATE_JUSTIFICATION** COLUMN     --- stores ORIGINAL
                           ADD**      (pre-populated from PO_APRL
                                      on Amendment screen load) or
                                      MANUAL (user override).
                                      RATE_JUSTIFICATION
                                      varchar(200) NULL ---
                                      mandatory when RATE_SOURCE =
                                      MANUAL. CEO rate directive
                                      v2.2/v2.3.
  ------------------------ ---------- ----------------------------

# Open Items (OI-01 to OI-05) --- All Resolved / Closed

OI-01 and OI-03 resolved. OI-02 closed --- adddelmod() is UI-only
(toolbar buttons), zero DB writes, no nested transaction risk. OI-04
closed --- CEO approved Architecture Proposal 18-May-2026. OI-05 closed
--- no maximum amendment count enforced at any live customer (CEO
directive 22-May-2026).

  ----------- ---------------- -------------- ---------------------------------- -----------
  **OI No**   **Item**         **Status**     **Resolution**                     **Owner**

  **OI-01**   newdocno() SP    **RESOLVED**   usp_GetNextAmendNo written and     **Sasi**
              deployment                      available. Deploy after CEO        
                                              countersignature per Section 6     
                                              execution control.                 

  **OI-02**   delmodclick      **CLOSED**     adddelmod() is UI-only (toolbar    **Sasi**
              transaction                     buttons). Zero DB writes. No       
              pattern                         nested transaction risk. Confirmed 
                                              by Sasi --- Stage 2 cleared.       

  **OI-03**   G8 error         **RESOLVED**   All 35 On Error GoTo handlers      **Sasi**
              handlers --- 35                 added. Stage 0 fully cleared by    
              subs                            Sasi 18 May 2026. No further       
                                              action required.                   

  **OI-04**   Multi-vertical   **CLOSED**     CEO approved Architecture Proposal **CEO T.
              architecture                    18-May-2026. Pattern:              Mani**
              (Budget                         PO_PARA.purchase_budget_ctrl_flg = 
              Category)                       Y. Blueprint v1.2 §5.4.1 ---       
                                              Abinandan.                         

  **OI-05**   Amendment count  **CLOSED**     CEO directive 22-May-2026. No      **CEO T.
              --- no maximum                  maximum amendment count enforced   Mani**
              limit                           at any live customer. AmendNo      
                                              MsgBox is informational only.      
                                              SPINRISE retains as count badge.   
                                              No hard block. No ig_param flag    
                                              needed.                            
  ----------- ---------------- -------------- ---------------------------------- -----------

Kalpatharu Software Ltd \| SPINRISE Migration \| M01 PO \| PR Amendment
Entry \| FSD v2.3 \| TL-IST Expert Review \| CEO Stage 4 Submission \|
23 May 2026 \| Internal Confidential
