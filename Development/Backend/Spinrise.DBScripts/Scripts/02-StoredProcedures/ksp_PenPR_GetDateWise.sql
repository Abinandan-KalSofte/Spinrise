-- ============================================================
-- ksp_PenPR_GetDateWise
-- Pending PR Date-Wise report.
-- Pending predicate: FCLOSED <> 'y' AND (qtyreqd - qtyord) >= 1
-- Column aliases verified against PendingPrDateWiseRowDto.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PenPR_GetDateWise
    @DivCode  varchar(10),
    @FromDate datetime,
    @ToDate   datetime
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.prno                                            AS PrNo,
            h.prdate                                          AS PrDate,
            h.app3date                                        AS App3Date,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.reqddate                                        AS ReqdDate,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName
        FROM dbo.PO_PRH h
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        LEFT  JOIN dbo.IN_DEP dep
            ON  h.depcode = dep.DEPCODE
            AND h.divcode = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.divcode = div.DIVCODE
        LEFT  JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @DivCode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND ISNULL(l.FCLOSED, 'N') <> 'y'
          AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0)) >= 1
        ORDER BY h.prdate, l.prno, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
