-- ============================================================
-- ksp_PR_DeptWise_Report
-- Returns PR lines for the Department-Wise PDF report.
-- Groups by department in the application layer (QuestPDF document).
-- @DepCode = NULL returns all departments.
-- Column names verified against SpinRiseSaranya_Schema.md.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_DeptWise_Report
    @Divcode  varchar(2),
    @FromDate datetime,
    @ToDate   datetime,
    @DepCode  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.divcode                                         AS DivCode,
            h.depcode                                         AS DepCode,
            RTRIM(ISNULL(dep.DEPNAME, ''))                   AS DepName,
            l.prno                                            AS PrNo,
            l.prdate                                          AS PrDate,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.prstatus                                        AS PrStatusCode,
            l.SecondApp                                       AS SecondApp,
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
        INNER JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @Divcode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND (@DepCode IS NULL OR h.depcode = @DepCode)
        ORDER BY dep.DEPNAME, l.prno, l.prdate, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
