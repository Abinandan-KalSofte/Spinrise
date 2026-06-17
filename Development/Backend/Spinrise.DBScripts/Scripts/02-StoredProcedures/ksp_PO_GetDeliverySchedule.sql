-- ============================================================
-- ksp_PO_GetDeliverySchedule
-- Returns delivery slot schedule for a given PO (divCode + poNo + poDate).
-- Source: PO_ORDL_DETL joined to PO_ORDL + IN_ITEM.
-- Delivery Schedule field order (CEO-confirmed Option B):
--   LineNo | ItemCode | ItemName | Uom | PrNo | PoQty |
--   SlotNo | ShDate | Qty | BalanceQty | Remarks
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetDeliverySchedule
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.PORDSNO                                                   AS [LineNo],
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(l.ORDqty, 0)                                         AS PoQty,
        ROW_NUMBER() OVER (PARTITION BY d.PORDSNO ORDER BY d.shdate) AS SlotNo,
        CASE WHEN d.shdate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(d.shdate AS DATE), 120) END AS ShDate,
        ISNULL(d.Quantity, 0)                                       AS Qty,
        ISNULL(l.ORDqty, 0) - ISNULL(
            (SELECT SUM(d2.Quantity)
             FROM dbo.PO_ORDL_DETL d2
             WHERE d2.divcode = d.divcode
               AND d2.pordno  = d.pordno
               AND CAST(d2.porddt AS DATE) = CAST(d.porddt AS DATE)
               AND d2.PORDSNO = d.PORDSNO), 0)                      AS BalanceQty,
        ''                                                          AS Remarks
    FROM dbo.PO_ORDL_DETL d
    INNER JOIN dbo.PO_ORDL l
        ON l.DIVCODE = d.divcode AND l.PORDNO = d.pordno
       AND CAST(l.PORDDT AS DATE) = CAST(d.porddt AS DATE)
       AND l.PORDSNO = d.PORDSNO
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE d.divcode = @DivCode
      AND d.pordno  = @PoNo
      AND CAST(d.porddt AS DATE) = @PoDate
    ORDER BY d.PORDSNO, d.shdate;
END;
GO
