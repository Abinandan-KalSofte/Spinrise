-- ============================================================
-- ksp_PenPR_GetDeptWise
-- Pending PR Department-Wise report.
-- @DepCode = NULL returns all departments.
-- Pending predicate: FCLOSED <> 'y' AND (qtyreqd - qtyord) >= 1
-- Column aliases verified against PendingPrDeptWiseRowDto.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PenPR_GetDeptWise
    @DivCode  varchar(10),
    @FromDate datetime,
    @ToDate   datetime,
    @DepCode  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            dep.DEPCODE                                       AS DepCode,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            l.prno                                            AS PrNo,
            h.prdate                                          AS PrDate,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.reqddate                                        AS ReqdDate,
            l.remarks                                         AS Remarks,
            h.app3date                                        AS App3Date,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName,
            RTRIM(ISNULL(div.DIVNAME,       ''))             AS DivName
        FROM dbo.PO_PRH h
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        INNER JOIN dbo.IN_DEP dep
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
          AND (@DepCode IS NULL OR h.depcode = @DepCode)
        ORDER BY dep.DEPNAME, l.prno, h.prdate, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
