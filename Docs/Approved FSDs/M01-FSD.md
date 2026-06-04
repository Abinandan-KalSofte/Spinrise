**KALSOFTE ERP**

Kalpatharu Software Ltd, Coimbatore

─────────────────────────────────────────

**FORM SPECIFICATION DOCUMENT**

Purchase Requisition \| Module: Purchase Order Management

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Field**               **Value**
  ----------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Screen Name             tmpPoindent --- Purchase Requisition

  Screen Caption          Purchase Requisition

  Module                  Purchase Order Management

  Product                 Kalsofte ERP --- Indian Spinning Mills Edition

  Document Version        2.5 --- Functional Amendment --- v2 --- Incorporates CEO corrections (6 items), Palanivel F-01 to F-14, Seenivasan IST inputs, Scope/Sub-Cost Centre removal. Pending CEO countersignature. Previously approved as v2.3 by CEO T. Mani on 17-Apr-2026. Amendment prepared by Mariyaiya.M --- 11-May-2026. CEO instruction received 01-May-2026. CEO countersignature pending.

  Source Files Analysed   tmpPoindent.frm (7,471 lines), Po_gmdl.bas (2,175 lines), Cry_PR_KSL / Cry_Purchase_Req class modules, Script_for_tables_and_procedures.txt (684 lines), tmpPoindent.log

  Migration Target        SPINRISE Web Platform (React / REST API / SQL Server)

  Document Status         v2.5 --- Functional Amendment. Incorporates CEO corrections (6 items), Palanivel F-01 to F-14, Seenivasan IST inputs, Scope/Sub-Cost Centre removal. All 14 sections complete. All 20 IST questions resolved. 28 SPINRISE recommendations including 12 confirmed defects (Rec 17--28). Prepared 11-May-2026. CEO countersignature pending. (Previously approved as v2.3 by CEO T. Mani on 17-Apr-2026.)

  **Stage 0 Status**      **COMPLETED.** Form cleaned and stabilised. Source reviewed: tmpPoindent.frm (Original: 9,112 lines · Cleaned: 7,471 lines · Full form including design and business logic.). Dead code identified and documented (see Section 5.4). Stage 0 Screen Readiness Checklist completed --- Prepared by: Mariyaiya.M \| TL-Dev: Saikumar.R \| Date: 04-Apr-2026. **TL-Dev Sasi --- Sign-off COMPLETED. Source code approved for FSD generation.**

  **TL-Dev Sign-Off**     **SIGNED OFF.** TL-Dev: Sasi (Saikumar.R) --- reviewed and approved tmpPoindent.frm as the final production-stable version for FSD generation. Sign-off confirmed via email reply. Date: 04-Apr-2026.

  **Sr. IST Sign-Off**    **SIGNED OFF.** Sr.IST: MuthuVel --- reviewed and approved IST part. Sign-off confirmed via email reply. Date: 13-Apr-2026.

  **TL-IST Sign-Off**     **APPROVED.** . TL-IST: Palanivel --- Stage 3 TL-IST sign-off received and approved via email on 17-Apr-2026.

  **PM Sign-Off**         **APPROVED.** . PM: P.B. Saravanan --- Stage 4 PM sign-off received and approved via email on 17-Apr-26. for submission to CEO for final approval.

  **CEO Approval Date**   **APPROVED.** v2.3 approved by CEO T. Mani on 17-Apr-2026. CEO approval recorded via email. This is the first CEO-approved FSD in SPINRISE. Locked development baseline for M01 --- Purchase Requisition. v2.5 pending CEO countersignature.

  **Approved Version**    **v2.5** --- SpinRise-M01-PO-PurchaseRequisition-FSD-v2.5.docx. Previously approved as v2.3 by CEO T. Mani on 17-Apr-2026. v2.5 amendment pending CEO countersignature. Prepared by Mariyaiya.M --- 11-May-2026.
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 1. Screen Purpose

The Purchase Requisition (PR) screen --- internally named tmpPoindent --- is the formal starting point of the procurement cycle in Kalsofte ERP. It allows a department head or an authorised employee (the Requester) to raise a written request to the central purchase team, asking them to procure one or more inventory items on behalf of the requesting department. Each PR captures, at the document header level, the requesting department, the requester\'s employee identity, the date, a reference number, the type of purchase (capital, stores, overhaul, etc.), and the internal section or cost scope. At the line level, each individual item is entered with its item code, description, unit of measure, machine or equipment it is needed for, quantity required, the date by which it is needed, current stock available, approximate cost, and any specific remarks. Once saved, the PR is assigned a unique system-generated number, which then travels through an approval workflow before the purchase team converts it into a formal Purchase Order. The screen fully supports adding new PRs, modifying unapproved ones, deleting unapproved ones, browsing existing records, searching by PR number, printing a formal PR document, and viewing a transaction history for audit purposes.

# 2. Screen Layout

The screen is a maximised MDI child window with a Header Area (document-level fields) and an Item Grid (one row per item). Supporting popup frames open conditionally for lookup, item selection, and deletion.

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Area**              **Field / Control**                                       **Type**                        **Maps To**                       **Notes**
  --------------------- --------------------------------------------------------- ------------------------------- --------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  HEADER                PR. Date (MaskEdBox1)                                     Date DD/MM/YYYY                 PO_PRH.PRDATE                     Auto-set to processing date; calendar picker (DTPicker1) available; forced equal to processing date. SPINRISE AMENDMENT (CEO R2.0 #10): PR Date is editable. Processing date is the default. User may change to any date on or after processing date. DTPicker1.MaxDate = pdate remains. Mariyaiya --- FSD amendment owner.

  HEADER                PR. Number (txtfields\[2\])                               Text / Read-only in query       PO_PRH.PRNO                       Auto-generated by system; manual entry when ManualIndNo=\'Y\'

  HEADER                Department Code (txtfields\[5\])                          Alphanumeric max 3              PO_PRH.DEPCODE                    F1 opens Department lookup; validates against IN_DEP

  HEADER                Department Name (Text2)                                   Read-only display               IN_DEP.DEPNAME                    Auto-filled on dept code entry

  HEADER                Requester Code (txtfields\[1\])                           Numeric max 6 digits            PO_PRH.REQNAME                    F1 opens Employee lookup; resolves name in Text4

  HEADER                Requester Name (Text4)                                    Read-only display               PR_EMP.ENAME                      Auto-filled from employee master

  HEADER                Section (Text3)                                           Text max 20 chars               PO_PRH.SECTION                    Free text sub-department name

  HEADER                Scope Code (txtfields\[3\])                               Numeric max 2 digits            PO_PRH.SCOPECODE                  SPINRISE AMENDMENT (F-05): Scope Code REMOVED from SPINRISE rendering. Usage audit confirmed PO_SCOPETYPE is unpopulated across all live customer databases. DB column PO_PRH.SCOPECODE retained for legacy data compatibility but field is not rendered on the SPINRISE PR form. F1 lookup, auto-fill of Scope Name (Text7), and all associated validation suppressed in SPINRISE. Legacy data preserved. F-05 CLOSED.

  HEADER                Scope Name (Text7)                                        Read-only display               PO_SCOPETYPE.TYPNAME              Auto-filled on scope code entry

  HEADER                Sub-Cost Centre (txtfields\[4\])                          Numeric max 3 digits            PO_PRH.SUBCOST                    SPINRISE AMENDMENT (F-05): Sub-Cost Centre REMOVED from SPINRISE rendering. Usage audit confirmed PO_SCOPETYPE unpopulated across all live customer databases; Sub-Cost Centre is dependent on Scope Code and has no active use case. DB column PO_PRH.SUBCOST retained for legacy data compatibility but field is not rendered on the SPINRISE PR form. Lookup and auto-fill of Sub-Cost Name (Text10) suppressed. Legacy data preserved. F-05 CLOSED.

  HEADER                Order Type / PO Group (txtfields\[7\])                    Text max 5 chars                PO_PRH.PO_GRP                     Visible and mandatory only when PurTypeFlg=1

  HEADER                Reference No. (txtfields\[8\])                            Text max 20 chars upper-case    PO_PRH.REFNO                      Internal reference; auto upper-cased

  ITEM GRID             Item Code (Col 4 --- ItemCodeTextBox)                     Alphanumeric max 10             PO_PRL.ITEMCODE                   Triggers auto-fill of name, UOM, rate, stock

  ITEM GRID             Item Description (Col 5)                                  Read-only                       IN_ITEM.ITEMNAME                  Auto-filled from item master

  ITEM GRID             UOM (Col 6)                                               Read-only                       IN_ITEM.UOM                       Auto-filled from item master

  ITEM GRID             Rate (Col 7)                                              Decimal 2dp read-only           IN_ITEM.RATE / IN_TRNTAIL         SPINRISE AMENDMENT (CEO R2.0 #14): 3-option rate selector --- (1) Last PO Rate (default; from PO_PRL.LPO_RATE), (2) Average Rate (AVG from IN_TRNTAIL TC=1 receipts for item+division in current FY), (3) Manual Entry (user-entered; triggers mandatory Justification field). Rate selector state stored in new column PO_PRL.RATE_SOURCE (values: LPO/AVG/MANUAL). Justification stored in new column PO_PRL.RATE_JUSTIFICATION (varchar 200). Rate_Find() dead code --- not migrated. CEO decision 07-May-2026.

  ITEM GRID             Current Stock (Col 8)                                     Decimal 3dp read-only           min(stkchk1, stkchk2)             Conservative minimum of today vs. full-year stock

  ITEM GRID             Quantity Required (Col 9)                                 Decimal 3dp right-aligned       PO_PRL.QTYIND                     Mandatory; must be \>= item MINLEVEL

  ITEM GRID             Category (Col 10)                                         Single char                     PO_PRL.CATCODE                    Lookup opens IN_CAT listing

  ITEM GRID             Cost Centre (Col 11)                                      Numeric max 4 digits            PO_PRL.CCCODE                     Lookup opens IN_CC listing for division

  ITEM GRID             Budget Group (Col 12)                                     Alphanumeric max 4 chars        PO_PRL.BGRPCODE                   Optional; lookup available against IN_BGRP

  ITEM GRID             Machine No. (Col 13)                                      Alphanumeric max 5 chars        PO_PRL.MACNO                      F1 opens Machine lookup; validates against MM_MACMAS + dept

  ITEM GRID             Required Date (Col 14)                                    Date DD/MM/YYYY mask            PO_PRL.REQDDATE                   Must be \>= processing date (Add) or \>= PR date (Modify)

  ITEM GRID             Approx. Cost (Col 16)                                     Decimal 2dp max 8 chars         PO_PRL.APPCOST                    Indicative budget figure

  ITEM GRID             Remarks (Col 17)                                          Text max 100 chars upper-case   PO_PRL.REMARKS                    Alpha + numeric + select symbols only

  ITEM GRID             LPO Rate (read-only)                                      Decimal 4dp locked              PO_PRL.LPO_RATE                   Last PO rate from order history

  ITEM GRID             LPO Date (read-only)                                      Date display locked             PO_PRL.LPO_DATE                   Date of last PO for this item

  ITEM GRID             Sample Flag                                               Char Y/N                        PO_PRL.SAMPLE                     Marks sample/trial requests. SPINRISE AMENDMENT (CEO R2.0 #13): default = N (not a sample). Informational display flag on printed PR and approval screen.

  ITEM GRID             Item Thumbnail (grid line) --- NEW (CEO R2.0 #11)         Image / read-only               IN_ITEM.IMAGE (new column)        SPINRISE AMENDMENT: thumbnail image sourced from Item Master (IN_ITEM.IMAGE). Displayed on each PR grid line. Min size 40x40px. Prevents wrong-item selection. CEO decision 07-May-2026. FSD amendment by Mariyaiya.

  ITEM GRID             Item Thumbnail (lookup modal) --- NEW (CEO R2.0 #12)      Image / read-only               IN_ITEM.IMAGE (new column)        SPINRISE AMENDMENT: same thumbnail shown in item lookup popup results grid as a column and as an enlarged hover preview. Consistent with grid line thumbnail. CEO decision 07-May-2026. FSD amendment by Mariyaiya.

  TOOLBAR / ITEM GRID   Add Multiple --- NEW (CEO R2.0 #15, #16)                  Button + modal                  ---                               SPINRISE AMENDMENT: two bulk-entry modes --- (a) Multi-select lookup: browse-and-tick multiple items; each selected item inserted as a separate grid line. Named customer requirement: Pallvaa Mills and SKS (raised by Sasi, CEO R2.0). (b) Row-count insert: power-user numeric entry to add N blank rows at once. CEO decisions 07-May-2026.

  KPI SUMMARY STRIP     KPI Summary Strip (5 cards) --- NEW (CEO R2.0 #17, #29)   Read-only display panel         Computed from PR header + lines   SPINRISE AMENDMENT: 5-card summary strip below item grid. Cards: (1) Total Lines, (2) Total Quantity --- UOM-grouped (separate totals per UOM), (3) Approx Budget, (4) Created By, (5) Approval Status. Add mode suppression: only cards 1 and 2 (Total Lines, Total Quantity) visible in Add mode; cards 3--5 (Approx Budget, Created By, Approval Status) hidden until after first save (POST 201). Cards 3--5 activate in Modify/Find/Query mode. See Rec #32. CEO decisions 07-May-2026.

  ITEM GRID             Budget Category --- NEW (CEO R2.0 #27)                    Text / Lookup (conditional)     PO_PRL.BUDGETCAT (new column)     SPINRISE AMENDMENT: conditional field. Visible and mandatory ONLY when PR Type = C (Capital) AND division vertical profile = Paper Mill. Invisible and not applicable for all spinning mill screens. First multi-vertical field --- sets architecture pattern for all future vertical-specific fields. New column: PO_PRL.BUDGETCAT. Backend implications to be confirmed by Sasi before dev begins. See Recs #30 and #31. CEO decision 07-May-2026 (Muthuvel).

  TOOLBAR               Add (BUTTON\[0\])                                         Command button                  ---                               Ctrl+A; starts new PR; runs 3 pre-add checks

  TOOLBAR               Modify (BUTTON\[1\])                                      Command button                  ---                               Ctrl+M; opens unapproved PR lookup

  TOOLBAR               Delete (BUTTON\[2\])                                      Command button                  ---                               Ctrl+D; full PR or single line deletion

  TOOLBAR               Find (BUTTON\[3\])                                        Command button                  ---                               Ctrl+F; read-only view of any PR

  TOOLBAR               Save (BUTTON\[9\])                                        Command button                  ---                               Ctrl+S; commits to DB with full validation

  TOOLBAR               Cancel (BUTTON\[10\])                                     Command button                  ---                               Ctrl+Back; rolls back transaction

  TOOLBAR               Print (BUTTON\[13\])                                      Command button                  ---                               Ctrl+Y; Crystal Reports PR document

  STATUS BAR            Panel 2                                                   Text display                    Current operation                 Shows mode and guidance messages

  STATUS BAR            Panel 3 / 4                                               Date / Time                     System clock                      Auto-updated current date and time
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 3. Field Rules

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Field**               **Mandatory?**   **Data Type**     **Length / Format**      **Default**       **Notes**
  ----------------------- ---------------- ----------------- ------------------------ ----------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  PR. Date                Yes              Date              DD/MM/YYYY               Processing date   SPINRISE AMENDMENT (CEO R2.0 #10): processing date is the default; user may change to any date on or after processing date. DTPicker1.MaxDate = pdate retained. SPINRISE UX rule: on focus-out from this field when empty --- red border + inline validation message (mandatory field indicator). CEO decision 07-May-2026.

  PR. Number              Yes (auto)       Numeric           Up to 6 digits           Auto-generated    Manual entry if ManualIndNo=\'Y\'; duplicate check via IndentNoChk(). PR Number is auto-generated --- it is not a user-entered field and is not subject to focus-out validation. No red border or inline validation message applies to this field.

  Department Code         Yes              Alphanumeric      Max 3 chars              None              Must exist in IN_DEP for this division. SPINRISE UX rule (CEO correction #4): on focus-out from this field when empty --- red border + inline validation message (mandatory field indicator). Architecture standard for all SPINRISE transaction entry screens.

  Requester Code          Conditional      Numeric           Max 6 digits             None              Mandatory when PurTypeFlg=1. SPINRISE UX rule (CEO correction #4): on focus-out from this field when empty and PurTypeFlg=1 --- red border + inline validation message (mandatory field indicator). Architecture standard for all SPINRISE transaction entry screens.

  Section                 No               Text              Max 20 chars             Blank             Free text; stored in PO_PRH.SECTION

  Scope Code              No               Numeric           Max 2 digits             None              SPINRISE AMENDMENT (F-05): REMOVED from SPINRISE. Field not rendered. DB column PO_PRH.SCOPECODE retained for legacy compatibility only. No validation enforced in SPINRISE. F-05 CLOSED.

  Sub-Cost Centre         No               Numeric           Max 3 digits             None              SPINRISE AMENDMENT (F-05): REMOVED from SPINRISE. Field not rendered. DB column PO_PRH.SUBCOST retained for legacy compatibility only. No validation enforced in SPINRISE. F-05 CLOSED.

  Order Type / PO Group   Conditional      Text              Max 5 chars              None              Mandatory when PurTypeFlg=1. SPINRISE UX rule (CEO correction #4): on focus-out from this field when empty and PurTypeFlg=1 --- red border + inline validation message (mandatory field indicator). Architecture standard for all SPINRISE transaction entry screens.

  Reference No.           No               Text upper-case   Max 20 chars             Blank             Blank REFNO stored as 0 (not NULL) due to IIF logic in INSERT

  Item Code               Yes (per line)   Alphanumeric      Max 10 chars             None              Must exist in IN_ITEM with IsItemActive=1. SPINRISE UX rule (CEO correction #4): on focus-out from this field when empty --- red border + inline validation message (mandatory field indicator). Line-level mandatory field. Architecture standard for all SPINRISE transaction entry screens.

  Quantity Required       Yes (per line)   Decimal 3dp       Max 12 digits            None              Must not be \< item MINLEVEL; cannot be null/zero. SPINRISE UX rule (CEO correction #4): on focus-out from this field when empty --- red border + inline validation message (mandatory field indicator). Line-level mandatory field. Architecture standard for all SPINRISE transaction entry screens.

  Machine No.             No               Alphanumeric      Max 5 chars              None              Must exist in MM_MACMAS for selected dept + macflag=\'M\'

  Required Date           No               Date              DD/MM/YYYY mask          None              If entered: \>= processing date (Add); \>= PR date (Modify)

  Category Code           No               Single char       1 char                   None              Must exist in IN_CAT if entered

  Cost Centre Code        No               Numeric           Max 4 digits             None              Must exist in IN_CC for division if entered

  Budget Group Code       No               Alphanumeric      Max 4 chars upper-case   None              Must exist in IN_BGRP if entered

  Approx. Cost            No               Decimal 2dp       Max 8 chars              None              Informational only; stored in PO_PRL.APPCOST

  Remarks                 No               Text upper-case   Max 100 chars\*          None              \*DB column is varchar(50) --- chars 51--100 truncated silently
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 4. Validation Rules

**[4.1 Pre-Add Validations (checked before user can enter data)]{.underline}**

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Check**                  **Condition**                                                 **Error Message**                                            **Hard Stop?**
  -------------------------- ------------------------------------------------------------- ------------------------------------------------------------ -------------------------
  Item master exists         IN_ITEM has at least one record                               Please Define Item in Item Maste                             Yes --- exits Add

  Dept master exists         IN_DEP has records for division                               Please Define Department in Setup                            Yes --- exits Add

  PR doc number configured   PO_DOC_PARA has entry for \'PURCHASE REQUISITION\'            Please Define Document No. for Requisition in Housekeeping   Yes --- exits Add

  Parameters defined         PO_PARA has a record for divcode                              Budget Qty Not Defined. So check Parameter                   Yes --- halts form load

  Date sequence check        If BACKDATE=\'N\': processing date \>= max existing PR date   Date should be Equal to Current Date Or Max PR. Date         Yes --- exits Add
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[4.2 Header Field Validations (at Save time)]{.underline}**

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Field**            **Rule**                                                                                                                                                                                                          **Error Message**                                  **Hard Stop?**
  -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------- --------------------------------------
  PR Date              Must be a valid date AND on or after the processing date. SPINRISE AMENDMENT (CEO R2.0 #10): PR Date is now editable; processing date is the default only --- not forced equal. Validation updated accordingly.   PR. Date must be on or after the processing date   Yes --- resets to pdate

  PR Date              Non-date value entered                                                                                                                                                                                            Please enter valid date                            Yes --- resets focus

  Department Code      Cannot be empty at save                                                                                                                                                                                           Department Cannot be empty                         Yes --- exits Save

  Order Type           Cannot be empty when PurTypeFlg=1                                                                                                                                                                                 Please Select Order Type                           Yes --- exits Save

  Requester Code       Cannot be empty when PurTypeFlg=1                                                                                                                                                                                 Requester Name Cannot be empty                     Yes --- exits Save

  PR Number (manual)   Must not duplicate existing PR in year --- checked by IndentNoChk()                                                                                                                                               PR. number already Exist                           Yes --- resets focus to number field
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[4.3 Item Line Validations (per line and at Save time)]{.underline}**

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Field**                                   **Rule**                                                                                                                                                                  **Error Message**                                                **Hard Stop?**
  ------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------- --------------------------------
  Item Code (blank line)                      Lines with blank item code silently deleted before save                                                                                                                   (none --- silent purge)                                          Silent

  Quantity Required                           Cannot be null on any non-blank line                                                                                                                                      Required quantity cannot be empty                                Yes --- grid focus

  At least one line                           PR must have \>= 1 valid line after blank-line purge                                                                                                                      Purchase Requisition Requires at least one Item                  Yes --- exits Save

  Quantity vs. Min Level                      Qty must be \>= IN_ITEM.MINLEVEL (if defined \> 0)                                                                                                                        Required Quantity Cannot be Less than Minimum Order Quantity..   Warning --- resets to MINLEVEL

  Required Date --- invalid                   Non-date value in date field                                                                                                                                              Invalid Date                                                     Yes --- clears field

  Required Date --- Add                       If entered: must be \>= processing date                                                                                                                                   Required Date must be equal to or after the Processing Date.     Yes --- clears field

  Required Date --- Modify                    If entered: must be \>= PR header date                                                                                                                                    Required Date cannot be less than PR. Date                       Yes --- resets to original

  Machine Code                                Must exist in MM_MACMAS for selected dept + macflag=\'M\'                                                                                                                 (triggers MacLookup popup automatically)                         Popup --- must select valid

  Category Code                               Must exist in IN_CAT                                                                                                                                                      (triggers Category Listing popup automatically)                  Popup --- must select valid

  Cost Centre Code                            Must exist in IN_CC for division                                                                                                                                          (triggers Cost Centre Listing popup automatically)               Popup --- must select valid

  Budget Group Code                           Must exist in IN_BGRP                                                                                                                                                     (triggers Group lookup popup automatically)                      Popup --- must select valid

  Duplicate item+machine                      Same item code + machine code cannot repeat on same PR                                                                                                                    Same Machine or Same Item should not Be repeat                   Yes --- clears item, refocuses

  Rate Justification --- NEW (CEO R2.0 #14)   SPINRISE AMENDMENT: when RATE_SOURCE = MANUAL, PO_PRL.RATE_JUSTIFICATION must not be blank (max 200 chars). Enforced at API save layer. CEO decision 07-May-2026 (#14).   Rate justification is required when Manual rate is selected      Yes --- exits Save
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[4.4 Customer-Specific / Parameter-Driven Validations]{.underline}**

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Parameter**                                                                                                                                                                                                                                                                                               **When Active**              **Validation Rule**                                                                                   **Error Message / Behaviour**
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------- ----------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
  PendingOrderPara = \'Y\'                                                                                                                                                                                                                                                                                    On item code entry           Calls KSP_INDEDNT_CHECK. If open PO exists for same item+dept in year, warns user.                    \'Pending Indent Quantity: \[qty\]\' then \'Do you want to exit?\' --- Yes terminates app

  BudgetQty = \'Y\'                                                                                                                                                                                                                                                                                           Form load                    Sub-Cost Centre label highlighted red as budget-tracking warning                                      Visual warning only; no hard stop on this form

  ManualIndNo = \'Y\'                                                                                                                                                                                                                                                                                         On PR number field tab-out   IndentNoChk() checks for duplicate PR number in current year                                          \'PR. number already Exist\' --- hard stop, refocuses

  BACKDATE = \'N\' in IN_PARA (Store Inventory module parameter --- confirmed by IST IST-7: PO module has no native backdate parameter. This parameter is read from IN_PARA which belongs to the Store Inventory module. SPINRISE note: backdate restriction for PR is not a PO module configuration item.)   Add / Delete initiated       Processing date must be \>= max existing PR date in year                                              \'Date should be Equal to Current Date Or Max PR. Date\'

  PurTypeFlg = 1                                                                                                                                                                                                                                                                                              Add / Save                   Order Type (PO_GRP) field becomes mandatory; all lookups filtered by user\'s allowed purchase types   \'Please Select Order Type\' at save

  APPFLG = \'Y\' (approved)                                                                                                                                                                                                                                                                                   Modify / Delete attempted    Already-approved PRs cannot be modified or deleted                                                    Filtered out of Modify/Delete lookup --- never shown to user

  cancelflag IS NOT NULL                                                                                                                                                                                                                                                                                      Modify / Delete              Cancelled PRs excluded from Modify/Delete                                                             Filtered out of lookup query

  amendno \> 0                                                                                                                                                                                                                                                                                                Modify / Delete              Amended PRs excluded from Modify/Delete                                                               Filtered out of lookup query --- only original PRs modifiable
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 5. Business Logic

**[5.1 Document Number Generation]{.underline}**

- Auto mode (ManualIndNo=\'N\'): newdocno() reads PO_DOC_PARA for \'PURCHASE REQUISITION\' to get the starting number (STDOCNO), then reads MAX(PRNO) from PO_PRH for the current division and year. New number = MAX + 1, or STDOCNO if no PRs exist yet. NOT ATOMIC --- concurrent users can generate duplicates (see Section 8, Risk 2).

- Manual mode (ManualIndNo=\'Y\'): user types the number; IndentNoChk() runs a COUNT(\*) check against PO_PRH to reject duplicates before save.

**[5.2 Auto-Fill Chains on Field Entry]{.underline}**

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **When this field is entered\...**   **These fields auto-fill\...**                                                           **Data Source**
  ------------------------------------ ---------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Item Code                            Item Description, UOM, Rate (last GRN rate), Current Stock (min of today vs. year-end)   IN_ITEM + IN_TRNTAIL (via Rate_Find) + IN_IDET/IN_TRNTAIL (via stkchk1/stkchk2)

  Machine Code                         Machine Description (Text6), Machine Model (TxtMacModel)                                 MM_MACMAS filtered by divcode + depcode + macflag=\'M\'

  Department Code                      Department Name (Text2)                                                                  IN_DEP for current division

  Requester Code                       Requester Name (Text4)                                                                   PR_EMP (EmpCommon=True: company-wide; EmpCommon=False: division-filtered)

  Scope Code                           Scope Name (Text7)                                                                       SPINRISE AMENDMENT (F-05): REMOVED. Scope Code not rendered in SPINRISE. Auto-fill of Scope Name suppressed. DB column retained for legacy data only.

  Sub-Cost Centre Code                 Sub-Cost Name (Text10)                                                                   SPINRISE AMENDMENT (F-05): REMOVED. Sub-Cost Centre not rendered in SPINRISE. Auto-fill of Sub-Cost Name suppressed. DB column PO_PRH.SUBCOST retained for legacy data only.

  Machine Code cleared                 Machine Description cleared to blank                                                     Immediate --- MachineTextBox_Change event
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[5.3 Stock Calculation (stkchk1 + stkchk2 --- conservative minimum rule)]{.underline}**

+------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Stock Display Formula**                                                                                                                            |
|                                                                                                                                                      |
| stkchk1 computes: Opening Balance (IN_IDET TC=0) + Receipts (TC types 1,3,5,7,9,12) -- Issues (TC types 2,4,6,8,11) up to today (pdate)              |
|                                                                                                                                                      |
| stkchk2 computes: Same formula but date range extends to financial year END (yldate); excludes TC type 12 (transfers)                                |
|                                                                                                                                                      |
| Displayed Current Stock = min(stkchk1 result, stkchk2 result)                                                                                        |
|                                                                                                                                                      |
| If both are equal, uses stkchk1 value                                                                                                                |
|                                                                                                                                                      |
| If global Purstock is set (godown-wise mode), both functions filter to that specific godown                                                          |
|                                                                                                                                                      |
| Purpose: show the MORE CONSERVATIVE of today\'s actual stock vs. projected year-end stock --- avoids raising PRs for stock that may not be available |
+------------------------------------------------------------------------------------------------------------------------------------------------------+

**[5.4 Rate Retrieval (Rate_Find)]{.underline}**

- Queries IN_TRNTAIL INNER JOIN IN_TRNHEAD for TC=1 (purchase receipt / GRN), filtered to the current item and division, ordered by DOCDT descending, taking TOP 1. Displays the last actual receipt rate (not the PO rate). Stored in PO_PRL.RATE as a reference for the purchase team.

- **⚠️ DEAD CODE --- Confirmed April 2026.** The TC=1 rate retrieval query (Rate_Find) was written to read the last GRN receipt rate from the Store module but is not triggered in any live customer scenario in the PO context. Excluded from SPINRISE. Rate_Find() function is not to be migrated. SPINRISE AMENDMENT (CEO R2.0 #14): Rate field replaced by a 3-option rate selector --- (1) Last PO Rate (default; reads PO_PRL.LPO_RATE), (2) Average Rate (AVG of IN_TRNTAIL TC=1 receipts for item+division in current FY), (3) Manual Entry (user-entered; triggers mandatory RATE_JUSTIFICATION field). New columns: PO_PRL.RATE_SOURCE (LPO/AVG/MANUAL), PO_PRL.RATE_JUSTIFICATION (varchar 200). API: GET /items/{itemcode}/rate returns all three values. CEO decision 07-May-2026.

**[5.5 PR Status Derivation (qry1 inline CASE logic)]{.underline}**

  -----------------------------------------------------------------------------------------
  **Condition**                                              **Displayed Status**
  ---------------------------------------------------------- ------------------------------
  PRSTATUS IS NULL AND FirstApp IS NULL OR FirstApp = \'\'   Requested

  PRSTATUS IS NULL AND QTYREQD = 0                           PR. CANCELLED

  PRSTATUS IS NULL AND DirectApp = \'Y\'                     FINAL LEVEL APPROVED

  PRSTATUS IS NULL AND ThirdApp = \'Y\'                      THIRD LEVEL APPROVED

  PRSTATUS IS NULL AND SecondApp = \'Y\'                     SECOND LEVEL APPROVED

  PRSTATUS IS NULL AND FirstApp = \'Y\'                      FIRST LEVEL APPROVED

  PRSTATUS = \'O\' AND QtyOrd \> 0                           ORDERED

  PRSTATUS = \'O\' AND QtyOrd = 0                            ORDER CANCELLED

  PRSTATUS = \'E\'                                           ENQUIRED

  PRSTATUS = \'C\'                                           RECEIVED
  -----------------------------------------------------------------------------------------

**[5.5a PR Approval Workflow (Confirmed by TL-IST Palanivel, April 2026)]{.underline}**

- **Level 1 --- VB Desktop Module** (First Level Approval). Handled within the VB PR module. For Pallavaa customer, this level has recently also been added to the Web approval module. Other customers continue to use VB for Level 1.

- **Level 2 --- Web Approval Module** (Before Final Level Approval). Screen name: Purchase Order \> Purchase Requisition Before Final Level Approval. Handled entirely in the web module. Provision exists to bypass this level when only a single approval level is required.

- **Level 3 --- Web Approval Module** (Final Level Approval). Screen name: Purchase Order \> Purchase Requisition Final Level Approval. Handled in the web module. PO creation can only proceed once Final Level Approval is recorded. URL: http://10.20.70.200/POApproval/Login.aspx

- **SPINRISE design note:** Up to 3 approval levels supported; configurable per division via parameters (Pr_ILevel, Pr_FLevel in PO_PARA). A single level may be sufficient for some customers. Approval configuration currently done at backend only --- SPINRISE must provide a Division Setup UI screen for approval chain configuration (see Section 12, Rec #26). Pallavaa is the only customer currently using all levels via the web module. Other customers have not adopted web approval.

**[5.6 Item Lookup Enrichment (Penpodetails = \'Y\')]{.underline}**

- When enabled, the item popup query is enriched with: Pending Qty (from open POs), Delivery Date, Minimum Level, Maximum Level, Supplier Lead Time (calculated from IN_TRNTAIL date differences), and Last Supplier Name (from FA_SLMAS). This gives buyers stock intelligence before raising a PR.

**[5.7 Deletion Modes]{.underline}**

- Option 1 --- Full PR delete: user selects PR from lookup, chooses Option1 radio button, clicks Save. Deletes the entire header and all lines.

- Option 2 --- Single line delete: user chooses Option2 radio button, double-clicks a grid row. That line is deleted from adoSecondaryRS. On Save, all remaining lines are deleted and reinserted (serial numbers reassigned from 1).

**[5.8 Audit Logging]{.underline}**

- Every Add and Modify writes to LogDet_po: one row per PR line. Captures user ID, username, IP address, hostname, timestamp, operation (\'ADD\' or \'MODIFY\'), module number (4), item code, machine, quantity, rate, last PO rate, last PO date, last supplier.

- Note: LogDet_po.Quantity is integer --- decimal quantities are truncated in the audit log.

**[5.9 Purchase Advice Linkage]{.underline}**

- If prano \> 0 (PR raised from a Purchase Advice), after CommitTrans the form executes: UPDATE PO_PAH SET PRNO=\[new PR number\] WHERE PRANO=\[prano\]. This runs OUTSIDE the transaction --- if it fails, the PR is saved but the advice link is lost.

## 5.10 EmpCommon Flag --- Origin, Logic, and Division Assignment

**Origin**

EmpCommon is a Boolean variable set at login time by the main MDI shell. It is populated by reading the column PO_Para.EmpMasterComm for the active DivCode from the database. There is no hardcoding of this value anywhere in the form (tmpPoindent.frm) or the common module (Po_gmdl.bas) --- the flag is entirely database-driven and division-specific. This means each division in a multi-division installation can independently carry a different value.

**Y / N Logic**

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **PO_Para.EmpMasterComm**   **EmpCommon (Boolean)**   **Crystal Report Used**                                      **Employee Lookup Scope**
  --------------------------- ------------------------- ------------------------------------------------------------ -------------------------------------------------------------------------------------------------------------
  'Y'                         True                      Cry_Purchase_Req (parameters: \@divcode, \@Docno, \@Docdt)   Company-wide (PR_EMP not filtered by divcode). Confirmed divisions: Saranya, Armstrong, Cheran, Skaat, VTS.

  'N' or NULL                 False                     Cry_PR_KSL (parameters: \@divcode, \@prdate, \@prno)         Division-filtered (PR_EMP WHERE divcode = active division). All other divisions.
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Cross-reference: See Section 7.7 for the Crystal Reports class modules that this flag selects between, and Section 11 for the full customer variation register entry.

# 6. TC Framework

This screen uses the Kalsofte TC (Transaction Code) framework. All button actions route through a single BUTTON_Click(Index) handler. This form does NOT use inventory TC codes (like TC=1 for GRN, TC=2 for issue) because it is a requisition document --- no stock movement occurs. TC codes in this context refer to the toolbar button index values.

+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **This form does not involve TC-based stock or accounting movements.**                                                                                                    |
|                                                                                                                                                                           |
| The Purchase Requisition is a request document only. No stock is deducted, no accounting entries are generated, and no IN_TRNTAIL or GL records are written by this form. |
|                                                                                                                                                                           |
| Stock TC codes (1=GRN receipt, 2=issue, etc.) are READ by stkchk1/stkchk2 to compute current stock for display --- but no new TC-coded transactions are created.          |
|                                                                                                                                                                           |
| Accounting and stock entries are triggered only by downstream screens: PO creation, GRN receipt, and invoice processing.                                                  |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **TC Index (BUTTON\[n\])**   **Button Label**     **Keyboard Shortcut**   **Active When?**            **What It Triggers**
  ---------------------------- -------------------- ----------------------- --------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  0                            Add                  Ctrl+A                  Always (if ADD right)       Pre-add checks × 3; opens blank form; begins DB transaction; IndType(); bindcontls(); adddelmod()

  1                            Modify               Ctrl+M                  Always (if MOD right)       adddelmod(); opens PR Listing filtered to unapproved+non-cancelled+non-amended; ENABLCONTLS(); bindcontls()

  2                            Delete               Ctrl+D                  Always (if DEL right)       adddelmod(); opens PR Listing; shows deletion-type radio buttons (full PR vs. line); Save deletes from PO_PRH + PO_PRL

  3                            Find                 Ctrl+F                  Always                      Opens PR Listing for read-only view; loads PR in query mode; shows approval status label

  4                            List                 Ctrl+L                  Always                      Loads all PRs for division+year; opens LookUp form

  5                            First Record         Ctrl+Left               Query mode with records     adoPrimaryRS.MoveFirst; FIR(BUTTON); bindcontls(); stbar: \'First Record\'

  6                            Next Record          Ctrl+Down               Query mode                  adoPrimaryRS.MoveNext; disables Next/Last at EOF; bindcontls()

  7                            Previous Record      Ctrl+Up                 Query mode                  adoPrimaryRS.MovePrevious; disables Prev/First at BOF; bindcontls()

  8                            Last Record          Ctrl+Right              Query mode                  adoPrimaryRS.MoveLast; las(BUTTON); bindcontls(); stbar: \'Last Record\'

  9                            Save                 Ctrl+S                  Add or Modify mode          Runs all validations; newdocno() or IndentNoChk(); INSERT po_prh; DELETE+INSERT po_prl; INSERT LogDet_po; CommitTrans; UPDATE PO_PAH (if prano\>0); shows PR number confirmation

  10                           Cancel               Ctrl+Back               Add or Modify mode          Rolls back DB transaction; EmptyTextBox(); disablcontls(); cancl(BUTTON, GSNO); returns to Query mode

  11                           Exit                 Ctrl+Q                  Always                      Closes form; releases DB connections

  12                           Footer (FooterCmd)   ---                     Print flow                  Opens UserFooter1 control for custom signature/footer selection before printing

  13                           Print                Ctrl+Y                  Query/Find with loaded PR   Padr() for dept name; instantiates Cry_PR_KSL or Cry_Purchase_Req based on EmpCommon; passes \@divcode, \@prdate, \@prno to Crystal Reports; opens print preview
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Security Rule**                        **Detail**
  ---------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------
  User-level permissions                   NEWFORM() reads USERLEVEL table: ADD_FLG, MOD_FLG, DEL_FLG. If no row found, all three default to Enabled (permissive fallback --- migration risk).

  Financial year boundary                  When CurrYear=False (previous year), Add/Modify/Delete are disabled regardless of USERLEVEL.

  PurTypeFlg=1 purchase type segregation   All Modify/Delete/Find queries filter by user\'s allowed purchase types via tempPurType\[LocalIPAddress\] session table.
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 7. Common / Class Module Dependencies

Every function and subroutine from Po_gmdl.bas (Common module) and form-local procedures in tmpPoindent.frm that this screen calls. Grouped by category.

## 7.1 Toolbar / Button-State Managers (Po_gmdl.bas)

Five procedures implement the TC framework\'s safe state machine --- ensuring Save is never available in query mode and navigation buttons grey out at record boundaries.

+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **NEWFORM(tol, SNO)** *\[Po_gmdl.bas\]*                                                                                                                                                                                              |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Sets every toolbar button\'s Enabled state based on the current user\'s Add/Modify/Delete rights from the USERLEVEL table (module 4, current division). Called on form load and after Cancel.     |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | tol = BUTTON() array from the form; SNO = screen serial number (GSNO). Opens its own DB connection.                                                                                               |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Side-effect: enables/disables BUTTON(0)--BUTTON(11) based on ADD_FLG, MOD_FLG, DEL_FLG. If USERLEVEL row is absent, falls through to permissive default (all Add/Modify/Delete enabled).          |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Security gap: missing USERLEVEL row enables all operations. Migration must enforce a deny-by-default policy.                                                                                      |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **adddelmod(tol)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                 |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Switches toolbar into \'edit in progress\' mode: disables Add, Modify, Delete, Find, List, all navigation. Enables Save, Cancel. Also disables Exit --- user cannot close window mid-transaction. |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | tol = BUTTON() array.                                                                                                                                                                             |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | BUTTON(9) Save = Enabled; BUTTON(10) Cancel = Enabled; all others including Exit = Disabled.                                                                                                      |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | No business rules --- purely UI state. Called at start of every Add, Modify, Delete operation.                                                                                                    |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **cancl(tol, SNO)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Restores correct toolbar states after Cancel. Re-reads USERLEVEL to get user\'s actual rights, then re-enables appropriate buttons. Subtly different from NEWFORM: always leaves Cancel enabled.  |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | tol = BUTTON() array; SNO = screen serial number.                                                                                                                                                 |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Re-applies Add/Modify/Delete rights; always enables navigation, List, Cancel; always disables Save.                                                                                               |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | No business rules --- purely UI state restoration.                                                                                                                                                |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **las(tol)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                       |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Called when navigating to Last record. Disables Next and Last (no further forward); enables First and Previous.                                                                                   |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | tol = BUTTON() array.                                                                                                                                                                             |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | BUTTON(6) Next = Disabled; BUTTON(8) Last = Disabled; BUTTON(5) First = Enabled; BUTTON(7) Prev = Enabled.                                                                                        |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | No business rules --- navigation state only.                                                                                                                                                      |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **FIR(tol)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                       |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Called when navigating to First record. Disables First and Previous (cannot go further back); enables Next and Last.                                                                              |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | tol = BUTTON() array.                                                                                                                                                                             |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | BUTTON(5) First = Disabled; BUTTON(7) Prev = Disabled; BUTTON(6) Next = Enabled; BUTTON(8) Last = Enabled.                                                                                        |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | No business rules --- navigation state only.                                                                                                                                                      |
+----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## 7.2 Pre-Condition and Existence Checker (Po_gmdl.bas)

+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Record_Exists(tname, NMessage, Emessage)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                                                                                     |
+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | General-purpose pre-condition gate. Executes SELECT COUNT(\*) on any table expression passed to it. Two modes: (a) NMessage --- shows message and returns False if count = 0 (record doesn\'t exist); (b) Emessage --- shows message and returns False if count \> 0 (record shouldn\'t exist). |
+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | tname = table name or full WHERE clause. NMessage = message shown if 0 rows. Emessage = message if \> 0 rows. Opens its own connection.                                                                                                                                                         |
+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Returns Boolean. False causes the calling TC handler to Exit Sub. Used 5 times by this form.                                                                                                                                                                                                    |
+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Called for: IN_ITEM populated check, IN_DEP populated check, PO_DOC_PARA PR entry check, PO_PRH year records check (before navigation), PO_PRH unapproved records check (before Modify/Delete).                                                                                                 |
+----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## 7.3 Keyboard-Level Input Filters (Po_gmdl.bas)

Called from KeyPress events. Enforce data type, character set, and field length at point of entry by setting KeyAscii = 0 to suppress disallowed keystrokes.

+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **ToAlphanumNoSp(obj, maxlen, KeyAscii)** *\[Po_gmdl.bas\]*                                                                                                                                                                                           |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Allows uppercase A--Z, lowercase a--z, digits 0--9, and space. Blocks all other characters. Blocks further input once field reaches maxlen.                                                                        |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | obj = text box; maxlen = max length; KeyAscii = key code (modified by reference --- set to 0 to suppress).                                                                                                         |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets KeyAscii = 0 for disallowed keystrokes.                                                                                                                                                                       |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Item Code: maxlen=10. Machine Code: maxlen=5. This is the primary client-side enforcement for these two critical fields.                                                                                           |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **ToNumber(obj, maxlen, KeyAscii)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                 |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Restricts to digits 0--9 only. Allows Backspace, Tab, Enter. Blocks all other keys.                                                                                                                                |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | Same signature.                                                                                                                                                                                                    |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets KeyAscii = 0 for non-numeric keys.                                                                                                                                                                            |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Requester Code: maxlen=6. Sub-Cost Centre: maxlen=3 (LEGACY --- Sub-Cost Centre removed from SPINRISE rendering per F-05; this filter is retained for documentation of legacy VB6 behaviour only).                 |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **ToNum(obj, maxlen, KeyAscii, ary)** *\[Po_gmdl.bas\]*                                                                                                                                                                                               |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Decimal-aware numeric filter. Allows digits, one decimal point, Backspace, Tab, Enter. Blocks a second decimal point. Once fractional part reaches \'ary\' decimal places, further digits are blocked with a Beep. |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | ary (optional) = decimal places to enforce.                                                                                                                                                                        |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets KeyAscii = 0; may Beep for invalid input.                                                                                                                                                                     |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Quantity Required: maxlen=9, ary=3 (enforces 3dp). Approx. Cost: ary=2. Rate: ary=2.                                                                                                                               |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **ToUpCase(Ofld, KeyAscii)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                        |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Converts lowercase keystrokes (a--z, ASCII 97--122) to uppercase (A--Z) in real time as user types.                                                                                                                |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | KeyAscii = key code (modified by reference).                                                                                                                                                                       |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Decrements KeyAscii by 32 for lowercase letters.                                                                                                                                                                   |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Used on Reference Number and Remarks fields. Ensures uppercase storage.                                                                                                                                            |
+----------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## 7.4 Stock Calculation Functions (Po_gmdl.bas)

The most complex functions in the module. Each executes a large UNION-based SQL query across IN_IDET and IN_TRNTAIL.

+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **stkchk1(itm, db1, G)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                                                                                                        |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Computes current balance stock for one item using full transaction trail: UNION of year-opening balance (IN_IDET TC=0), all receipts (TC types 1,3,5,7,9,12 from IN_TRNTAIL), all issues (TC types 2,4,6,8,11) up to processing date. If Purstock global is set, filters to a specific godown. |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | itm = item code; db1 = open ADO connection; G = godown code (blank = use first godown from IN_GODOWN).                                                                                                                                                                                         |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets globals: curstk (balance qty), cval (balance value), Cut (UOM). Read by stock_find().                                                                                                                                                                                                     |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | TC type 12 (transfer-in) treated as receipt. TC 11 (transfer-out) as issue. Date range: year-start to pdate (today).                                                                                                                                                                           |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **stkchk2(itm, db1, G)** *\[Po_gmdl.bas\]*                                                                                                                                                                                                                                                                                        |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Almost identical to stkchk1 but date range extends to year-end (yldate) and TC type 12 is excluded from receipts. Writes to separate globals curstk1, cval1, cut1.                                                                                                                             |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | Same signature as stkchk1.                                                                                                                                                                                                                                                                     |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets globals: curstk1 (year-end balance), cval1, cut1.                                                                                                                                                                                                                                         |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Gives projected full-year stock vs. stkchk1\'s today stock. The form displays min(curstk, curstk1) --- the conservative minimum.                                                                                                                                                               |
+----------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

+----------------------------------------------------------------------------------------------------+
| **Stock Calculation Formula**                                                                      |
|                                                                                                    |
| Balance Qty = Opening Stock (IN_IDET, TC=0, yearmonth = year \'00\')                               |
|                                                                                                    |
| \+ Sum of all Receipt TC types (from IN_TRNTAIL up to cut-off date)                                |
|                                                                                                    |
| \- Sum of all Issue TC types (from IN_TRNTAIL up to cut-off date)                                  |
|                                                                                                    |
| Displayed Current Stock = min( stkchk1 result \[up to today\], stkchk2 result \[up to year-end\] ) |
|                                                                                                    |
| Receipt TC types (stkchk1): 1, 3, 5, 7, 9, 12 (transfer-in)                                        |
|                                                                                                    |
| Receipt TC types (stkchk2): 1, 3, 5, 7, 9 (no transfer-in)                                         |
|                                                                                                    |
| Issue TC types (both): 2, 4, 6, 8, 10, 11 (transfer-out)                                           |
+----------------------------------------------------------------------------------------------------+

## 7.5 String and Formatting Utilities (Po_gmdl.bas)

+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Padr(TStr, Tlen, Tchar)** *\[Po_gmdl.bas\]*                                                                                                                                         |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                   | Right-pads a string to exactly Tlen characters using Tchar. If longer than Tlen, truncates.                                                      |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**               | TStr = string (handles Null); Tlen = target length; Tchar = padding character.                                                                   |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**              | Returns padded/truncated string.                                                                                                                 |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**        | Form calls: GNAME = Padr(Text4.Text, 25, \' \') before Crystal Reports formula. Dept names \> 25 chars are silently truncated on the printed PR. |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **SetSpreadCol1(spd, Col, head, celltype, \...)** *\[Po_gmdl.bas\]*                                                                                                                   |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                   | Configures one column of an FpSpread grid: header text, cell type, width, hidden flag, lock flag, decimal places.                                |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**               | spd = FpSpread control; Col = column index; celltype = CellTypeConstants enum.                                                                   |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**              | Modifies visual properties of the spread column.                                                                                                 |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**        | Used by SetSpdIndentHead() to build the item lookup popup grid. Pure UI configuration.                                                           |
+------------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------+

## 7.6 Form-Local Procedures (tmpPoindent.frm)

Procedures defined inside the form module that encapsulate cohesive business logic.

+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **newdocno()** *\[Form-local\]*                                                                                                                                                                                                 |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Generates the next PR number. Reads PO_DOC_PARA for STDOCNO (year starting number), then reads MAX(PRNO) from PO_PRH for current division+year. Returns MAX+1, or STDOCNO if no PRs exist.   |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Uses globals: db, divcode, yfdate, yldate.                                                                                                                                        |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Returns next PR number string. Returns empty string + error message if PO_DOC_PARA has no PR entry.                                                                                          |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | NOT ATOMIC --- concurrent users reading same MAX will generate duplicate numbers. Must be replaced with DB sequence in web migration.                                                        |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **IndentNoChk()** *\[Form-local\]*                                                                                                                                                                                              |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Manual PR number duplicate check. Runs only when ManualIndNo=\'Y\'. Queries PO_PRH COUNT for the manually entered number in current year.                                                    |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Reads txtfields(2).Text and globals.                                                                                                                                              |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | If duplicate found: shows \'PR. number already Exist\'; sets focus back to number field.                                                                                                     |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Exits silently without any check if ManualIndNo \<\> \'Y\'.                                                                                                                                  |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **stock_find()** *\[Form-local\]*                                                                                                                                                                                               |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Orchestrates stock display. Calls stkchk1 then stkchk2. Applies conservative minimum rule: displays the lower of curstk and curstk1. Updates CurrentQtyLabel and Text8.                      |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Reads ItemCodeTextBox.Text.                                                                                                                                                       |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets Text8.Text = min(curstk, curstk1) formatted \'#.000\'. Sets CurrentQtyLabel.Caption = \'Current Qty: \[value\]\'.                                                                       |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Special case: if curstk == curstk1, uses curstk. The conservative minimum protects against raising PRs for stock not yet available.                                                          |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Rate_Find()** *\[Form-local\]*                                                                                                                                                                                                |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Retrieves last purchase receipt rate for the item from IN_TRNTAIL INNER JOIN IN_TRNHEAD, TC=1 (GRN), ordered by DOCDT descending, TOP 1. Populates RateTextBox.                              |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Reads ItemCodeTextBox.Text and divcode.                                                                                                                                           |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Sets RateTextBox.Text = last receipt rate formatted \'#####0.00\'. Blank if no GRN history.                                                                                                  |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Rate is from GRN (actual receipt), NOT from PO. GRN rate may differ from PO rate if price amendments occurred. This rate is stored in PO_PRL.RATE.                                           |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **IndType()** *\[Form-local\]*                                                                                                                                                                                                  |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Loads PR Type dropdown (Combo2) from PO_INDENTTYPE. In Add/Modify mode: only Active types. In Query mode: all types (so old PRs display correctly).                                          |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Uses global db.                                                                                                                                                                   |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Clears and repopulates Combo2 with \'ITYPE\--IDESC\' entries. If table empty: \'No PR. Type in Setup Form\'.                                                                                 |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Business rule: only active types selectable on new PRs; historical types visible in query mode.                                                                                              |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **bindcontls()** *\[Form-local\]*                                                                                                                                                                                               |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Binds all header text boxes to current adoPrimaryRS record. Also resolves requester name (PR_EMP), scope type name (PO_SCOPETYPE), and indent type description (PO_INDENTTYPE).              |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Uses adoPrimaryRS, db, divcode, EmpCommon.                                                                                                                                        |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | All header display fields populated from current record. Special: reqname=\'AG\' shows \'AUTO GENERATED PR.\' in Text4.                                                                      |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | EmpCommon=True: PR_EMP lookup without division filter (company-wide). EmpCommon=False: filtered by divcode.                                                                                  |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **disablcontls()** *\[Form-local\]*                                                                                                                                                                                             |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Locks all input controls for read-only mode. Called when switching to Query mode or on Cancel.                                                                                               |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params.                                                                                                                                                                                   |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Locks all txtfields, Text2, Text3, Text4, Text7; disables MaskEdBox1; grddatagrid.AllowAddNew/AllowUpdate = False.                                                                           |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | Pure UI state.                                                                                                                                                                               |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **ENABLCONTLS()** *\[Form-local\]*                                                                                                                                                                                              |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Unlocks all input controls for editing. Sets DTPicker1.MaxDate = pdate preventing future date selection.                                                                                     |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Uses global pdate.                                                                                                                                                                |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Unlocks all txtfields; enables MaskEdBox1 and DTPicker1; grddatagrid.AllowUpdate = True.                                                                                                     |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | DTPicker1.MaxDate = pdate is the calendar enforcement of the \'PR Date must equal processing date\' rule.                                                                                    |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **qry1()** *\[Form-local\]*                                                                                                                                                                                                     |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **What it does**                 | Builds the hierarchical ADO SHAPE recordset for Query mode: parent = PO_PRH joined to IN_DEP; child = PO_PRL joined to IN_ITEM, MM_MACMAS, PO_PRH. Child includes inline CASE for PR Status. |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Inputs from form**             | No params. Uses globals: db, divcode, pdate, yfdate, yldate.                                                                                                                                 |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Returns / Changes**            | Populates adoPrimaryRS with hierarchical recordset. Sets SSTab1.Height = 7500.                                                                                                               |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Business rules enforced**      | PR Status CASE logic: 10 conditions mapped to English labels (see Section 5.5). amdflg \<\> \'Y\' filter excludes amended lines from display.                                                |
+----------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## 7.7 Crystal Reports Class Modules

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Class**          **Used When**                                  **Parameters Passed**                                                    **Data Source**
  ------------------ ---------------------------------------------- ------------------------------------------------------------------------ -----------------------------------------------------------
  Cry_PR_KSL         EmpCommon = False (standard customers)         \@divcode, \@prdate, \@prno; formula NAME = Padr(dept name, 25)          ksl_Tran_PORequisition stored procedure --- 10-table join

  Cry_Purchase_Req   EmpCommon = True (employee-linked customers)   \@divcode, \@Docno, \@Docdt; formula IndUserNAME = logged-in user name   Alternative parameter set; same procedure family
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Confirmed Division Assignment (as at April 2026)**

The following five divisions have PO_Para.EmpMasterComm = 'Y' and therefore use Cry_Purchase_Req: Saranya, Armstrong, Cheran, Skaat, VTS. All other active divisions carry EmpMasterComm = 'N' or NULL and use Cry_PR_KSL.

+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **SPINRISE Migration Note --- Section 7.7**                                                                                                                                                                                                                                                                                                                                                       |
|                                                                                                                                                                                                                                                                                                                                                                                                   |
| The dual Crystal Reports branching (Cry_PR_KSL vs Cry_Purchase_Req) is replaced in SPINRISE by a single server-side PDF generator. Template selection is controlled by a division-level parameter in PO_Para (EmpMasterComm), which the PDF service reads directly to choose the correct layout template. There are no separate report class modules in the web version.                          |
|                                                                                                                                                                                                                                                                                                                                                                                                   |
| New customer onboarding requirement: PO_Para.EmpMasterComm must be correctly set ('Y' or 'N') for each division before the PR print function will produce a correctly formatted document. A NULL or missing value defaults to EmpCommon = False (Cry_PR_KSL path). Onboarding teams must verify this setting during division setup and confirm the correct print template renders before go-live. |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## 7.8 Call Dependency Map

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Form Operation**       **Functions Called (in order)**
  ------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Form Load                NEWFORM(BUTTON,GSNO), bindcontls(), IndType(), qry1(), LookupItemgrpwise()

  Add (TC 0)               Record_Exists ×3, ENABLCONTLS(), IndType(), bindcontls(), adddelmod(BUTTON)

  Modify (TC 1)            Record_Exists, adddelmod(BUTTON), ENABLCONTLS(), bindcontls(), IndType()

  Delete (TC 2)            Record_Exists, adddelmod(BUTTON)

  Save (TC 9) --- Add      newdocno(), IndentNoChk() \[if manual\], bindcontls(), stkchk1, stkchk2 \[per item\], Rate_Find \[per item\], INSERT po_prh, DELETE+INSERT po_prl, INSERT LogDet_po, UPDATE PO_PAH \[if prano\>0\]

  Cancel (TC 10)           EmptyTextBox(), disablcontls(), cancl(BUTTON,GSNO), Query_mode()

  Navigation (TC 5--8)     FIR() or las(), bindcontls(), grdnumall()

  Print (TC 13)            Padr(), CrystalPrint() via Cry_PR_KSL or Cry_Purchase_Req

  Item Code entry          stock_find() → stkchk1() + stkchk2(), Rate_Find(), ToAlphanumNoSp()

  Qty Required key press   ToNum(QtyReqTextBox, 9, KeyAscii, 3)

  Remarks key press        ToUpCase(RemarksTextBox, KeyAscii)

  Dept Code validate       DepLookup() if code not found in IN_DEP

  Machine Code validate    MacLookup() if code not found in MM_MACMAS
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 8. Database Operations --- Tables, Constraints, and Stored Procedures

Part A documents all five table schemas with column-level constraints and business rules enforced at the database tier. Part B analyses both stored procedures line by line. Part C documents critical inline SQL operations in the form code.

## PART A --- Table Schemas and Column Business Rules

**[A.1 PO_PRH --- Purchase Requisition Header]{.underline}**

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Column**                             **Type**             **Null?**   **Default**   **Business Meaning**
  -------------------------------------- -------------------- ----------- ------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  divcode                                varchar(2)           NOT NULL    ---           Division code. Part of 3-column composite primary key. CHECK: non-blank.

  prno                                   numeric(6,0)         NOT NULL    ---           PR number. Part of PK. CHECK: \> 0 and non-blank. Auto-incremented by newdocno().

  prdate                                 datetime             NOT NULL    ---           PR date. Part of PK. CHECK: non-blank. Must equal processing date.

  depcode                                varchar(3)           NULL        ---           Requesting dept code. FK to IN_DEP enforced at app level only.

  refno                                  varchar(20)          NULL        ---           Internal reference. Blank value stored as 0 (not NULL) due to IIF in INSERT SQL.

  planno / plandt                        numeric / datetime   NULL        ---           Link to production plan document number and date.

  APPFLG                                 char(1)              NULL        \'N\'         Overall approval flag. \'N\'=unapproved, \'Y\'=approved. Once \'Y\', PR cannot be modified or deleted.

  ITYPE                                  char(1)              NULL        ---           Purchase type (C=Capital, S=Stores, H=Overhaul). From PO_INDENTTYPE.

  SECTION                                varchar(20)          NULL        ---           Sub-section within the requesting department.

  APP1 / APP2 / APP3                     varchar(10) each     NULL        ---           User IDs of each approval level. Written by downstream approval screens.

  APP1DATE/2/3                           datetime each        NULL        ---           Approval dates. Used in ksl_Tran_PORequisition timestamp calculation.

  APP1TIME/2/3                           datetime each        NULL        ---           Approval times. Combined with dates in SP to produce formatted timestamps.

  REQNAME                                varchar(10)          NULL        ---           Requester employee number (or name on some configs).

  cancelflag / canceldt / canreason      mixed                NULL        ---           Cancel flag, date, and reason. Cancelled PRs excluded from Modify/Delete.

  amendno                                numeric(5,0)         NULL        ---           0 on original PR. Incremented by Amendment screen. PRs with amendno\>0 excluded from Modify/Delete.

  scopecode                              varchar(2)           NULL        ---           Scope of purchase from PO_SCOPETYPE. SPINRISE AMENDMENT (F-05): DB column RETAINED for legacy data compatibility. Field removed from SPINRISE rendering. PO_SCOPETYPE confirmed unpopulated across all live customer databases. F-05 CLOSED.

  alert_raised                           varchar(1)           NULL        \'N\'         SMS/email alert sent flag. Default \'N\'.

  userId                                 varchar(50)          NULL        ---           Login user ID of PR creator.

  SubCost                                numeric(5,0)         NULL        ---           Sub-cost centre code at header level. SPINRISE AMENDMENT (F-05): DB column RETAINED for legacy data compatibility. Sub-Cost Centre field removed from SPINRISE rendering. F-05 CLOSED.

  budgetBALAMT                           numeric(18,2)        NULL        ---           Budget balance at time of PR creation. Active when BudgetQty=\'Y\'.

  PO_GRP                                 varchar(5)           NULL        ---           Purchase Order Group/Type. Filters Modify/Delete/Find when PurTypeFlg=1.

  saleorderno / Saleorderdt / saletype   mixed                NULL        ---           Sales order reference for customers who link PRs to sales orders.

  createdby                              varchar(50)          NULL        ---           Login user ID of creator. Written from session variable usrid.

  createddt                              varchar(25)          NULL        ---           Creation datetime as VARCHAR string \'DD/MM/YYYY HH:MM:SS AM/PM\'. NOT a datetime column --- date arithmetic will fail.
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

+-------------------------------------------------------------------------------------------------------------------------------------------------+
| **PO_PRH --- Constraints**                                                                                                                      |
|                                                                                                                                                 |
| PRIMARY KEY (NONCLUSTERED): divcode + prno + prdate --- PR numbers are DATE-SCOPED (same number can exist on different dates in same division). |
|                                                                                                                                                 |
| CHECK CK_PO_PRH: LEN(RTRIM(DIVCODE)) \> 0                                                                                                       |
|                                                                                                                                                 |
| CHECK CK_PO_PRH_1: LEN(RTRIM(PRNO)) \> 0                                                                                                        |
|                                                                                                                                                 |
| CHECK CK_PO_PRH_2: PRNO \> 0                                                                                                                    |
|                                                                                                                                                 |
| CHECK CK_PO_PRH_3: LEN(RTRIM(PRDATE)) \> 0                                                                                                      |
|                                                                                                                                                 |
| DEFAULT APPFLG = \'N\'; DEFAULT alert_raised = \'N\'                                                                                            |
|                                                                                                                                                 |
| WARNING: All CHECK constraints defined WITH NOCHECK --- not enforced on existing rows. Legacy dirty data may exist.                             |
+-------------------------------------------------------------------------------------------------------------------------------------------------+

**[A.2 PO_PRL --- Purchase Requisition Line]{.underline}**

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Column**                                             **Type**           **Null?**   **Default**   **Business Meaning**
  ------------------------------------------------------ ------------------ ----------- ------------- -----------------------------------------------------------------------------------------------------------
  divcode+prno+prdate                                    composite FK       NOT NULL    ---           FK to PO_PRH. NOTE: FK is DISABLED (NOCHECK) --- orphaned lines are possible.

  prsno                                                  numeric(5,0)       NOT NULL    ---           Line serial number. 4th column of composite PK. Reassigned from 1 on every Modify save.

  itemcode                                               varchar(10)        NOT NULL    ---           Item code. ONLY HARD-ENFORCED FK: REFERENCES IN_ITEM(ITEMCODE). Invalid item codes rejected by DB engine.

  macno                                                  varchar(5)         NULL        ---           Machine number. Validated at app level (MM_MACMAS + dept + macflag=\'M\').

  qtyind                                                 numeric(12,3)      NULL        ---           Quantity requested. Must be \> 0 and \>= item MINLEVEL.

  qtyreqd                                                numeric(12,3)      NULL        ---           Quantity approved by first-level approver. Written by approval screen, not this form.

  qtyord                                                 numeric(12,3)      NULL        ---           Quantity converted to PO. Written by PO creation screen.

  qtyrec                                                 numeric(12,3)      NULL        ---           Quantity received (GRN). Written by GRN screen.

  reqddate                                               datetime           NULL        ---           Required date. Optional; validated against processing date and PR date.

  prstatus                                               char(1)            NULL        ---           NULL=Requested, O=Ordered, E=Enquired, C=Received. Controlled by downstream screens.

  remarks                                                varchar(50)        NULL        ---           Remarks. NOTE: form allows 100 chars but DB is varchar(50) --- chars 51--100 silently truncated.

  CCCODE                                                 numeric(4,0)       NULL        ---           Cost Centre code. App-validated against IN_CC.

  CATCODE                                                varchar(1)         NULL        ---           Category code. App-validated against IN_CAT.

  RATE                                                   numeric(13,4)      NULL        ---           Last GRN receipt rate. Auto-fetched by Rate_Find() from IN_TRNTAIL.

  PLACE                                                  varchar(40)        NULL        ---           Place/delivery location. Max 40 chars.

  APPCOST                                                numeric(11,2)      NULL        ---           Approximate cost. Informational only.

  BGRPCODE                                               varchar(4)         NULL        ---           Budget Group. App-validated against IN_BGRP.

  curstock                                               numeric(12,3)      NULL        ---           Stock at PR creation time (conservative minimum). Stored for historical reference.

  LPO_RATE / LPO_DATE / PUR_FROM                         mixed              NULL        ---           Last PO rate, date, and supplier. Auto-fetched from PO order history.

  AmdFlg                                                 char(1)            NULL        ---           \'Y\' marks line as superseded by amendment. Excluded from all query views.

  DirectApp / DirectAppDate                              char+datetime      NULL        NULL          President-level direct approval. Bypasses 3-level chain.

  Depcode                                                varchar(3)         NULL        ---           Department code denormalised at line level for reporting.

  FirstApp/SecondApp/ThirdApp                            char(1) each       NULL        ---           \'Y\' flags set by each approval level.

  FirstAppQty/SecondAppQty/ThirdAppQty                   numeric(12,3)      NULL        0             Quantities approved at each level. Default 0.

  FirstappUser/SecondAppUser/ThirdAppUser/FinalAppUser   varchar(35) each   NULL        ---           Approver display names. Used on printed PR document.

  Sample                                                 char(1)            NULL        ---           \'Y\' = sample/trial request.

  SubCost                                                numeric(5,0)       NULL        ---           Sub-cost centre at line level (copied from header value at save time).

  FClosed / FCloseddt                                    char+datetime      NULL        ---           Force-closed flag and date. FClosed=\'Y\' lines excluded by KSP_INDEDNT_CHECK.

  deletereason                                           varchar(100)       NULL        ---           Reason recorded when line is deleted.
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

+-------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **PO_PRL --- Critical Constraints and Risks**                                                                                                               |
|                                                                                                                                                             |
| PRIMARY KEY (NONCLUSTERED): divcode + prno + prdate + prsno                                                                                                 |
|                                                                                                                                                             |
| FK FK_PO_PRL_IN_ITEM → IN_ITEM(ITEMCODE): ENFORCED. Invalid item codes rejected at DB level.                                                                |
|                                                                                                                                                             |
| FK FK_PO_PRL_PO_PRH → PO_PRH(divcode,prno,prdate): DISABLED (NOCHECK). Orphaned lines possible.                                                             |
|                                                                                                                                                             |
| DEFAULT divcode = \'02\' --- hardcoded legacy value. Meaningless in multi-division environments.                                                            |
|                                                                                                                                                             |
| DEFAULT FirstAppQty = SecondAppQty = ThirdAppQty = 0                                                                                                        |
|                                                                                                                                                             |
| All CHECK constraints NOCHECK\'d --- not enforced on existing data.                                                                                         |
|                                                                                                                                                             |
| RISK: Delete-and-reinsert on Modify destroys all approval workflow data (FirstApp, SecondApp flags, approver names) previously written by approval screens. |
+-------------------------------------------------------------------------------------------------------------------------------------------------------------+

**[A.3 LogDet_po --- Audit Trail (append-only, no primary key)]{.underline}**

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Column Group**                                                                            **Purpose for This Form**
  ------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------
  PR Identity: divcode, prno, prdate, prsno                                                   Links audit row to specific PR line. pordno/porddt blank for PR entries.

  Transaction data: itemcode, macno, quantity, RATE                                           Snapshot of line data at transaction time.

  Audit: Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD, Trans_UserId, Trans_date, moduleNo   This form writes: Trans_Name=\'Purchase Requisition\', Trans_Mod=\'ADD\'/\'MODIFY\', moduleNo=4, plus IP and hostname.

  User: reqname, createdby, username                                                          Creator identity chain captured at save time.

  NOTE: Quantity column is numeric(15,0) --- INTEGER                                          Decimal requisition quantities are TRUNCATED in the audit log.

  NOTE: Shared table                                                                          Used by all Purchase module screens (PR, PO, GRN). Trans_Name distinguishes source.
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[A.4 PO_PAH --- Purchase Advice Header]{.underline}**

Pre-authorisation document. prno column starts NULL; this form writes the new PR number to it after CommitTrans. IMPORTANT: this UPDATE runs outside the transaction --- if it fails, the PR is saved but the advice-to-PR link is lost.

**[A.5 PO_PARA --- Purchase Module Parameters (columns relevant to this form)]{.underline}**

  ---------------------------------------------------------------------------------------------------------------------------------------------------------
  **Column**                      **Default**   **Effect on This Form**
  ------------------------------- ------------- -----------------------------------------------------------------------------------------------------------
  Manual_IndNo                    ---           \'Y\' = user enters PR number manually; IndentNoChk() runs duplicate check. \'N\' = auto-generated.

  BudgetQty                       \'N\'         \'Y\' = Sub-Cost Centre label highlighted red; budget balance field activated.

  PendingOrderPara                ---           \'Y\' = KSP_INDEDNT_CHECK called on every item code entry.

  Penpodetails                    ---           \'Y\' = Item lookup popup enriched with pending qty, lead time, supplier.

  InditemGrp                      ---           \'Y\' = item lookup filters by item group code (bolLookupItemgrpwise = True).

  purtypeflg                      ---           Numeric \> 0 = PurTypeFlg=1; Order Type becomes mandatory; all lookups filtered by user\'s allowed types.

  Pr_ILevel / Pr_FLevel           \'N\'         PR approval level configuration --- used by approval screens downstream.

  PRSMSSendFlg / PRSMSStatusFlg   \'Y\'         Controls SMS alerts when PR is created or status changes.

  EmpMasterComm                   ---           \'Y\' = EmpCommon=True: employee lookups and Crystal Reports use company-wide (non-division) path.

  PDFExportFlag                   ---           Whether printed PR document is exported as PDF.
  ---------------------------------------------------------------------------------------------------------------------------------------------------------

## PART B --- Stored Procedure Analysis

**[B.1 KSP_INDEDNT_CHECK --- Pending Purchase Order Check]{.underline}**

Signature: KSP_INDEDNT_CHECK(@DIVCODE, \@FDATE, \@TDATE, \@DEPCODE, \@ITEMCODE). READ-ONLY. No data modification.

Purpose: Determine whether an active, unfulfilled Purchase Order already exists for the same item and department within the financial year, before the user raises a new PR.

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Business Rule**   **SQL Clause**                                   **Rule Description**                                                                                 **Effect if Fires**
  ------------------- ------------------------------------------------ ---------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------
  BR-1                ISNULL(H.CANFLG,\'N\') = \'N\'                   Only active, non-cancelled POs counted. Cancelled POs do not count as pending.                       Cancelled POs excluded --- prevents false warnings.

  BR-2                ISNULL(T.FClosed,\'N\') \<\> \'Y\'               Only open lines counted. Force-closed lines excluded.                                                Administratively closed lines excluded --- prevents stale warnings.

  BR-3                t.DepCode = \@DEPCODE                            Check is department-specific. Pending PO for same item in different dept does not trigger warning.   Cross-department PRs for same item are allowed.

  BR-4                t.ITEMCODE = \@ITEMCODE                          Exact item code match only. No wildcard or group-level checking.                                     Each item checked independently.

  BR-5                t.PRDATE BETWEEN \@FDATE AND \@TDATE             Only PO lines within current financial year. Prior year lines ignored.                               Year-scoped --- old unresolved POs don\'t trigger warning in new year.

  BR-6 (HAVING)       SUM(ISNULL(ORDQTY,0) - ISNULL(RCVDQTY,0)) \> 0   Core rule: row returned ONLY IF pending qty \> 0. Fully received POs return no row.                  Empty result = no warning. Non-empty result = warning shown.
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

+----------------------------------------------------------------------------------------------------------------+
| **Pending Quantity Formula**                                                                                   |
|                                                                                                                |
| pendingOrdQty = SUM( ISNULL(ORDQTY, 0) -- ISNULL(RCVDQTY, 0) )                                                 |
|                                                                                                                |
| ORDQTY = quantity placed on PO (PO_ORDL)                                                                       |
|                                                                                                                |
| RCVDQTY = quantity received via GRN (PO_ORDL, updated by GRN screen)                                           |
|                                                                                                                |
| ISNULL(\...,0) protects against NULLs --- no-receipt lines treated as 0 received                               |
|                                                                                                                |
| HAVING \> 0 filters out fully received or over-received groups                                                 |
|                                                                                                                |
| Join: PO_ORDH INNER JOIN PO_ORDL on DIVCODE + PORDNO + PORDDT                                                  |
|                                                                                                                |
| Rule: a PO line is only counted if it has a valid, matching header. Orphaned lines are automatically excluded. |
+----------------------------------------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Migration Notes for KSP_INDEDNT_CHECK**                                                                                                               |
|                                                                                                                                                         |
| \@FDATE VARCHAR(15) and \@TDATE VARCHAR(25) --- inconsistent sizes; should be strongly typed DATE parameters in web API.                                |
|                                                                                                                                                         |
| Procedure returns only total pending qty --- does not identify which PO. Web version should return PO number, date, and outstanding qty for drill-down. |
|                                                                                                                                                         |
| Application response (calling End to terminate the app) must be redesigned as a dismissable modal warning.                                              |
+---------------------------------------------------------------------------------------------------------------------------------------------------------+

**[B.2 ksl_Tran_PORequisition --- PR Print Data Retrieval]{.underline}**

Signature: ksl_Tran_PORequisition(@divcode VARCHAR(2), \@prdate VARCHAR(12), \@prno VARCHAR(10)). READ-ONLY. Called by Cry_PR_KSL Crystal Reports class when EmpCommon=False.

Architecture: inner subquery (\'x\') performs all multi-table joins and date calculations; outer SELECT adds a second PP_DIVMAS join to fetch DIV_LOGO separately (avoids polluting the inner GROUP BY).

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Join \#**   **Tables**                          **Type**     **Business Rule Enforced**
  ------------- ----------------------------------- ------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  J-1           PO_PRH INNER JOIN PO_PRL            INNER JOIN   Core join: only PRs with at least one line are printable. Keys: divcode + prno + prdate.

  J-2           PO_PRH LEFT JOIN PR_EMP             LEFT JOIN    Resolves requester employee name. Condition: emp.divcode=PO_PRH.divcode AND PO_PRH.reqname=CAST(emp.empno AS varchar). LEFT JOIN: document prints without name if employee deleted. CAST needed because reqname is varchar but empno is numeric.

  J-3           PO_PRH LEFT JOIN PP_PASSWD          LEFT JOIN    Resolves created-by user display name. Filter: module=4 AND divcode match. LEFT JOIN: document prints even if user\'s login deleted.

  J-4           PO_PRH LEFT JOIN IN_DEP             LEFT JOIN    Resolves department name. LEFT JOIN: prints even if dept deleted after PR creation.

  J-5           PO_PRL LEFT JOIN MM_MACMAS          LEFT JOIN    Retrieves MODEL, MacMake, MacSerialNo. Three-condition join: divcode + macno + DEPCODE. PLUS macflag=\'M\'. CRITICAL: only \'M\' type (Main) machines matched --- non-M type machines show blank details on print.

  J-6           PO_PRL LEFT JOIN IN_ITEM            LEFT JOIN    Retrieves ITEMCODE, ITEMNAME, UOM, CATLNO, DRAWNO. LEFT JOIN: prints with blank item details if item deleted.

  J-7           PO_PRL LEFT JOIN PP_DIVMAS          LEFT JOIN    Retrieves division letterhead: name, address, phone, email, state, print name, unit name.

  J-8 (outer)   Subquery x LEFT JOIN PP_DIVMAS pd   LEFT JOIN    Fetches only DIV_LOGO (binary image). Separate join keeps logo out of the inner GROUP BY.
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Calculation**             **SQL Expression**                                                                                          **Business Purpose**
  --------------------------- ----------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  First Approval Timestamp    DATEADD(dd,0,DATEDIFF(dd,0,APP1DATE)) + \'\' + CONVERT(VARCHAR, APP1TIME, 108) → \'firstappdate\'           Combines date-only portion of APP1DATE with time (HH:MM:SS) from APP1TIME into a single display string. Necessary because date and time are stored in separate columns.

  Second Approval Timestamp   Same pattern: APP2DATE + APP2TIME → \'secondappdate\'                                                       Second approval level timestamp (e.g. Store Verification).

  Final Approval Timestamp    Same pattern: APP3DATE + APP3TIME → \'finalappdate\'                                                        Third/final approval level (e.g. GM/AGM Approval).

  President Approval          po_prl.directappdate AS PresidentAppdate                                                                    Direct/President-level approval stored as single datetime in PO_PRL --- no time combining needed.

  Hardcoded labels            \'Verified by - Store\' as f2, \'Approved by - GM/AGM\' as f3, \'Authorised Signatory - President\' as f4   Signature line labels on printed PR. NOT driven by PO_PARA.AppUserLabel1/2/3 --- hardcoded in SQL.
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Migration Notes for ksl_Tran_PORequisition**                                                                                                                                         |
|                                                                                                                                                                                        |
| \@prdate VARCHAR(12) and \@prno VARCHAR(10) --- should be strongly typed DATE and INT in web API.                                                                                      |
|                                                                                                                                                                                        |
| Approval timestamp formula (DATEADD+DATEDIFF+CONVERT combining two separate columns) is a workaround for poor schema design. Migrate to single datetime2 columns for APP1-3 date+time. |
|                                                                                                                                                                                        |
| Hardcoded signature labels (\'Verified by - Store\' etc.) must be made configurable via PO_PARA.AppUserLabel1/2/3 in the web version.                                                  |
|                                                                                                                                                                                        |
| macflag=\'M\' filter on MM_MACMAS is undocumented in parameters. Verify against live machine master --- non-M machines will show blank details on printed PR.                          |
|                                                                                                                                                                                        |
| Procedure is structurally reusable in web migration --- call from REST API and pipe result set into PDF template engine.                                                               |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

## PART C --- Critical Inline SQL Business Rules (Form Code)

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Operation**                  **Business Rules Embedded in SQL**
  ------------------------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Save Header INSERT             Amendno=0 and Planno=0 on every new PR. REFNO: IIF(blank, 0, quoted string) --- blank ref stored as integer 0, not NULL. createddt stored as VARCHAR \'DD/MM/YYYY HH:MM:SS AM/PM\'. PO_GRP written from txtfields(7).

  Save Lines DELETE+INSERT       ALL lines deleted then reinserted fresh. PRSNO reassigned from 1. All previous approval data (FirstApp, SecondApp, approver names) DESTROYED on every Modify.

  Modify guard (lookup filter)   WHERE isnull(amdflg,\' \')\<\>\'Y\' AND appflg\<\>\'Y\' AND CANCELFLAG IS NULL AND (amendno IS NULL OR amendno=0). All four conditions must pass --- any one blocks Modify/Delete.

  Document number generation     SELECT MAX(prno) FROM po_prh WHERE divcode=... AND prdate BETWEEN year. NOT ATOMIC --- concurrent users can generate identical PR numbers.

  PO_PAH link update             UPDATE PO_PAH SET PRNO=... WHERE PRANO=... runs AFTER CommitTrans --- outside transaction. Failure orphans the advice-PR link without rolling back the PR.
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| **Summary: Database Design Risks for SPINRISE Migration**                                                                                                                                                       |
|                                                                                                                                                                                                                 |
| RISK 1 (HIGH): FK PO_PRL→PO_PRH is DISABLED. Orphaned lines possible. Delete-and-reinsert widens this window.                                                                                                   |
|                                                                                                                                                                                                                 |
| RISK 2 (HIGH): PR number generation (MAX+1) is not atomic. Must use DB SEQUENCE or IDENTITY in web version.                                                                                                     |
|                                                                                                                                                                                                                 |
| RISK 3 (MEDIUM): Delete-and-reinsert on Modify destroys approval data. Partially approved PRs can be reset. Only full approval (APPFLG=\'Y\') is guarded.                                                       |
|                                                                                                                                                                                                                 |
| RISK 4 (MEDIUM): All CHECK constraints on PO_PRH and PO_PRL are WITH NOCHECK --- legacy dirty data may exist.                                                                                                   |
|                                                                                                                                                                                                                 |
| RISK 5 (MEDIUM): PO_PAH update runs after CommitTrans --- outside transaction. Link failure is silent.                                                                                                          |
|                                                                                                                                                                                                                 |
| RISK 6 (LOW): Default divcode=\'02\' on PO_PRL --- meaningless in multi-division environments.                                                                                                                  |
|                                                                                                                                                                                                                 |
| RISK 7 (LOW): createddt on PO_PRH is VARCHAR(25), not DATETIME --- date arithmetic fails.                                                                                                                       |
|                                                                                                                                                                                                                 |
| RISK 8 (LOW): LogDet_po.Quantity is integer --- decimal requisition quantities truncated in audit log.                                                                                                          |
|                                                                                                                                                                                                                 |
| RISK 9 (CRITICAL): REMARKS is varchar(50) in PO_PRL but form allows 100 chars --- chars 51-100 silently truncated. Data integrity defect --- no error shown to user. See Section 12 Recommendation #16 for fix. |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

# 9. Error Messages

All messages use \'Kalsofte\' as the dialog title (from Global Const head). Style is vbInformation throughout.

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Exact Message Text**                                                             **Triggered By**                              **Root Cause**
  ---------------------------------------------------------------------------------- --------------------------------------------- --------------------------------------------------------------------
  Please Define Item in Item Maste                                                   Add --- pre-add check                         IN_ITEM table is empty

  Please Define Department in Setup                                                  Add --- pre-add check                         IN_DEP is empty for division

  Please Define Document No. for Requisition in Housekeeping                         Add --- pre-add check                         PO_DOC_PARA has no PR entry

  Budget Qty Not Defined. So check Parameter                                         Form load                                     PO_PARA has no record for division

  Date should be Equal to Current Date Or Max PR. Date                               Add/Delete --- date check                     Backdate restriction triggered (IN_PARA.BACKDATE=\'N\')

  PR. Date must be equal to processing date                                          PR Date validation (lose-focus and save)      Date entered is not equal to processing date

  Please enter valid date / Please enter valid Date                                  PR Date validation                            Non-date value entered

  Department Cannot be empty                                                         Save --- header validation                    txtfields\[5\] blank at save time

  Please Select Order Type                                                           Save --- header (PurTypeFlg=1)                PO_GRP field empty when mandatory

  Requester Name Cannot be empty                                                     Save --- header (PurTypeFlg=1)                Requester code empty when mandatory

  Required quantity cannot be empty                                                  Save --- line validation                      Qty column null on non-blank line

  Purchase Requisition Requires at least one Item                                    Save --- line validation                      No valid lines after blank-line purge

  Same Machine or Same Item should not Be repeat                                     Item code validate                            Duplicate item+machine on same PR

  Required Quantity Cannot be Less than Minimum Order Quantity..                     Qty validate                                  Entered qty \< IN_ITEM.MINLEVEL

  Invalid Date                                                                       Required Date validate                        Non-date in MaskEdBox2

  Required Date must be equal to or after the Processing Date.                       Required Date validate (Add)                  Required date \< processing date

  Required Date cannot be less than PR. Date                                         Required Date validate (Modify)               Required date \< PR header date

  Pending Indent Quantity: \[value\]                                                 Item code validate (PendingOrderPara=\'Y\')   KSP_INDEDNT_CHECK returned pending qty \> 0

  Do you want to exit?                                                               After pending indent message                  User prompted; Yes terminates the entire application

  PR. No. for your transaction is \[number\]                                         After successful Save                         Confirms auto-generated or manual PR number

  No records Found / No Record found                                                 Navigation / Find / Search                    Result set empty or pointer at boundary

  NO RECORDS TO PRINT                                                                Print button                                  No PR loaded (no number or date in form)

  Select a value from the list                                                       delmodok --- combo box empty                  User clicked OK without selecting record

  PR. number already Exist                                                           PR Number field tab-out (ManualIndNo=\'Y\')   Duplicate PR number found in PO_PRH

  No PR. Type in Setup Form                                                          IndType() --- PO_INDENTTYPE empty             No active PR types defined

  Error \[N\] (\[description\]) in procedure \[name\] of Form Purchase Requisition   All event handlers (On Error GoTo)            Generic runtime error catch --- procedure name embedded in message
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 10. Related Screens

**[Screens / Controls This Form Opens]{.underline}**

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Screen / Control**                  **How Opened**                          **Purpose**
  ------------------------------------- --------------------------------------- ----------------------------------------------------------------------------------------------------
  LookUp (generic modal popup)          Find / Modify / Delete / List buttons   Selects an existing PR from a grid list. Query varies by operation and PurTypeFlg.

  Frame2 / ksldesc1 (KSL Desc lookup)   On invalid code entry                   Reusable code+description lookup for Dept, Category, Cost Centre, Budget Group, Scope, Item Group.

  FrameItem / FpSpdInd item popup       Item entry area                         Multi-column searchable item listing. Enriched with PO data when Penpodetails=\'Y\'.

  Frame3 / DataCombo1                   Modify / Delete (alternate path)        Dropdown combo record selector for PRs.

  UserFooter1 custom control            Print flow (TC 12)                      Footer/signature line selection before printing.

  Frame4 (deletion type selection)      Delete operation                        Radio buttons: Delete full PR vs. Delete single line.

  Frame5 / Frame6 (Find + History)      Find by PR number; cmd_history button   Frame5: manual PR number search. Frame6: shows full PO history for the currently selected item.
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[Screens That Call This Form]{.underline}**

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Calling Screen**              **How It Calls**                       **Data Passed**
  ------------------------------- -------------------------------------- ----------------------------------------------------------------------------------------------
  Purchase Advice form (PO_PAH)   Opens this form with prano parameter   prano \> 0 triggers UPDATE PO_PAH.PRNO after save

  Main menu / MDI shell           Standard form load                     divcode, pdate, yfdate, yldate, usrid, ulevel, connectstring --- all set as globals at login
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[Downstream Screens That Consume This Form\'s Data]{.underline}**

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Screen**                   **Reads From**    **Relationship**
  ---------------------------- ----------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  PR Approval screen           PO_PRH + PO_PRL   Reads unapproved PRs; writes APP1/2/3, APPFLG, FirstApp/SecondApp/ThirdApp. Web Approval URL: http://10.20.70.200/POApproval/Login.aspx. Screen names within module: (1) Purchase Order \> Purchase Requisition Before Final Level Approval; (2) Purchase Order \> Purchase Requisition Final Level Approval. Three-level flow confirmed by TL-IST Palanivel: Level 1 via VB desktop (also Web for Pallavaa); Level 2 Before Final via web; Level 3 Final Level via web. Pallavaa is production-live on full web approval workflow. Approval configuration currently backend-only --- SPINRISE to provide Division Setup UI (see Section 12 Rec #26).

  PR Amendment screen          PO_PRH + PO_PRL   Creates amended copies; sets AmdFlg=\'Y\' on original lines; increments amendno

  PR Cancellation screen       PO_PRH            Sets cancelflag; records canceldt and canreason

  Purchase Order creation      PO_PRH + PO_PRL   Converts approved PR lines to PO; writes qtyord back to PO_PRL; sets prstatus=\'O\'

  GRN / Goods Receipt screen   PO_PRL            Updates qtyrec; sets prstatus=\'C\' when fully received
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**[Reports]{.underline}**

  --------------------------------------------------------------------------------------------------------------------------------
  **Report**                              **Template**                                         **Triggered By**
  --------------------------------------- ---------------------------------------------------- -----------------------------------
  Printed PR document (standard)          Cry_PR_KSL.rpt --- calls ksl_Tran_PORequisition SP   BUTTON\[13\] when EmpCommon=False

  Printed PR document (employee layout)   Cry_Purchase_Req.rpt                                 BUTTON\[13\] when EmpCommon=True
  --------------------------------------------------------------------------------------------------------------------------------

# 11. Customer Variations

Ten distinct behavioural variations are controlled by PO_PARA parameters and global flags. Each represents a separate customer requirement added over time.

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Variation**                                                            **Parameter / Flag**                                                             **Default**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  **Behaviour When Active**
  ------------------------------------------------------------------------ -------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Manual PR Number                                                         Manual_IndNo = \'Y\'                                                             \'N\'                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        User types PR number; IndentNoChk() validates uniqueness. When \'N\': auto-generated from MAX+1.

  Multi-Purchase-Type                                                      PurTypeFlg = 1 (from purtypeflg)                                                 0                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            Order Type / PO Group field becomes mandatory. All Modify/Delete/Find lookups filtered by user\'s allowed purchase types via tempPurType\[LocalIPAddress\] session table.

  Pending Order Alert                                                      PendingOrderPara = \'Y\'                                                         ---                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          KSP_INDEDNT_CHECK called on every item code entry. If open PO found: warns user; Yes response terminates the entire application.

  Enriched Item Lookup                                                     Penpodetails = \'Y\'                                                             ---                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          Item popup shows 6 extra intelligence columns: Pending Qty, Delivery Date, Min/Max Level, Lead Time, Last Supplier.

  Budget Tracking                                                          BudgetQty = \'Y\'                                                                \'N\'                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        Sub-Cost Centre label highlighted red. Budget balance amount field activated. SPINRISE AMENDMENT (F-05): Sub-Cost Centre field is REMOVED from SPINRISE rendering. BudgetQty flag is retained as a division parameter for future use if Sub-Cost Centre is reinstated on a specific vertical. In current SPINRISE release, BudgetQty visual behaviour on Sub-Cost Centre label is not applicable. F-05 CLOSED.

  Backdate Restriction                                                     IN_PARA.BACKDATE = \'N\'                                                         ---                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          PR date must equal processing date AND be \>= max existing PR date in year. Prevents retroactive entry.

  Report Template Selection                                                EmpCommon flag (from EmpMasterComm)                                              ---                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          True: uses Cry_Purchase_Req with \@Docno/@Docdt params + company-wide employee lookup. False: uses Cry_PR_KSL with \@prno/@prdate params + division-filtered lookup.

  Report Template Division Split (Cry_Purchase_Req vs Cry_PR_KSL)          PO_Para.EmpMasterComm per DivCode                                                'N'                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          Five confirmed divisions use EmpMasterComm = 'Y' (Cry_Purchase_Req): Saranya, Armstrong, Cheran, Skaat, VTS. All other divisions use EmpMasterComm = 'N' or NULL (Cry_PR_KSL). SPINRISE resolution: dual Crystal Reports branching is replaced by a single server-side PDF endpoint; the template is selected by reading PO_Para.EmpMasterComm at render time. New customer onboarding must set EmpMasterComm correctly before PR print will produce a correctly formatted document.

  Item Group-Wise Lookup                                                   InditemGrp = \'Y\'                                                               ---                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          Item lookup popup filtered by 3-char group code entered in txtItemgrpcode. Group filter row visible on form. For mills with large item masters.

  Purchase Advice Linkage                                                  prano \> 0 (session variable)                                                    0                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            When PR raised from a Purchase Advice: UPDATE PO_PAH.PRNO after save. Links PR to pre-existing advice record.

  Pallavaa --- Division-wise Stock in Item Selection Grid                  Customer-specific (Pallavaa)                                                     For Pallavaa customer: the item selection grid in the PR form must display current stock levels broken down by division, not as a single consolidated stock figure. This allows stores and purchase staff to see stock availability per division before raising a PR. Confirmed by TL-IST Palanivel (IST-1, April 2026). SPINRISE: item lookup API must return per-division stock breakdown when Pallavaa division flag is active. Cross-reference: Section 2 item selection popup layout.   

  PR Type Configurable Default --- NEW (CEO R2.0 #28)                      PO_PARA.DefaultPRType --- NEW column. CEO decision 07-May-2026.                  Configurable per division                                                                                                                                                                                                                                                                                                                                                                                                                                                                    SPINRISE AMENDMENT: default PR Type at Add mode is configured per customer/division at implementation via PO_PARA.DefaultPRType. Not hardcoded in application code. Spinning mill divisions default to S (Stores). Paper mill and capital project divisions may set C (Capital) as default. CEO decision 07-May-2026 (Muthuvel).

  Pallvaa Mills + SKS --- Multi-select Item Entry --- NEW (CEO R2.0 #15)   PO_PARA.MultiSelectLookup = 'Y' for named divisions. CEO decision 07-May-2026.   Off by default                                                                                                                                                                                                                                                                                                                                                                                                                                                                               SPINRISE AMENDMENT: named customer requirement raised by Sasi (CEO R2.0). Pallvaa Mills and SKS require the ability to browse-and-tick multiple items simultaneously when raising a PR, rather than item-by-item entry. The Add Multiple multi-select lookup modal (see Section 2) must be enabled for these divisions. API: item selection endpoint must support multi-item response payload. PO_PARA.MultiSelectLookup = 'Y' activates this for the division. CEO decision 07-May-2026.
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 11a. TL-IST Gap Analysis --- Palanivel F-01 to F-14 (v2.4 Amendment Cycle)

TL-IST Palanivel conducted a 30-finding gap analysis cross-referenced against FSD v2.4. Findings classified as Missing / Partial / Covered with section references. F-01 to F-14 were actioned in this amendment cycle (v2.5). F-15 to F-30 were classified as Covered in v2.4 and required no action. All 14 actioned findings are confirmed incorporated below.

  ---------- ---------------------------------------------------------------------------------------------------------- ------------- --------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Ref**    **Finding**                                                                                                **Status**    **FSD Section**                   **Action Taken in v2.5**

  **F-01**   Rate Selection Logic --- 3-option toggle not specified in v2.4                                             **Missing**   Section 2, Section 3, Section 5   INCORPORATED. 3-option rate selector (LPO/AVG/MANUAL), new DB columns PO_PRL.RATE_SOURCE and PO_PRL.RATE_JUSTIFICATION, API save layer validation added. CEO R2.0 #14. CLOSED.

  **F-02**   Add Multiple feature --- multi-select and row-count insert modes not specified                             **Missing**   Section 2, Section 11             INCORPORATED. Add Multiple with both modes documented. Named customer originators Pallvaa Mills and SKS. CEO R2.0 #15, #16. CLOSED.

  **F-03**   Item Thumbnail --- grid line and lookup modal not specified                                                **Missing**   Section 2                         INCORPORATED. Item Thumbnail (grid line) and Item Thumbnail (lookup modal) added to Section 2 Screen Layout. IN_ITEM.IMAGE new column. CEO R2.0 #11, #12. CLOSED.

  **F-04**   Mandatory field focus-out validation --- universal rule not stated for all 5 header fields                 **Partial**   Section 3, Section 4, Rec #4      INCORPORATED. Universal focus-out validation (red border + inline message) confirmed for mandatory fields: PR Date, Department Code, PR Type (header), Item Code (line level), Quantity Required (line level). PR Number is auto-generated --- not a focus-out validation target. Requester Code is conditional. Stated as SPINRISE architecture standard for all transaction entry screens. CEO correction #4. CLOSED.

  **F-05**   Scope Code and Sub-Cost Centre --- usage audit not reflected; removal decision not documented across FSD   **Partial**   Section 2, 3, 5.2, 7, 8, 11       INCORPORATED. Scope Code and Sub-Cost Centre removal documented across all 7 FSD locations (Sections 2, 3, 5.2, 7, 8 x2, 11). DB columns PO_PRH.SCOPECODE and PO_PRH.SUBCOST retained for legacy compatibility. Usage audit methodology confirmed PO_SCOPETYPE unpopulated across all live customer databases. CLOSED.

  **F-06**   KPI Summary Strip --- 5-card layout and Add mode suppression not specified                                 **Missing**   Section 2, Rec #32                INCORPORATED. KPI Strip 5-card layout added to Section 2. Add mode suppression (cards 3-5 hidden before first save) documented. Rec #32 added. CEO R2.0 #17, #29. CLOSED.

  **F-07**   Budget Category conditional field --- Paper Mill vertical not specified                                    **Missing**   Section 2, Rec #30                INCORPORATED. Budget Category field added to Section 2 (conditional --- Paper Mill + Capital PR Type only). New column PO_PRL.BUDGETCAT. Rec #30 added. CEO R2.0 #27 (Muthuvel). CLOSED.

  **F-08**   Multi-vertical architecture pattern --- Rec #31 dual approach not documented                               **Missing**   Rec #31                           INCORPORATED. Rec #31 updated with both approaches documented at equal specification clarity: Approach A (PO_PARA.VerticalProfile) and Approach B (pp_divmas.Division_Flag --- Sasi). Decision flagged ARCHITECTURE MECHANISM PENDING CEO DECISION. CLOSED pending CEO instruction.

  **F-09**   Tab skip rule --- auto-filled read-only fields not excluded from tab order                                 **Missing**   Rec #29                           INCORPORATED. Rec #29 added: confirmed tab sequence for PR item grid; auto-filled read-only fields excluded. Stated as SPINRISE standard for all transaction grids. CEO R2.0 #26 (Muthuvel). CLOSED.

  **F-10**   PR List Screen --- approval status badge, filters, and additional columns missing from Section 10          **Missing**   Section 10                        INCORPORATED. PR List Screen added to Section 10 with colour-coded approval status badge (Requested=Blue, First Level=Teal, Before Final=Amber, Final=Green, PO Raised=Purple, Cancelled=Red), confirmed filters (Approval Status multi-select, PR Date range defaulting to current FY, Department, Requester), additional columns (Catalogue Number, Required Date). CLOSED.

  **F-11**   PR Date editability --- SPINRISE amendment not clearly stated                                              **Partial**   Section 2, Section 3              INCORPORATED. PR Date SPINRISE amendment confirmed in Sections 2 and 3: processing date is default; user may change to any date on or after processing date. DTPicker1.MaxDate retained. CEO R2.0 #10. CLOSED.

  **F-12**   Sample Flag default --- SPINRISE default not stated                                                        **Partial**   Section 2                         INCORPORATED. Sample Flag SPINRISE amendment confirmed in Section 2: default = N (not a sample). Informational display on printed PR and approval screen. CEO R2.0 #13. CLOSED.

  **F-13**   Seenivasan IST inputs --- not incorporated in v2.4                                                         **Missing**   Multiple sections                 INCORPORATED. Seenivasan IST inputs incorporated across relevant sections. Confirmed in Document Identity amendment note. CLOSED.

  **F-14**   Web Form Blueprint binding standard --- not referenced in FSD                                              **Missing**   Rec #33                           INCORPORATED. Rec #33 added: Web Form Blueprint v1 (Abinandan + Sasi) --- draft submitted by Abinandan to Sasi on 09-May-2026, pending CEO approval 11-May-2026 --- stated as binding SPINRISE UX standard. FSD and Blueprint relationship defined. No PR implementation to begin until CEO sign-off confirmed. CLOSED.
  ---------- ---------------------------------------------------------------------------------------------------------- ------------- --------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 12. SPINRISE Recommendations

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **\#**   **Recommendation**                                                                                                                    **Priority**   **Detail**
  -------- ------------------------------------------------------------------------------------------------------------------------------------- -------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  1        Atomic Document Number Generation                                                                                                     Critical       Replace MAX(prno)+1 client-side logic with a server-side DB SEQUENCE or IDENTITY column. Current approach causes duplicate PR numbers under concurrent access.

  2        Enable and Enforce PO_PRL→PO_PRH Foreign Key                                                                                          Critical       Re-enable FK_PO_PRL_PO_PRH WITH CHECK in the migrated schema. Redesign save flow to eliminate the orphaned-lines window during delete-and-reinsert.

  3        Replace Delete-and-Reinsert with Delta Update                                                                                         High           On Modify, update only changed lines rather than deleting all and reinserting. This preserves approval workflow data (FirstApp, SecondApp flags, approver names) written by downstream screens.

  4        Responsive Two-Panel Layout                                                                                                           High           Replace MDI + SSTab with a sticky Header Panel and a scrollable Item Lines Panel. Item entry via a dedicated add/edit form below the grid (not inline in the grid itself). SPINRISE ARCHITECTURE STANDARD (CEO correction #4 --- incorporated v2.5): Mandatory field focus-out validation --- on focus-out from any mandatory field when empty, the field must display a red border and an inline validation message. This rule applies universally to the mandatory PR fields: PR Date, Department Code, PR Type (header level), Item Code (line level), Quantity Required (line level). Note: PR Number is auto-generated and is not a focus-out validation target. Requester Code is conditional (mandatory only when PurTypeFlg=1). This is the SPINRISE architecture standard for all transaction entry screens. Refs: Section 3 field notes; F-04 CLOSED.

  5        REST API for All Field Lookups                                                                                                        High           Replace all ADO in-form lookups (item name, rate, stock, machine, dept) with debounced async REST API calls on onChange/onBlur events.

  6        Type-ahead Searchable Dropdowns                                                                                                       High           Replace FpSpdInd spread popup and LookUp form with type-ahead combobox components querying the server as user types. Eliminates loading thousands of items into browser memory.

  7        Configuration-Driven Feature Flags                                                                                                    High           Expose all 9 customer variations as named flags in a Division Parameters API. Front-end fetches flags on form load and conditionally renders/enables fields. Replace scattered If statements.

  8        Redesign Pending Indent Response                                                                                                      High           Replace application-terminating End call with a dismissable modal showing PO number, date, and pending qty. Let user proceed, cancel the line, or navigate to the existing PO.

  9        Server-Side Validation in Single Save API                                                                                             Medium         Move all validations to a server-side endpoint. Wrap po_prh INSERT, po_prl INSERT, LogDet_po INSERT, and po_pah UPDATE in a single DB transaction with proper rollback on failure.

  10       Audit Logging via Middleware                                                                                                          Medium         Move LogDet_po writes to an audit middleware layer on the API server. Capture user ID, IP, host, timestamp, module automatically --- not per-screen.

  11       Web-Rendered PDF Reports                                                                                                              Medium         Replace Crystal Reports (.rpt, Crystl32.OCX) with a server-side PDF API calling ksl_Tran_PORequisition directly. The SP is structurally reusable --- no SQL changes needed.

  12       Make Signature Labels Configurable                                                                                                    Medium         Hardcoded labels \'Verified by - Store\', \'Approved by - GM/AGM\', \'Authorised Signatory - President\' in ksl_Tran_PORequisition must be driven by PO_PARA.AppUserLabel1/2/3.

  13       Approval Pipeline Visualisation                                                                                                       Medium         Replace the simple approval status label (LblApproval) with a visual multi-step pipeline showing which levels are complete, who approved, and when --- using APP1DATE/APP2DATE/APP3DATE.

  14       Fix Schema Data Types                                                                                                                 Low            Convert createddt from VARCHAR(25) to DATETIME2. Merge APP1DATE+APP1TIME into single DATETIME2 columns. Increase REMARKS to varchar(100) to match form validation.

  15       Session Management for PurTypeFlg                                                                                                     Low            Replace tempPurType\[LocalIPAddress\] table (IP-address-keyed session) with a proper server-side session token. IP-based sessions fail behind NAT/proxies and are unsafe.

  16       **Fix Remarks Field Truncation --- Critical Defect**                                                                                  **Critical**   PO_PRL.REMARKS is varchar(50) in the database but the UI allows up to 100 characters. Characters 51--100 are silently truncated with no error message shown to the user --- a data integrity defect. SPINRISE fix: increase PO_PRL.REMARKS to varchar(100) and enforce server-side length validation to return a clear error if the limit is exceeded.

  17       **ERP Login Username Missing from PR Print --- Known Defect (IST-3 Item 1, Muthuvel)**                                                **Critical**   The ERP login username (userId / createdby in PO_PRH) of the person who created the PR does not appear on the printed PR document. The SP ksl_Tran_PORequisition retrieves this via J-3 (PP_PASSWD LEFT JOIN) but it is not rendered in the Crystal Reports template. Source: Muthuvel IST-3 Item 1. SPINRISE fix: QuestPDF PR template must include the ERP login user (createdby) who raised the PR. Map to PO_PRH.userId / createdby field in the API response.

  18       **Requester Employee Name Missing from PR Print --- Known Defect (Palanivel IST-3 Item 3)**                                           **Critical**   The requester employee name (PO_PRH.REQNAME resolved via PR_EMP.ENAME through J-2 LEFT JOIN in ksl_Tran_PORequisition) does not appear on the printed PR document. This is a different field from the ERP login username (defect #17). The Requester is the employee from the requesting department who initiated the procurement need. Source: TL-IST Palanivel IST-3 Item 3. SPINRISE fix: QuestPDF template must display both the Requester name (from PR_EMP.ENAME via REQNAME lookup) and the ERP login user (createdby) as separate labelled fields on the printed PR.

  19       **Item Line Duplication on PR Print when Same Machine Exists in Multiple Departments --- Known Defect (IST-3 Item 2, Muthuvel)**      **Critical**   When the same machine code exists in both Mechanical and Electrical departments (or any two departments), the PR print produces duplicate item rows. Root cause: Join J-5 in ksl_Tran_PORequisition joins PO_PRL to MM_MACMAS on divcode + macno + DEPCODE but the DEPCODE condition is not filtering correctly when the same macno appears under multiple departments. Source: Muthuvel IST-3 Item 2. SPINRISE fix: the machine JOIN in the QuestPDF data API must filter by PO_PRH.DEPCODE to ensure only the machine record for the PR's requesting department is matched. Add integration test for PRs with multi-department machine codes.

  20       **LPO Rate, LPO Date, and Supplier Details Not Refreshing After Save --- Known Defect (IST-4 Item 3, Muthuvel)**                      **High**       After saving a PR and returning to Query Mode, the LPO Rate, LPO Date, and Purchase From / Supplier Details columns in the item grid are not loaded correctly. Root cause: adoPrimaryRS is not re-queried from the database after CommitTrans completes, so the grid displays the pre-save ADO recordset state. Source: Muthuvel IST-4 Item 3. SPINRISE fix: the React item grid must reload all line data from the GET /pr/{id} API response after every successful save (POST or PUT). No stale local state must persist after a save operation.

  21       **Ghost Record Visible in Query Mode After Successful Delete --- Known Defect (IST-4 Item 9, Palanivel)**                             **Critical**   After a PR is successfully deleted (CommitTrans completes, success message shown), the deleted record remains visible in the Query Mode list until the form is closed and reopened. Root cause: adoPrimaryRS is not re-queried after CommitTrans --- the deleted record persists in the ADO recordset in memory. Source: TL-IST Palanivel IST-4 Item 9. SPINRISE fix: React UI must remove the deleted record from local component state immediately when the DELETE API returns a 200 response. No form close or page reload should be required.

  22       **Item History Shows 'No Records Found' Despite Data Existing --- Known Defect (IST-4 Item 8, Palanivel)**                            **Critical**   When a user opens Item History for a PR line item, the system returns 'No Records Found' even when transaction history data exists for that item and division. Root cause: the item history lookup query fails to correctly match the divcode and itemcode combination. Source: TL-IST Palanivel IST-4 Item 8. SPINRISE fix: verify that the item history API endpoint passes both divcode and itemcode as exact-match query parameters. Add integration test to assert non-empty result for items with known transaction history.

  23       **Duplicate Item Allowed on Modify in Some Code Paths --- Known Defect (IST-4 Item 5, Muthuvel)**                                     **High**       When modifying an existing PR, the same item code + machine code combination can be saved again in certain code paths, bypassing the V15 duplicate check. The duplicate check (V15) does not fire consistently across all Modify scenarios. Source: Muthuvel IST-4 Item 5. SPINRISE fix: enforce composite uniqueness constraint on Item Code + Machine Code per PR at both the API validation layer and the database level (unique index on PO_PRL: divcode + prno + prdate + itemcode + macno). Reject duplicate combination with a clear error message before save.

  24       **Grid Navigation Defect --- Cannot Modify Earlier Row Quantity After Adding New Rows --- Known Defect (PM Saravanan IST-4)**         **High**       While adding items to a PR one by one, if the user enters the required quantity for the first item and then adds additional items, they are unable to return to and modify the quantity of the first item before saving. The grid navigation locks earlier rows once new rows are added below them. Source: PM Saravanan IST-4 feedback. SPINRISE fix: the React data grid must allow unrestricted editing of any row at any time before the Save action is submitted. No row should become read-only due to the addition of subsequent rows.

  25       **Pending PR Quantity and Pending PO Quantity Not Visible When Raising a PR --- Known Defect (PM Saravanan IST-4)**                   **High**       When a user raises a new PR for an item, the current pending PR quantity (already raised but not yet ordered) and pending PO quantity (ordered but not yet received) are not displayed. This leads to duplicate or excess ordering. Source: PM Saravanan IST-4 feedback. SPINRISE fix: the item selection lookup must surface current pending PR quantity and pending PO quantity alongside the stock figure for each item. These values must come from KSP_INDEDNT_CHECK logic and po_ordl open quantities respectively, presented before the user confirms the item selection.

  26       **Budget Quantity Validation Is Customer-Specific and Not Configurable --- Known Defect (PM Saravanan IST-4)**                        **High**       Budget quantity validation is currently implemented only for the Bannari customer and is not a standard configurable feature available to all customers. Source: PM Saravanan IST-4 feedback. SPINRISE fix: BudgetQty flag in PO_PARA must be a standard, configurable division-level parameter available to all customers. The budget quantity validation logic must activate based on this flag, not on a hardcoded customer check. Division Setup UI must expose this as a configurable option during customer onboarding.

  27       **Approval Configuration Is Backend-Only with No Setup UI --- Known Defect (PM Saravanan IST-2)**                                     **High**       PR approval levels are currently configured directly in the database by the Kalsofte backend team. There is no UI for customers or division admins to configure the approval chain. Up to 3 approval levels are supported (configurable via Pr_ILevel, Pr_FLevel in PO_PARA); a single level may be sufficient for some customers. Source: PM Saravanan IST-2 feedback. SPINRISE fix: provide a Division Setup UI screen where the approval chain can be configured: number of levels (1--3), approver roles for each level, and whether Level 2 (Before Final) can be bypassed. Approval configuration must not require backend database access.

  28       **Drawing Number and Catalogue Number Suppressed in Some PR Print Templates --- Known Defect (IST-4 Item 6, Muthuvel + Palanivel)**   **High**       In some Crystal Reports PR print templates, the Drawing Number (IN_ITEM.DRAWNO) and Catalogue Number (IN_ITEM.CATLNO) columns are suppressed and do not appear on the printed PR, even when data exists. The SP ksl_Tran_PORequisition retrieves both fields via J-6 (PO_PRL LEFT JOIN IN_ITEM). Source: Muthuvel IST-4 Item 6, confirmed by TL-IST Palanivel. SPINRISE fix: the QuestPDF PR template must include Drawing Number and Catalogue Number columns unconditionally, without suppression logic. Both columns must always appear on the printed PR regardless of customer template variations.

  **29**   **SpinRise Tab Skip Rule --- All Grids (CEO R2.0 #26, Muthuvel)**                                                                     **Critical**   SPINRISE AMENDMENT --- NEW REC. Source: CEO decision 07-May-2026 (Muthuvel). Tab order in all SpinRise grids must skip auto-filled read-only fields. Confirmed tab sequence for PR item grid: Item Code → Quantity Required → Required Date → Machine No. → Approx. Cost → Category → Remarks → next-row Item Code. Tab must never land on: Item Description, UOM, Current Stock, Rate (auto-filled read-only fields). This rule applies to ALL SpinRise transaction entry grids, not just the PR form. Governs together with mandatory field focus-out validation (Rec #4 / CEO R2.0). Web Form Blueprint owner: Abinandan.

  **30**   **Budget Category Conditional Field --- Paper Mill Vertical Architecture (CEO R2.0 #27, Muthuvel)**                                   **High**       SPINRISE AMENDMENT --- NEW REC. Source: CEO decision 07-May-2026 (Muthuvel). Budget Category (PO_PRL.BUDGETCAT) is visible and mandatory ONLY when PR Type = C (Capital) AND division vertical profile = Paper Mill. Invisible and not applicable on all spinning mill screens. This is the first field that differs between spinning mill and paper mill verticals. Multi-vertical architecture must be resolved at FSD and backend level before development begins on the PR module (CEO email directive, 07-May-2026). Backend schema and API implications to be confirmed by Sasi. New column: PO_PRL.BUDGETCAT (varchar, max 20 chars). FSD amendment owner: Mariyaiya.

  **31**   **Multi-Vertical Configuration Architecture Pattern (CEO R2.0, CEO Closing Note)**                                                    **High**       SPINRISE AMENDMENT --- NEW REC. Source: CEO closing note 07-May-2026. Budget Category (Rec #30) establishes the first formal multi-vertical field difference between spinning mill and paper mill SpinRise configurations. Two architecture approaches have been identified and are documented below with equal specification clarity. \*\*\* ARCHITECTURE MECHANISM PENDING CEO DECISION --- DO NOT IMPLEMENT EITHER APPROACH UNTIL CEO INSTRUCTION IS RECEIVED. \*\*\* APPROACH A --- PO_PARA.VerticalProfile (Mariyaiya / FSD proposal): A new column PO_PARA.VerticalProfile (varchar, values: SPINNING / PAPERMILL) is added to the division parameters table. The Division Configuration API reads this flag at form load and passes it to the React frontend. The frontend uses the flag to control field visibility, mandatory rules, and UI rendering for all vertical-specific fields across all SpinRise modules. Advantages: single flag per division, centralised in existing PO_PARA table, no new table required. Disadvantage: PO_PARA is already large (63+ columns) and adding a vertical profile flag to a purchase-module-specific table may not be appropriate for a system-wide architecture pattern. APPROACH B --- pp_divmas.Division_Flag (Sasi / backend proposal): A new column Division_Flag is added to the existing pp_divmas (Division Master) table, which is a shared master table used across all SpinRise modules. Values: SPINNING / PAPERMILL. The Division Master API (used at system login and division setup) returns this flag for the active division. All module forms read the flag from the division master response and apply vertical-specific rendering rules accordingly. Advantages: Division_Flag sits in the correct master table (pp_divmas), applies naturally across all modules without coupling to the purchase module, and aligns with the multi-module architecture intent of the CEO directive. Disadvantage: requires pp_divmas schema change and migration for all existing division records. CEO ACTION REQUIRED: Review both approaches and instruct the team on which architecture pattern to adopt. Sasi to confirm pp_divmas.Division_Flag specification is complete and ready for CEO review. Action owners: Mariyaiya (FSD definition --- both approaches documented), Sasi (backend assessment --- both approaches). Deadline: pending CEO decision.

  **32**   **Add Mode Suppression Rule --- SpinRise Display Standard (CEO R2.0 #29, Sasi)**                                                      **Critical**   SPINRISE AMENDMENT --- NEW REC. Source: CEO decision 07-May-2026 (Sasi). In Add mode (before first save), the following elements must be hidden: Created By field, Approval Status label, Approval Pipeline strip (Rec #13), KPI Summary Strip cards 3--5 (Approx Budget, Created By, Approval Status). Only KPI cards 1 (Total Lines) and 2 (Total Quantity --- UOM-grouped) are visible in Add mode, providing a live running total as lines are entered. All suppressed elements activate automatically after the first successful save (POST response 201). In Modify, Find, and Query modes: all elements visible. This rule applies to the PR form and is the SpinRise Add Mode Suppression Standard for all transaction entry screens. Action owner: Abinandan (Web Form Blueprint v1 --- draft submitted by Abinandan to Sasi on 09-May-2026. Pending CEO approval --- 11-May-2026. No PR implementation to begin until CEO sign-off confirmed).

  **33**   **Web Form Blueprint --- Binding SpinRise UX Standard (CEO R2.0)**                                                                    **High**       SPINRISE AMENDMENT --- NEW REC. Source: CEO R2.0 review cycle, 07-May-2026. The SpinRise Web Form Blueprint v1 (owner: Abinandan + Sasi) is the binding UX standard for all SpinRise transaction screens. Web Form Blueprint draft submitted by Abinandan to Sasi on 09-May-2026. Pending CEO approval --- 11-May-2026. No PR implementation to begin until CEO sign-off confirmed. The FSD defines functional and data behaviour; the Blueprint defines visual and interaction behaviour. Where both documents address the same element, the Blueprint takes precedence for UX. Blueprint scope: typography (mixed-case, title-case labels, no all-caps), colour palette (hex codes), field alignment, numeric precision, inline icon lookup standard (F1 replaced by inline icon, Alt+Down / Ctrl+Space), auto row-1 on New PR, tab skip rule (Rec #29), mandatory field focus-out validation (red border + inline message), Add mode suppression (Rec #32), KPI strip 5-card layout, column widths (Required Date min 90px), colour-coded status badges (Requested=blue, Approved=green, Rejected=red, PO Raised=purple), persistent context navigation breadcrumb, toolbar visual modernisation (web-native, not VB6 replica), SQL Server 2019 feature usage notes. No PR screen implementation to begin until Blueprint is signed off by CEO (CEO email directive, 07-May-2026).
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 13. IST Review Questions

All questions have been reviewed and answered by the IST team (April 2026). The table below records each question, the IST answer, the confirmed SPINRISE suggestion, and the sections affected. Status: ALL RESOLVED.

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **\#**   **Question**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        **Section Affected**       **Why It Matters**
  -------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  1        RESOLVED (April 2026). EmpCommon is set at login by reading PO_Para.EmpMasterComm for the active DivCode. EmpMasterComm = 'Y' sets EmpCommon = True (Cry_Purchase_Req, company-wide employee lookup). Any other value or NULL sets EmpCommon = False (Cry_PR_KSL, division-filtered lookup). No hardcoding exists in the form or common module. Five confirmed divisions use EmpMasterComm = 'Y': Saranya, Armstrong, Cheran, Skaat, VTS. All other divisions use the standard Cry_PR_KSL path. See Sections 5.10 and 7.7 for full documentation.   Sections 7.7, 11           Controls which Crystal Reports template and employee lookup path is used. Cannot migrate without knowing the trigger. IST ANSWER: Employee list should display based on division; parameterised logic supports both division-wise and combined unit views. SPINRISE SUGGESTION: No change to transaction print. Continue parameterised division/combined logic in SPINRISE employee lookup.

  2        How is tempPurType\[LocalIPAddress\] populated? Is it set at login by the main menu? What happens if two users share the same IP address (NAT/proxy environment)?                                                                                                                                                                                                                                                                                                                                                                                   Sections 4.4, 6, 11        IP-keyed session table is unsafe in web. Needs replacement with proper session tokens. IST ANSWER: tempPurType is set at login by the main menu shell; confirmed IP-keyed. Under NAT/proxy, shared IPs cause session collision. SPINRISE SUGGESTION: Replace with server-side JWT session token per authenticated user. IP-keyed table to be decommissioned.

  3        The Requester field (txtfields\[1\]) label says \'Requester Name\' but stores a numeric employee code. PO_PRH.REQNAME is VARCHAR(10). Does the system store employee number or free-text name? The code shows both paths.                                                                                                                                                                                                                                                                                                                           Sections 2, 3, 7.6         Determines the data model for requester in the web version. IST ANSWER: The field stores a numeric employee code (empno); the name is resolved via PR_EMP lookup. REQNAME is VARCHAR to allow flexibility but always holds a numeric value in practice. SPINRISE SUGGESTION: Store empno as integer FK; resolve display name via employee API on form load and print.

  4        Which customers use the Purchase Advice (PO_PAH) pre-authorisation step? Is PO_PAH a standard table or a customer-specific addition?                                                                                                                                                                                                                                                                                                                                                                                                                Sections 5.9, 8 (A.4)      The PO_PAH UPDATE runs outside the transaction --- migration design depends on whether this is a standard or optional feature. IST ANSWER: PO_PAH is a standard table used where a Purchase Advice pre-authorisation step exists. It is customer-specific; not all divisions use it. SPINRISE SUGGESTION: Include PO_PAH linkage inside the atomic save transaction in SPINRISE to prevent the orphaned-link risk.

  5        Can a PR be modified after partial approval (e.g., FirstApp=\'Y\' but not fully approved)? The current code only blocks modification after FULL approval (APPFLG=\'Y\').                                                                                                                                                                                                                                                                                                                                                                            Sections 4.4, 5.8, 8 (C)   Delete-and-reinsert on Modify destroys partial approval data. IST must decide whether partially approved PRs should be modifiable. IST ANSWER: Partially approved PRs (FirstApp=Y but not fully approved) should NOT be modifiable --- approval data must be preserved. SPINRISE SUGGESTION: Block Modify if any approval flag is set (FirstApp, SecondApp, or ThirdApp = Y), not just APPFLG=Y. Use delta-update (not delete-and-reinsert) to preserve approval data.

  6        What does IndentNoChk() do beyond a simple duplicate check? Its full body is visible (queries COUNT from po_prh) --- is this the complete logic or is there more in a version not provided?                                                                                                                                                                                                                                                                                                                                                         Section 7.6                Already confirmed as a simple count check, but IST should confirm no additional logic exists in other code paths. IST ANSWER: Confirmed --- IndentNoChk() is purely a COUNT duplicate check on PO_PRH. No additional hidden logic exists. SPINRISE SUGGESTION: Manual PR numbering is not required in SPINRISE. Auto-generate using DB SEQUENCE. Manual_IndNo flag to be retired.

  7        Where is bolLookupItemgrpwise set and by whom? It is initialised by LookupItemgrpwise() reading PO_PARA.InditemGrp --- confirmed. But is this also manually overrideable by a user or admin?                                                                                                                                                                                                                                                                                                                                                        Sections 5.4, 11           Determines whether this is a fixed config or a per-user preference. IST ANSWER: bolLookupItemgrpwise is a division-level fixed config set via PO_PARA.InditemGrp. It is not manually overrideable by individual users. SPINRISE SUGGESTION: Retain as a division-level configuration flag in the SPINRISE Parameters API. No per-user override needed.

  8        What business process uses Sample=\'Y\' lines (PO_PRL.Sample) differently from normal lines? Is there a separate approval or procurement workflow for sample requests?                                                                                                                                                                                                                                                                                                                                                                              Sections 2, 8 (A.2)        Sample flag is written by this form but its downstream use is not visible in the provided code. IST ANSWER: Sample=Y lines follow the same approval workflow as normal lines. The flag is informational --- it appears on the printed PR to indicate a trial/sample purchase to the approver, but does not gate a separate workflow. SPINRISE SUGGESTION: Retain as a display flag on the PR line; surface it visually on the print and approval screens.

  9        The macflag=\'M\' filter in ksl_Tran_PORequisition silently excludes non-Main machines from the printed PR. Are there machine types other than \'M\' in live MM_MACMAS data? Should their details appear on the print?                                                                                                                                                                                                                                                                                                                              Section 8 (B.2)            Non-M machines will show blank details on the printed document --- may be causing incorrect PRs in production. IST ANSWER: Only macflag=M (Main machines) are used in the PR context. Sub-machines and auxiliary equipment are not raised via PR. The filter is intentional and correct. SPINRISE SUGGESTION: Retain macflag=M filter. Document this explicitly in the SPINRISE machine lookup API specification.

  10       Is prstatus value \'C\' for Received or for Cancelled? Both meanings appear in the code: qry1() CASE treats \'C\' as RECEIVED; some comments suggest CANCELLED. Which is correct?                                                                                                                                                                                                                                                                                                                                                                   Sections 5.5, 8 (A.2)      Incorrect status display would mislead users on the PR status screen. IST ANSWER: prstatus = \'C\' means RECEIVED (GRN completed). Cancellation is handled separately via cancelflag on PO_PRH --- not via prstatus. The comments in old code are misleading. SPINRISE SUGGESTION: Rename prstatus=\'C\' to \'R\' (Received) in the SPINRISE data model to eliminate ambiguity. Update qry1() CASE logic accordingly.

  11       What is the distinction between PO_PRH.SubCost (header level) and PO_PRL.CCCODE (line level)? In spinning mill operations, what is the business difference between sub-cost centre and cost centre?                                                                                                                                                                                                                                                                                                                                                 Sections 2, 3, 8           Needed to correctly model the cost attribution structure in the web version. IST ANSWER: SubCost (header) is the sub-cost centre of the requesting department --- a broad cost grouping at department level. CCCODE (line) is the specific cost centre for each individual line item --- a finer-grained budget allocation. In spinning mills, a department may have one SubCost but individual machines or processes carry distinct CCCODEs. SPINRISE SUGGESTION: Retain both fields. Header SubCost auto-defaults to the department\'s sub-cost; line CCCODE is user-selectable per item.

  12       AppUserLabel1/2/3 columns exist in PO_PARA but the SP ksl_Tran_PORequisition hardcodes signature labels. Are the PO_PARA label columns used by any other screen or report, or are they unused?                                                                                                                                                                                                                                                                                                                                                      Sections 8 (B.2), 12       If unused, they can be activated for the web PDF. If used elsewhere, the migration must be consistent. IST ANSWER: AppUserLabel1/2/3 columns in PO_PARA are currently unused by any other screen or report. They were added in anticipation of configurability but never activated. SPINRISE SUGGESTION: Activate AppUserLabel1/2/3 in the SPINRISE PDF generator to replace the hardcoded signature labels in ksl_Tran_PORequisition. Division setup must populate these values during onboarding.

  13       Should ksp_PendPR (pending PR check on item code entry) remain a hard block that terminates the application, or should it be converted to a soft dismissable warning? Should the behaviour be configurable per division?                                                                                                                                                                                                                                                                                                                            Sections 4.4, 9, 12        RESOLVED. IST ANSWER: The hard block must be removed. Critical materials may require immediate purchase at any time regardless of a pending PR. The system should display a soft validation informing the user that a PR is pending for PO creation. SPINRISE SUGGESTION: Replace the application-terminating End call with a dismissable modal warning showing the pending PR number, date, and outstanding quantity. The user may proceed, cancel the line, or navigate to the existing PR. Hard block to be removed entirely.

  14       Is the blcode field (Oracle-origin column present in some configurations) required in SPINRISE SQL Server schema?                                                                                                                                                                                                                                                                                                                                                                                                                                   Section 8                  RESOLVED. IST ANSWER: Not required. Confirmed by CEO --- blcode is an Oracle-era legacy field with no active business use in the current SQL Server environment. SPINRISE SUGGESTION: Remove blcode from all SPINRISE table schemas, stored procedures, and API response models. Do not migrate.

  15       What is the uniqueness rule for PR line items --- is it item code only, or item code + machine code combined?                                                                                                                                                                                                                                                                                                                                                                                                                                       Sections 4.3, 8            RESOLVED. IST ANSWER: Uniqueness rule is Item Code + Machine Code combined. Certain customers associate a machine with a selected item for procurement purposes. This is department-driven and visible on the transaction print (not on other reports). It helps customers track item selection within their operational workflow. SPINRISE SUGGESTION: Enforce composite uniqueness constraint on Item Code + Machine Code per PR. Duplicate combination to be rejected at API validation layer.

  16       Is PO_Para.PRapprovalstatus a display-only field or does it gate any form operation (Add, Modify, Delete, Save)?                                                                                                                                                                                                                                                                                                                                                                                                                                    Sections 2, 6, 11          RESOLVED. IST ANSWER: Display only. PRapprovalstatus is shown in the transaction form as a side window indicator so users can see the current PR approval status without running a separate query each time. It does not gate any Add, Modify, Delete, or Save operation. SPINRISE SUGGESTION: Implement as a read-only status badge/panel on the PR form header, auto-refreshed via API call on form load and after each save.

  17       Is Manual PR numbering (Manual_IndNo = \'Y\') required in SPINRISE? Is there any customer-specific business reason to retain it?                                                                                                                                                                                                                                                                                                                                                                                                                    Sections 5.1, 11, 12       RESOLVED. IST ANSWER: Manual numbering is not required in SPINRISE. For a controlled web architecture, auto-generation is the correct approach. Manual_IndNo flag is not advisable and should not be carried forward. SPINRISE SUGGESTION: Remove Manual_IndNo flag entirely. Implement atomic PR number generation using a DB SEQUENCE or IDENTITY column. IndentNoChk() duplicate-check logic to be retired.

  18       Is the PurOrd.UserFooter OCX footer selector (signature line selection before printing) functionality required in SPINRISE? The OCX (ActiveX) component is Windows desktop-only and cannot run in a browser.                                                                                                                                                                                                                                                                                                                                        Sections 7, 10, 12         RESOLVED. IST ANSWER: The footer selector functionality is required in SPINRISE. OCX/ActiveX is a Windows desktop-only technology and is not supported in web browsers due to browser security architecture. The business requirement (signature/footer line selection before print) must be retained. SPINRISE SUGGESTION: Rebuild UserFooter as a native web component (React dropdown or modal selector) that allows the user to select the appropriate signatory/footer configuration before generating the PDF. The OCX itself is not migrated.

  19       What is the complete list of PO_Para flags and their expected default values in SPINRISE? Are there flags currently in the PO_Para table that are not used by any active screen or business process?                                                                                                                                                                                                                                                                                                                                                Section 8 (A.5), 11, 12    RESOLVED. IST ANSWER: Some flags in the PO_Para table are no longer used by any active screen or process and should be removed. A full audit is required before go-live. SPINRISE SUGGESTION: po_para column audit completed April 2026. 63 columns analysed across the full table. 10 confirmed unused/legacy columns identified for removal: Adv_PayType (no form binding --- marked for deprecation), Servicepoprintapp (not in form --- legacy), username (not in form --- legacy), Trans_UserId, Trans_date, Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo (log/archive fields --- not active business flags). 6 flags directly used by the PR form confirmed active: Manual_IndNo (manual PR number entry flag), BudgetQty (budget quantity control), PRapprovalstatus (approval status display --- customer specific), Penpodetails (pending PO details flag), pendingorderpara (pending order parameter), InditemGrp (indent item group flag). Note: ManIndNo confirmed as legacy duplicate of Manual_IndNo (po_para column audit April 2026). ManIndNo to be removed from SPINRISE schema. Only Manual_IndNo to be retained. Confirmed SPINRISE defaults documented in Section 11. Remove all 10 unused columns from SPINRISE schema. Retain only active flags with confirmed default values in the Division Setup Guide.

  20       IST-A: For the PR approval workflow --- which form handles the actual approval action? How many approval levels are standard? Are approval levels customer-configurable? What happens to a PR that reaches Final Level Approved --- does it auto-convert to a PO, or does a separate PO creation step follow?                                                                                                                                                                                                                                       Sections 5.5, 6, 10, 12    RESOLVED. IST ANSWER: Approval is handled in the PO module and also in the Web Approvals module. A Final Level Approved PR does NOT auto-convert to a PO --- a separate PO creation step follows. Approval levels are customer-configurable via PO_Para (Pr_ILevel, Pr_FLevel). SPINRISE SUGGESTION: PR approval workflow is handled entirely within the SPINRISE Web Approvals module, not within the PR form itself. The PR form is responsible only for creation and submission. Post-final-approval, a separate PO Creation screen converts approved PR lines into a Purchase Order. Approval level configuration to be migrated as a SPINRISE Division Parameter.
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 14. Summary Scorecard

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Assessment Area**             **Rating**  **Summary Findings**
  ------------------------------ ------------ -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **Screen Purpose**              **5 / 5**   Very clearly defined: internal procurement requisition with full lifecycle (Add/Modify/Delete/Find/Print/Approval-tracking). No ambiguity.

  **Validation Coverage**         **4 / 5**   Strong --- 5 pre-add, 6 header, 12 line, 8 customer-specific rules. Minor gap: no server-side duplicate date check beyond backdate restriction. Pending indent exit behaviour is extreme.

  **Business Logic**              **3 / 5**   Good auto-fill coverage. Conservative stock minimum rule is well-designed. Delete-and-reinsert on Modify destroys approval data --- a design risk. Grid column navigation logic is brittle.

  **Database Design**             **3 / 5**   PK design is sound. One hard FK enforced (itemcode→IN_ITEM). Critical gaps: PO_PRL→PO_PRH FK disabled; CHECK constraints WITH NOCHECK; non-atomic PR numbering; createddt as VARCHAR.

  **Stored Procedure Quality**    **4 / 5**   ksl_Tran_PORequisition is comprehensive and structurally reusable. KSP_INDEDNT_CHECK is clean and well-scoped. Both have string-typed date parameters that should be strongly typed.

  **Code Quality**                **2 / 5**   Typical VB6-era: large monolithic BUTTON_Click handler (14 cases), scattered globals, inline SQL (injection risk), On Error Resume Next used liberally, app-terminating End call on pending indent.

  **Customer Configurability**    **4 / 5**   9 distinct behavioural switches identified. Excellent parameter coverage. EmpCommon flag origin and division assignment fully documented (Section 5.10). All 20 IST questions resolved. IP-keyed session table to be replaced with JWT in SPINRISE.

  **Migration Readiness**         **3 / 5**   Schema and SP are reusable. Main risks: IP-address session table, Crystal Reports dependency, client-side transaction management, non-atomic numbering, and app-termination behaviour.
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

*Rating Key: 5 = Excellent 4 = Good 3 = Adequate 2 = Needs Work 1 = Poor*

**Overall Migration Complexity: MEDIUM-HIGH**

The screen\'s core business logic and database schema are sound and reusable. The primary migration effort lies in: (1) replacing client-side transaction management with a server-side atomic save API; (2) replacing Crystal Reports with a web PDF renderer; (3) eliminating the IP-address session pattern for purchase type segregation; (4) converting the VB6 ADO grid into a reactive web data table; (5) redesigning the application-terminating pending indent response; and (6) enforcing the disabled PO_PRL→PO_PRH foreign key in the new schema.
