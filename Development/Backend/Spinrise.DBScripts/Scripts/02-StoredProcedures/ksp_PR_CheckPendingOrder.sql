-- ============================================================
-- ksp_PR_CheckPendingOrder
-- Mirrors KSP_INDEDNT_CHECK. Called on item code entry
-- when PendingOrderPara = 'Y'.
-- Returns pending qty > 0 if an open PO exists for the
-- same item + dept in the financial year.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_CheckPendingOrder
(
    @DivCode  VARCHAR(2),
    @FDate    DATE,
    @LDate    DATE,
    @DepCode  VARCHAR(3),
    @ItemCode VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SUM(ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0)) AS PendingQty
    FROM dbo.PO_ORDH h
    INNER JOIN dbo.PO_ORDL l
        ON l.divcode = h.divcode
       AND l.pordno  = h.pordno
       AND l.porddt  = h.porddt
    WHERE h.divcode             = @DivCode
      AND ISNULL(h.CANFLG, 'N') = 'N'        -- BR-1: non-cancelled POs only
      AND ISNULL(l.FClosed, 'N') <> 'Y'      -- BR-2: open lines only
      AND l.DepCode              = @DepCode   -- BR-3: same department
      AND l.ITEMCODE             = @ItemCode  -- BR-4: exact item
      AND CAST(l.PRDATE AS DATE) BETWEEN @FDate AND @LDate  -- BR-5: current FY
    HAVING SUM(ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0)) > 0;  -- BR-6: pending > 0
END;
GO
