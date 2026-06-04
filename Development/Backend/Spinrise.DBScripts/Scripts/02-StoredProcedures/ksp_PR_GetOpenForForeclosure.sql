CREATE OR ALTER PROCEDURE ksp_PR_GetOpenForForeclosure
    @divcode      varchar(10),
    @fdate        date,
    @ldate        date,
    @prno_filter  varchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            a.prno                                        AS PrNo,
            -- PO_PRH.prdate may be NULL on legacy records; fall back to PO_PRL.prdate
            ISNULL(CONVERT(varchar(12), ISNULL(a.prdate, b.prdate), 106), '') AS PRDate,
            RTRIM(ISNULL(c.Depname, ''))                  AS Department,
            RTRIM(ISNULL(a.depcode, ''))                  AS DepCode,
            CAST(ISNULL(b.prsno, 0) AS INT)               AS PrSno,
            RTRIM(b.itemcode)                             AS ItemCode,
            RTRIM(ISNULL(d.Itemname, ''))                 AS ItemName,
            RTRIM(ISNULL(d.UOM, ''))                      AS UOM,
            ISNULL(b.QTYREQD, 0)                         AS PrQty,
            ISNULL(b.QTYORD,  0)                         AS OrdQty,
            ISNULL(b.QTYREQD, 0)
                - ISNULL(b.QTYORD,  0)
                - ISNULL(b.enq_qty, 0)                    AS Balance,
            RTRIM(ISNULL(e.MAC_NO, ''))                   AS SccCode,
            RTRIM(ISNULL(e.DESCRIPTION, ISNULL(e.MAC_NO, ''))) AS SccName,
            -- Convert raw PRSTATUS char to readable label matching the HTML prototype badges
            CASE RTRIM(ISNULL(b.PRSTATUS, ''))
                WHEN 'F' THEN 'First Approved'
                WHEN 'E' THEN 'Enquired'
                WHEN 'C' THEN 'Received'
                WHEN 'X' THEN 'Cancelled'
                WHEN 'Z' THEN 'Force Closed'
                WHEN 'O' THEN
                    CASE WHEN ISNULL(b.QTYORD, 0) > 0 THEN 'Ordered' ELSE 'Order Cancelled' END
                ELSE 'Requested'
            END                                           AS PrevStatus
        FROM  PO_PRH   a
        INNER JOIN PO_PRL    b ON b.prno    = a.prno
                               AND b.divcode = a.divcode
        INNER JOIN In_dep    c ON c.depcode  = a.depcode
                               AND c.divcode  = a.divcode
        INNER JOIN in_item   d ON d.itemcode  = b.itemcode
        LEFT  JOIN MM_MACMAS e ON e.MACFLAG  = 'M'
                               AND e.DIVCODE  = b.divcode
                               AND e.DEPCODE  = b.depcode
                               AND e.MAC_NO   = b.macno
        WHERE a.divcode = @divcode
          AND CAST(ISNULL(a.prdate, b.prdate) AS DATE) BETWEEN @fdate AND @ldate
          AND ISNULL(a.cancelflag, '') <> 'Y'          -- fix: was 'IS NULL', live DB stores 'N'
          AND ISNULL(b.FClosed, 'N') <> 'Y'
          AND RTRIM(ISNULL(b.prstatus, '')) NOT IN ('O','E','C','Z','X')   -- FC-EX-09/BR-03: exclude Ordered/Enquired/Received/ForceClosed/Cancelled
          AND (ISNULL(b.QTYREQD, 0) - ISNULL(b.QTYORD, 0) - ISNULL(b.enq_qty, 0)) > 0
          AND (ISNULL(b.QTYORD, 0) - ISNULL(b.qtyrec, 0)) >= 0
          AND (@prno_filter IS NULL
               OR CAST(a.prno AS varchar(20)) LIKE @prno_filter + '%')
        ORDER BY a.prdate, a.prno, b.prsno;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
