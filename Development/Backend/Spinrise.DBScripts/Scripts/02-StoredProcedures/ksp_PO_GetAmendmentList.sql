-- ============================================================
-- ksp_PO_GetAmendmentList
-- Find mode (FN-PO-Amendment v1.2 §1): lists SAVED amendments for the year,
-- view-only. Sourced from the amendment SNAPSHOT header PO_AORDH — one row per
-- amendment EVENT (a PO amended three times has three rows here), which is what
-- makes the AMDORDNO MAX(...)+1 allocation in ksp_PO_AmendOrder meaningful.
--
-- Result maps to AmendmentSummaryDto { DivCode, PoNo, PoDate, PoGroup, AmdNo,
-- AmdDate, Supplier, SupplierName, OrderValue } — Dapper binds BY NAME.
--
-- AMDORDNO is stored as a character column in legacy data (hence the SP's use of
-- CONVERT(INT, ...) when allocating). T-0119 addendum item (d) verified on both
-- JAT and SCMTS that ZERO non-numeric AMDORDNO values exist, so the TRY_CONVERT
-- below cannot silently drop rows on current data; TRY_ (not CONVERT) is used so
-- that a future bad row degrades to NULL in the list rather than failing the
-- whole query.
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm used inline ADO.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAmendmentList
(
    @DivCode VARCHAR(2),
    @YFDate  DATE = NULL,
    @YLDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(a.DIVCODE)                            AS DivCode,
            a.PORDNO                                    AS PoNo,
            CONVERT(VARCHAR(10), a.PORDDT, 120)         AS PoDate,
            RTRIM(ISNULL(a.POGRP, ''))                  AS PoGroup,
            ISNULL(TRY_CONVERT(INT, a.AMDORDNO), 0)     AS AmdNo,
            CONVERT(VARCHAR(10), a.AMDORDDT, 120)       AS AmdDate,
            RTRIM(ISNULL(a.SLCODE, ''))                 AS Supplier,
            RTRIM(ISNULL(s.SLNAME, ''))                 AS SupplierName,
            ISNULL(a.ORDVAL, 0)                         AS OrderValue
    FROM    PO_AORDH a
    LEFT JOIN FA_SLMAS s ON s.SLCODE = a.SLCODE
    WHERE   a.DIVCODE = @DivCode
      AND   (@YFDate IS NULL OR CAST(a.PORDDT AS DATE) >= @YFDate)
      AND   (@YLDate IS NULL OR CAST(a.PORDDT AS DATE) <= @YLDate)
    ORDER BY a.AMDORDDT DESC, a.PORDNO DESC, TRY_CONVERT(INT, a.AMDORDNO) DESC;
END;
GO
