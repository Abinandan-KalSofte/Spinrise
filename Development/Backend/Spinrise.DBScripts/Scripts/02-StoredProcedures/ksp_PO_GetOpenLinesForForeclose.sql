-- ============================================================
-- ksp_PO_GetOpenLinesForForeclose
-- Grid load for the PO Foreclosure screen (FN-PO-Foreclosure v1.4 §1/§2).
-- Loads ALL open PO lines across the division in one list (no PO picker),
-- ordered PORDDT, PORDNO, PORDSNO. Optional PO No. prefix filter.
-- Corrected load predicate (see FN §6 deviations):
--   Balance = ISNULL(ORDQTY,0)-ISNULL(RCVDQTY,0)-ISNULL(CANQTY,0) > 0
--   AND ISNULL(FCLOSED,'N') <> 'Y' AND ISNULL(LCANFLG,'') <> 'C'.
-- Returns POForeclosureLineDto { group, poNo, poDate, slCode, supplierName,
-- sNo, itemCode, itemName, balanceQty, prNo, prDate }.
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): CANQTY / LCANFLG / FCLOSED on PO_ORDL unverified.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetOpenLinesForForeclose
(
    @DivCode     VARCHAR(2),
    @PoNoPrefix  VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(ISNULL(h.POGRP, ''))    AS [Group],
            h.PORDNO                       AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120) AS PoDate,
            RTRIM(ISNULL(h.SLCODE, ''))    AS SlCode,
            RTRIM(ISNULL(s.SLNAME, ''))    AS SupplierName,
            CAST(l.PORDSNO AS INT)         AS SNo,
            RTRIM(l.ITEMCODE)              AS ItemCode,
            RTRIM(ISNULL(i.ITEMNAME, ''))  AS ItemName,
            ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0) - ISNULL(l.CANQTY, 0) AS BalanceQty,
            RTRIM(ISNULL(CONVERT(VARCHAR(20), l.PRNO), '')) AS PrNo,
            CONVERT(VARCHAR(10), l.PRDATE, 120)             AS PrDate
    FROM    PO_ORDL l
    INNER JOIN PO_ORDH h
            ON  h.DIVCODE = l.DIVCODE
            AND ISNULL(h.POGRP, '') = ISNULL(l.POGRP, '')
            AND h.PORDNO  = l.PORDNO
            AND h.PORDDT  = l.PORDDT
    LEFT JOIN FA_SLMAS s
            ON  s.SLCODE = h.SLCODE
    LEFT JOIN IN_ITEM i
            ON  i.ITEMCODE = l.ITEMCODE
    WHERE   l.DIVCODE = @DivCode
      AND   ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0) - ISNULL(l.CANQTY, 0) > 0
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
      AND   ISNULL(l.LCANFLG, '') <> 'C'
      AND   (@PoNoPrefix IS NULL
             OR CONVERT(VARCHAR(20), h.PORDNO) LIKE @PoNoPrefix + '%')
    ORDER BY h.PORDDT, h.PORDNO, l.PORDSNO;
END;
GO
