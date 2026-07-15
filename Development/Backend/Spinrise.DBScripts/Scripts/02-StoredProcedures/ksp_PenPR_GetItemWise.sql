-- ============================================================
-- ksp_PenPR_GetItemWise
-- Pending PR Item-Wise report.
-- @FItem / @TItem: empty string = all items; code = range/single.
-- Single: FItem = TItem = itemcode
-- All / multiple: FItem = '' , TItem = '' (post-filter in app layer for multi-select)
-- Pending predicate: FCLOSED <> 'y' AND (qtyreqd - qtyord) >= 1
-- Column aliases verified against PendingPrItemWiseRowDto.
-- PrStatus decoded in the application layer (DecodePrStatus).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PenPR_GetItemWise
    @DivCode  varchar(10),
    @FromDate datetime,
    @ToDate   datetime,
    @FItem    varchar(50) = '',
    @TItem    varchar(50) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            l.prno                                            AS IndentNo,
            h.prdate                                          AS IndentDt,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            dep.DEPCODE                                       AS DepCode,
            RTRIM(ISNULL(div.DIVNAME,  ''))                  AS DivName,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Unit,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrd,
            ISNULL(l.qtyrec,  0)                             AS QtyRec,
            l.prstatus                                        AS PrStatusCode,
            l.SecondApp                                       AS SecondApp,
            h.refno                                           AS RefNo,
            l.remarks                                         AS Remarks,
            l.reqddate                                        AS ReqdDate,
            h.placeofiss                                      AS PlaceOfIss
        FROM dbo.PO_PRH h
        LEFT  JOIN dbo.IN_DEP dep
            ON  h.depcode = dep.DEPCODE
            AND h.divcode = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.divcode = div.DIVCODE
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        LEFT  JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @DivCode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND ISNULL(l.FCLOSED, 'N') <> 'y'
          AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0)) >= 1
          AND (ISNULL(@FItem, '') = '' OR l.itemcode >= @FItem)
          AND (ISNULL(@TItem, '') = '' OR l.itemcode <= @TItem)
        ORDER BY l.itemcode, l.prno, h.prdate;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
