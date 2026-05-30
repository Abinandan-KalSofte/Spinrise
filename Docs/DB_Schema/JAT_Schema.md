# JAT Database Schema — Spinrise M01 (Purchase Requisition)

**Database:** JAT (on `172.16.16.52\sql2016`)
**Exported:** 2026-05-30
**Source:** INFORMATION_SCHEMA.COLUMNS query run directly on JAT

> ⚠️ This is the authoritative schema for ALL M01 SPs (`ksp_PR_*`).
> Do NOT use `SpinRiseSaranya_Schema.md` for M01 — it is a different database.

---

## Critical Column Rules (memorise)

| Rule | Detail |
|------|--------|
| `PP_PASSWD` user column | `user_id` (underscore) |
| `PP_PASSWD` level column | `alevel` |
| `PR_EMP` name column | `ename` |
| `PO_PRL` machine column | `macno` (varchar 5, no underscore) |
| `mm_macmas` machine column | `MAC_NO` (uppercase with underscore) |
| `PO_PRH` has NO prstatus | Never write `PO_PRH.prstatus` — column does not exist |
| `PO_PRL.prstatus` values | char(1): 'F'=First Approved, 'C'=Received, 'X'=Cancelled, 'Z'=Foreclosed, 'E'=Enquired, 'O'=Ordered |
| `IN_SCC` sub-cost centre key | `SCCCODE` numeric(6,0), name=`SCCNAME`, dept=`DEPCODE`, div=`Divcode` |
| `IN_SCC` cost centre link | `CC_Code` varchar(5) (not CCCODE) |
| `PO_IndentAppUser` columns | `Divcode`, `Depcode`, `UserID` |

---

## PO_PRH — PR Header

| Column | Type | Length / Precision | Nullable | Default |
|--------|------|--------------------|----------|---------|
| divcode | varchar | 2 | NO | — |
| prno | numeric(6,0) | — | NO | — |
| prdate | datetime | — | NO | — |
| depcode | varchar | 3 | YES | — |
| refno | varchar | 20 | YES | — |
| planno | numeric(6,0) | — | YES | — |
| plandt | datetime | — | YES | — |
| APPFLG | char(1) | — | YES | 'N' |
| ITYPE | char(1) | — | YES | — |
| SECTION | varchar | 20 | YES | — |
| PLACEOFISS | varchar | 30 | YES | — |
| APP2 | varchar | 10 | YES | — |
| APP3 | varchar | 10 | YES | — |
| APP1DATE | datetime | — | YES | — |
| APP2DATE | datetime | — | YES | — |
| APP3DATE | datetime | — | YES | — |
| APP1TIME | datetime | — | YES | — |
| APP2TIME | datetime | — | YES | — |
| APP3TIME | datetime | — | YES | — |
| APP1 | varchar | 10 | YES | — |
| REQNAME | varchar | 10 | YES | — |
| cancelflag | char(1) | — | YES | — |
| canceldt | datetime | — | YES | — |
| canreason | varchar | 250 | YES | — |
| amendno | numeric(5,0) | — | YES | — |
| scopecode | varchar | 2 | YES | — |
| alert_raised | varchar | 1 | YES | 'N' |
| userId | varchar | 50 | YES | — |
| SubCost | numeric(5,0) | — | YES | — |
| budgetBALAMT | numeric(18,2) | — | YES | — |
| PO_GRP | varchar | 5 | YES | — |
| createdby | varchar | 10 | YES | — |
| createddt | varchar | 50 | YES | — |
| row_version | timestamp | — | NO | — |
| pre_cancel_status | char(1) | — | YES | — |

**⚠️ PO_PRH has NO prstatus column.**

---

## PO_PRL — PR Line Items

| Column | Type | Length / Precision | Nullable | Default |
|--------|------|--------------------|----------|---------|
| divcode | varchar | 2 | NO | '02' |
| prno | numeric(6,0) | — | NO | — |
| prdate | datetime | — | NO | — |
| prsno | numeric(5,0) | — | NO | — |
| itemcode | varchar | 10 | NO | — |
| macno | varchar | 5 | YES | — |
| qtyind | numeric(12,3) | — | YES | — |
| qtyreqd | numeric(12,3) | — | YES | — |
| qtyord | numeric(12,3) | — | YES | — |
| qtyrec | numeric(12,3) | — | YES | — |
| reqddate | datetime | — | YES | — |
| prstatus | char(1) | — | YES | — |
| remarks | varchar | 50 | YES | — |
| pend_flag | char(1) | — | YES | — |
| slcode | varchar | 6 | YES | — |
| CCCODE | numeric(4,0) | — | YES | — |
| CATCODE | varchar | 1 | YES | — |
| REMARK1 | varchar | 25 | YES | — |
| RATE | numeric(13,4) | — | YES | — |
| VALUE | numeric(13,2) | — | YES | — |
| pino | decimal(6,0) | — | YES | — |
| pidate | datetime | — | YES | — |
| MAKPARTNO | varchar | 20 | YES | — |
| PLACE | varchar | 40 | YES | — |
| APPCOST | numeric(11,2) | — | YES | — |
| BGRPCODE | varchar | 4 | YES | — |
| BLCODE | varchar | 5 | YES | — |
| ITEMMEMO | varchar | 200 | YES | — |
| Enq_Qty | numeric(15,3) | — | YES | — |
| AUPFLAG | varchar | 1 | YES | — |
| curstock | numeric(12,3) | — | YES | — |
| LPO_RATE | numeric(13,4) | — | YES | — |
| LPO_DATE | datetime | — | YES | — |
| PUR_FROM | varchar | 8 | YES | — |
| AmdFlg | char(1) | — | YES | — |
| DirectApp | char(1) | — | YES | NULL |
| DirectAppDate | datetime | — | YES | — |
| Depcode | varchar | 3 | YES | — |
| FirstApp | char(1) | — | YES | — |
| SecondApp | char(1) | — | YES | — |
| ThirdApp | char(1) | — | YES | — |
| FirstAppQty | numeric(12,3) | — | YES | 0 |
| SecondAppQty | numeric(12,3) | — | YES | 0 |
| ThirdAppQty | numeric(12,3) | — | YES | 0 |
| AppQty1 | numeric(12,3) | — | YES | — |
| AppQty2 | numeric(12,3) | — | YES | — |
| AppQty3 | numeric(12,3) | — | YES | — |
| AppQty4 | numeric(12,3) | — | YES | — |
| FirstappUser | varchar | 35 | YES | — |
| SecondAppUser | varchar | 35 | YES | — |
| ThirdAppUser | varchar | 35 | YES | — |
| FinalAppUser | varchar | 35 | YES | — |
| FinalLevel_Remarks | varchar | 20 | YES | — |
| FinalAppQty | numeric(12,3) | — | YES | — |
| Sample | char(1) | — | YES | — |
| SubCost | numeric(5,0) | — | YES | — |
| FClosed | char(1) | — | YES | — |
| FCloseddt | datetime | — | YES | — |
| BeforeFinalLevelApp | char(1) | — | YES | — |
| BeforeFinalLevelAppDate | datetime | — | YES | — |
| BeforeFinalLevelAppUserID | varchar | 20 | YES | — |
| deletereason | varchar | 25 | YES | — |
| SecondAppremarks | varchar | 20 | YES | — |
| SecondAppdatetime | datetime | — | YES | — |
| row_version | timestamp | — | NO | — |

**prstatus values:** `'F'`=First Approved · `'C'`=Received · `'X'`=Cancelled · `'Z'`=Foreclosed · `'E'`=Enquired · `'O'`=Ordered

---

## PP_PASSWD — Users

| Column | Type | Nullable |
|--------|------|----------|
| divcode | varchar(2) | NO |
| user_id | varchar(5) | NO |
| alevel | decimal(3,0) | NO |
| password | varchar(10) | YES |
| user_name | varchar(35) | YES |
| module | numeric(2,0) | NO |
| activeflg | char(1) | YES |
| empid | varchar(15) | YES |

---

## PR_EMP — Employees

| Column | Type | Nullable |
|--------|------|----------|
| divcode | varchar(2) | NO |
| empno | decimal(5,0) | NO |
| depcode | varchar(3) | YES |
| ename | varchar(30) | NO |
| active | varchar(3) | YES |
| (+ many HR columns not relevant to PR) | | |

**Join pattern:** `TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno`

---

## IN_DEP — Departments

| Column | Type | Nullable |
|--------|------|----------|
| DEPCODE | varchar(3) | YES |
| DEPNAME | varchar(50) | YES |
| divcode | varchar(2) | YES |
| CCCODE | numeric(5,0) | YES |
| active | varchar(5) | YES |

---

## IN_ITEM — Item Master

| Column | Type | Nullable |
|--------|------|----------|
| ITEMCODE | varchar(10) | NO |
| ITEMNAME | varchar(70) | NO |
| UOM | varchar(3) | NO |
| MACNO | varchar(5) | YES |
| IsItemActive | char(2) | YES |
| (+ many other columns) | | |

---

## IN_SCC — Sub Cost Centre

| Column | Type | Nullable |
|--------|------|----------|
| SCCCODE | numeric(6,0) | NO |
| SCCNAME | varchar(40) | YES |
| DEPCODE | varchar(5) | NO |
| mastid | int | NO |
| Divcode | varchar(2) | NO |
| CC_Code | varchar(5) | YES |
| Active | varchar(5) | YES |

---

## mm_macmas — Machine Master

| Column | Type | Nullable |
|--------|------|----------|
| DIVCODE | varchar(2) | NO |
| DEPCODE | varchar(3) | NO |
| MAC_NO | varchar(5) | NO |
| DESCRIPTION | varchar(30) | YES |
| MACFLAG | char(1) | YES |
| MAC_CODE | varchar(5) | NO |
| IsActive | char(1) | YES | 'Y' |

---

## PO_IndentAppUser — Department Approver Mapping

| Column | Type | Nullable |
|--------|------|----------|
| Divcode | varchar(2) | NO |
| Depcode | varchar(3) | NO |
| UserID | varchar(6) | NO |
| ModDate | datetime | YES |

---

## LogDet_po — PR Audit Log

Key columns used in SP inserts:

| Column | Type | Notes |
|--------|------|-------|
| divcode | varchar(5) | NO |
| prno | numeric(15,0) | YES |
| prdate | datetime | YES |
| prsno | numeric(15,0) | YES |
| depcode | varchar(50) | YES |
| itemcode | varchar(250) | YES |
| macno | varchar(5) | YES |
| qtyreqd | numeric(12,3) | YES |
| qtyrec | numeric(12,3) | YES |
| prstatus | char(1) | YES |
| FClosed | char(1) | YES |
| FCloseddt | datetime | YES |
| Trans_UserId | varchar(50) | YES |
| Trans_date | datetime | YES |
| Trans_Name | varchar(100) | YES |
| Trans_Mod | varchar(20) | YES |
| Trans_IPADD | varchar(50) | YES |
| Trans_Host | varchar(50) | YES |
| username | varchar(50) | YES |
| Quantity | numeric(15,0) | YES |
| Activity | varchar(20) | YES |
| Modifiedby | varchar(100) | YES |
| ModifyDate | datetime | YES |
