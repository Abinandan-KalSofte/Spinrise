-- ============================================================
-- ksp_PO_GetOpenPOList
-- Open-PO lookup for the PO Cancellation picker (FN-PO-Cancellation v1.4 §1).
-- Lists distinct POs that still have at least one open line:
--   ISNULL(RCVDQTY,0) + ISNULL(CANQTY,0) < ISNULL(ORDQTY,0)
--   AND LCANFLG <> 'C' AND ISNULL(FCLOSED,'N') <> 'Y'
-- Scoped to the caller's division. Optional FY-bound filter on PORDDT.
--
-- NOTE (11-Jul-2026): the shipped Cancellation picker (PoListModal.tsx) currently
-- reuses the generic ksp_PO_GetPOList endpoint, so this SP is not yet wired to a
-- C# endpoint — it is delivered per FN §5 as the correct open-only lookup source
-- for when the picker is retargeted. No frontend/controller change is made here
-- (frozen contract).
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): CANQTY / LCANFLG / FCLOSED on PO_ORDL presumed
--    legacy but unverified from the repo.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetOpenPOList
(
    @DivCode VARCHAR(2),
    @YFDate  DATE = NULL,
    @YLDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
            h.PORDNO                       AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120) AS PoDate,
            RTRIM(ISNULL(h.SLCODE, ''))    AS SlCode,
            RTRIM(ISNULL(s.SLNAME, ''))    AS SupplierName,
            RTRIM(ISNULL(h.POGRP, ''))     AS PoGrp
    FROM    PO_ORDH h
    INNER JOIN PO_ORDL l
            ON  l.DIVCODE = h.DIVCODE
            AND ISNULL(l.POGRP, '') = ISNULL(h.POGRP, '')
            AND l.PORDNO  = h.PORDNO
            AND l.PORDDT  = h.PORDDT
    LEFT JOIN FA_SLMAS s
            ON  s.SLCODE = h.SLCODE
    WHERE   h.DIVCODE = @DivCode
      AND   ISNULL(l.RCVDQTY, 0) + ISNULL(l.CANQTY, 0) < ISNULL(l.ORDQTY, 0)
      AND   ISNULL(l.LCANFLG, '') <> 'C'
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
      AND   (@YFDate IS NULL OR CAST(h.PORDDT AS DATE) >= @YFDate)
      AND   (@YLDate IS NULL OR CAST(h.PORDDT AS DATE) <= @YLDate)
    -- SELECT DISTINCT permits only select-list items in ORDER BY.
    -- PoDate is YYYY-MM-DD, so the string sort is chronological.
    ORDER BY PoDate DESC, PoNo DESC;
END;
GO
