-- ============================================================
-- LT-01 schema gate — PO Cancellation & Foreclosure (Sprint 2B, FN v1.4)
-- READ-ONLY. Run on live JAT BEFORE deploying the 6 new SPs from merged_jat.sql.
-- Confirms the legacy VB6 columns/tables the SPs assume exist, and that the 6 new
-- SP names are free of any conflicting legacy owner.
--
-- SCOPE: JAT ONLY. SCMTS was removed from M01 pilot scope by CEO on 10-Jul-2026
-- (QA OBS-01, 11-Jul) — do NOT run this against SCMTS.
--
-- Every row below should return a value / 'OK'. A NULL data_type or a
-- "MISSING" flag = a real gap: STOP and raise to Sasi/CEO before executing
-- merged_jat.sql on that DB. (G2/G4 in the build planner.)
--
-- RESULT — run on JAT 11-Jul-2026: GATE CLEAN. All 6 cancel/foreclose columns
-- present, PO_CANCELREASON present, PO_PRL + LogDet_PO complete, POGRP never NULL.
-- Full verdict: Docs/Audits/LT-01_PCF_JAT_20260711/LT-01_RESULT.md
-- ============================================================
SET NOCOUNT ON;
PRINT '=== DB: ' + DB_NAME() + ' ===';

-- 1. PO_ORDL cancel/foreclose columns (the SP writes/reads these) --------------
PRINT '--- PO_ORDL columns (expect one row each with a data_type) ---';
SELECT c.name AS column_name, t.name AS data_type, c.max_length, c.precision, c.scale
FROM   sys.columns c
JOIN   sys.types  t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID('dbo.PO_ORDL')
  AND  c.name IN ('LCANFLG','LCANDT','LCANCELCODE','CANQTY','FCLOSED','FCLOSEDDT',
                  'ORDQTY','RCVDQTY','PRNO','PRDATE','PRSNO','POGRP','PORDNO','PORDDT','PORDSNO','ITEMCODE')
ORDER BY c.name;

PRINT '--- PO_ORDL: any REQUIRED cancel/foreclose column MISSING? ---';
SELECT req.col AS missing_column, 'MISSING' AS status
FROM (VALUES ('LCANFLG'),('LCANDT'),('LCANCELCODE'),('CANQTY'),('FCLOSED'),('FCLOSEDDT')) req(col)
WHERE NOT EXISTS (
    SELECT 1 FROM sys.columns c
    WHERE c.object_id = OBJECT_ID('dbo.PO_ORDL') AND c.name = req.col);

-- 2. PO_PRL backflush columns --------------------------------------------------
PRINT '--- PO_PRL backflush key columns (QTYORD/PRNO/PRDATE/PRSNO/ITEMCODE/DIVCODE) ---';
SELECT c.name AS column_name, t.name AS data_type
FROM   sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID('dbo.PO_PRL')
  AND  c.name IN ('QTYORD','PRNO','PRDATE','PRSNO','ITEMCODE','DIVCODE')
ORDER BY c.name;

-- 3. PO_CANCELREASON lookup table + Code/Reason columns ------------------------
PRINT '--- PO_CANCELREASON table + columns (expect table id + Code/Reason) ---';
SELECT OBJECT_ID('dbo.PO_CANCELREASON') AS po_cancelreason_object_id;
SELECT c.name AS column_name, t.name AS data_type
FROM   sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID('dbo.PO_CANCELREASON')
ORDER BY c.column_id;

-- 4. LogDet_PO audit columns the SPs insert into -------------------------------
PRINT '--- LogDet_PO columns used by the audit inserts ---';
SELECT c.name AS column_name, t.name AS data_type
FROM   sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID('dbo.LogDet_PO')
  AND  c.name IN ('divcode','pordno','porddt','prno','prdate','prsno','itemcode',
                  'Quantity','username','Trans_UserId','Trans_date','Trans_Name',
                  'Trans_Mod','Trans_IPADD','Trans_Host','moduleNo','Reason')
ORDER BY c.name;

-- 5. POGRP NULL/blank audit (informs the ISNULL(POGRP,'') matching) ------------
PRINT '--- PO_ORDL POGRP NULL/blank counts (informational) ---';
SELECT SUM(CASE WHEN POGRP IS NULL THEN 1 ELSE 0 END)               AS null_pogrp,
       SUM(CASE WHEN RTRIM(ISNULL(POGRP,'')) = '' THEN 1 ELSE 0 END) AS null_or_blank_pogrp,
       COUNT(*)                                                      AS total_lines
FROM   dbo.PO_ORDL;

-- 6. Confirm the 6 new SP names are free of a conflicting legacy owner ----------
--    (If a row returns for a name, that SP already exists — review before ALTER.)
PRINT '--- Existing SPs with our 6 target names (rows here = pre-existing owner) ---';
SELECT name, create_date, modify_date
FROM   sys.procedures
WHERE  name IN ('ksp_PO_GetCancelReasons','ksp_PO_GetOpenPOList','ksp_PO_GetPOLinesForCancel',
                'ksp_PO_GetOpenLinesForForeclose','ksp_PO_CancelLines','ksp_PO_ForeCloseLines')
ORDER BY name;

PRINT '=== LT-01 gate check complete for ' + DB_NAME() + ' ===';
GO
