-- ============================================================
-- ksp_PO_GetAmendablePOList
-- Amendable-PO lookup for the PO Amendment picker (FN-PO-Amendment v1.2 §1).
--
-- Predicate is AmdAfterGRN-driven (PO_PARA.AmdAfterGRN), resolved INSIDE the SP —
-- the client never sends it:
--   AmdAfterGRN = 'Y'  → line-level: Balance > 0
--                        AND ISNULL(FCLOSED,'N') <> 'Y'
--                        AND ISNULL(LCANFLG,'')  <> 'C'
--                        AND header CANFLG IS NULL AND CANDT IS NULL
--        where Balance = ISNULL(ORDQTY,0) - ISNULL(RCVDQTY,0) - ISNULL(CANQTY,0)
--        (same corrected formula as Foreclosure §1; VB6 omitted the LCANFLG
--         exclusion — FN §6 deviation, deliberately NOT reproduced).
--   else               → only POs with NO receipts at all on any line
--                        (ISNULL(RCVDQTY,0) = 0) AND ISNULL(FCLOSED,'N') <> 'Y'.
--
-- Result maps to AmendablePoSummaryDto { DivCode, PoNo, PoDate, PoGroup,
-- Supplier, SupplierName, OrderValue, TotalLines } — Dapper binds BY NAME, so the
-- aliases below are a contract: do not rename without changing the DTO.
--
-- Date is returned as CONVERT(VARCHAR(10),...,120) and counts as INT — the DTOs
-- expect string/int. (T-0156: a DATE/NUMERIC column against a string/int property
-- fails Dapper materialisation at runtime.)
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm used inline ADO
-- SQL, not a procedure.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT — the read-only SQL login is down. Run
--    PARSEONLY / deploy on JAT before use.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAmendablePOList
(
    @DivCode VARCHAR(2),
    @YFDate  DATE = NULL,
    @YLDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_PARA is division-scoped; default to 'N' (stricter branch) when absent,
    -- so a missing parameter row can never widen the eligible set by accident.
    DECLARE @AmdAfterGRN CHAR(1);
    SELECT TOP 1 @AmdAfterGRN = UPPER(RTRIM(ISNULL(AmdAfterGRN, 'N')))
    FROM   PO_PARA
    WHERE  DIVCODE = @DivCode;
    SET @AmdAfterGRN = ISNULL(@AmdAfterGRN, 'N');

    SELECT  RTRIM(h.DIVCODE)                    AS DivCode,
            h.PORDNO                            AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120) AS PoDate,
            RTRIM(ISNULL(h.POGRP, ''))          AS PoGroup,
            RTRIM(ISNULL(h.SLCODE, ''))         AS Supplier,
            RTRIM(ISNULL(s.SLNAME, ''))         AS SupplierName,
            ISNULL(h.ORDVAL, 0)                 AS OrderValue,
            -- CAST to INT: the DTO property is int. COUNT_BIG/BIGINT here would
            -- fail Dapper materialisation at runtime (the T-0156 failure class).
            CAST(COUNT(l.PORDSNO) AS INT)       AS TotalLines
    FROM    PO_ORDH h
    INNER JOIN PO_ORDL l
            ON  l.DIVCODE = h.DIVCODE
            AND ISNULL(l.POGRP, '') = ISNULL(h.POGRP, '')
            AND l.PORDNO  = h.PORDNO
            AND l.PORDDT  = h.PORDDT
    LEFT JOIN FA_SLMAS s
            ON  s.SLCODE = h.SLCODE
    WHERE   h.DIVCODE = @DivCode
      -- Header-level exclusion: a cancelled PO is never amendable (both branches).
      AND   h.CANFLG IS NULL
      AND   h.CANDT  IS NULL
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
      AND   (
              (   @AmdAfterGRN = 'Y'
              AND ISNULL(l.LCANFLG, '') <> 'C'
              AND ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0) - ISNULL(l.CANQTY, 0) > 0
              )
              OR
              (   @AmdAfterGRN <> 'Y'
              AND ISNULL(l.RCVDQTY, 0) = 0
              )
            )
      AND   (@YFDate IS NULL OR CAST(h.PORDDT AS DATE) >= @YFDate)
      AND   (@YLDate IS NULL OR CAST(h.PORDDT AS DATE) <= @YLDate)
    GROUP BY h.DIVCODE, h.PORDNO, h.PORDDT, h.POGRP, h.SLCODE, s.SLNAME, h.ORDVAL
    ORDER BY h.PORDDT DESC, h.PORDNO DESC;
END;
GO
