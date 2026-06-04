CREATE OR ALTER PROCEDURE ksp_PR_GetCancellablePRs
    @divcode varchar(10),
    @yfdate  datetime,
    @yldate  datetime
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            a.prno                                        AS PrNo,
            ISNULL(CONVERT(varchar(12), a.prdate, 106),'') AS PRDate,
            RTRIM(ISNULL(a.depcode, ''))                  AS DepCode,
            RTRIM(ISNULL(c.Depname, ''))                  AS Department,
            RTRIM(ISNULL(a.reqname, ''))                  AS Requester,
            (SELECT COUNT(*)
               FROM PO_PRL x
              WHERE x.prno    = a.prno
                AND x.prdate  = a.prdate
                AND x.divcode = a.divcode)                 AS ItemCount,
            RTRIM(ISNULL(a.refno,   ''))                  AS RefNo,
            RTRIM(ISNULL(t.idesc, ISNULL(a.ITYPE, '')))   AS PRType,
            RTRIM(ISNULL(a.section, ''))                  AS Section,
            RTRIM(ISNULL(a.reqname, ''))                  AS CreatedBy,
            RTRIM(ISNULL(
                (SELECT TOP 1 PRSTATUS
                   FROM PO_PRL x
                  WHERE x.prno    = a.prno
                    AND x.prdate  = a.prdate
                    AND x.divcode = a.divcode
                  ORDER BY x.prsno),
            ''))                                           AS Status
        FROM  PO_PRH a
        INNER JOIN In_dep        c ON c.depcode = a.depcode
                                   AND c.divcode = a.divcode
        LEFT  JOIN PO_INDENTTYPE t ON t.itype   = a.ITYPE
        WHERE a.divcode = @divcode
          AND ISNULL(a.cancelflag, '') <> 'Y'            -- fix: was 'IS NULL', live DB stores 'N'
          AND ISNULL(a.APPFLG, 'N') <> 'Y'              -- only un-approved PRs can be cancelled
          AND a.prdate BETWEEN @yfdate AND @yldate
          AND NOT EXISTS (
              SELECT 1 FROM PO_ENQL x
               WHERE x.prno    = a.prno
                 AND x.prdate  = a.prdate
                 AND x.divcode = a.divcode)
          -- PO_ORD check: confirm actual PO order table name before enabling
          -- AND NOT EXISTS (SELECT 1 FROM <po_order_table> x WHERE x.prno=a.prno AND x.divcode=a.divcode)
          AND NOT EXISTS (
              SELECT 1 FROM PO_PRL x
               WHERE x.prno    = a.prno
                 AND x.prdate  = a.prdate
                 AND x.divcode = a.divcode
                 AND ISNULL(x.QTYORD, 0) > 0)
        ORDER BY a.prdate DESC, a.prno DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
