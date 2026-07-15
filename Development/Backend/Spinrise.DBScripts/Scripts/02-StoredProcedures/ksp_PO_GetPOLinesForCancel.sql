-- ============================================================
-- ksp_PO_GetPOLinesForCancel
-- Grid load for a selected PO on the Cancellation screen
-- (FN-PO-Cancellation v1.4 §2 / §3.3). Returns the open lines of one PO
-- mapped to POCancellationLineDto { slCode, itemCode, sNo, itemName, uom,
-- orderQty, receivedQty, rate, value }.
-- Open-line predicate identical to the picker:
--   ISNULL(RCVDQTY,0)+ISNULL(CANQTY,0) < ISNULL(ORDQTY,0)
--   AND LCANFLG <> 'C' AND ISNULL(FCLOSED,'N') <> 'Y'.
-- Balance is computed client- and server-side as ORDQTY-RCVDQTY-CANQTY;
-- receivedQty here is the raw RCVDQTY per the FN column map.
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): CANQTY / LCANFLG / FCLOSED on PO_ORDL unverified.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOLinesForCancel
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(ISNULL(h.SLCODE, ''))  AS SlCode,
            RTRIM(l.ITEMCODE)            AS ItemCode,
            CAST(l.PORDSNO AS INT)       AS SNo,
            RTRIM(ISNULL(i.ITEMNAME, '')) AS ItemName,
            RTRIM(ISNULL(i.UOM, ''))     AS Uom,
            ISNULL(l.ORDQTY, 0)          AS OrderQty,
            ISNULL(l.RCVDQTY, 0)         AS ReceivedQty,
            ISNULL(l.RATE, 0)            AS Rate,
            ISNULL(l.ORDVAL, 0)          AS Value
    FROM    PO_ORDL l
    INNER JOIN PO_ORDH h
            ON  h.DIVCODE = l.DIVCODE
            AND ISNULL(h.POGRP, '') = ISNULL(l.POGRP, '')
            AND h.PORDNO  = l.PORDNO
            AND h.PORDDT  = l.PORDDT
    LEFT JOIN IN_ITEM i
            ON  i.ITEMCODE = l.ITEMCODE
    WHERE   l.DIVCODE = @DivCode
      AND   l.PORDNO  = @PoNo
      AND   CAST(l.PORDDT AS DATE) = @PoDate
      AND   ISNULL(l.RCVDQTY, 0) + ISNULL(l.CANQTY, 0) < ISNULL(l.ORDQTY, 0)
      AND   ISNULL(l.LCANFLG, '') <> 'C'
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
    ORDER BY l.PORDSNO;
END;
GO
