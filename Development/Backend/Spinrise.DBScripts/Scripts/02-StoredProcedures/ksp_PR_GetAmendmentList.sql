-- ============================================================
-- ksp_PR_GetAmendmentList
-- Returns amendments for a division within a date range.
-- PO_PRH is deleted after the first amendment — LEFT JOIN used;
-- depcode/REQNAME fall back to PO_APRH columns stored on ADD.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentList]
    @DivCode    VARCHAR(10),
    @FDate      DATE,
    @LDate      DATE,
    @PrNo       NUMERIC(6,0)    = NULL,
    @Search     NVARCHAR(100)   = NULL,
    @PageNumber INT             = 1,
    @PageSize   INT             = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.divcode,
        a.prno,
        CONVERT(VARCHAR(10), CONVERT(DATE, a.prdate,    103), 103)   AS prDate,
        CAST(a.amendno AS INT)                                       AS amendno,
        CONVERT(VARCHAR(10), CONVERT(DATE, a.amenddate, 103), 103)   AS amendDate,
        ISNULL(a.amendreason,  '')                                   AS amendmentReason,
        ISNULL(a.refno,        '')                                   AS refNo,
        ISNULL(a.depcode,    ISNULL(h.depcode,    ''))               AS depCode,
        ISNULL(d.Depname, ISNULL(a.depcode, h.depcode))              AS depName,
        ISNULL(a.REQNAME,    ISNULL(h.REQNAME,    ''))               AS reqName,
        ISNULL(a.createdby, ISNULL(h.createdby, ''))                 AS createdby,
        (
            SELECT COUNT(*) FROM dbo.PO_APRL l2
            WHERE l2.divcode                          = a.divcode
              AND l2.prno                             = a.prno
              AND CONVERT(DATE, l2.prdate, 103)       = CONVERT(DATE, a.prdate, 103)
              AND l2.amendno                          = a.amendno
        )                                                            AS totalLines
    FROM   dbo.PO_APRH a
    LEFT JOIN dbo.PO_PRH h  ON  h.divcode                        = a.divcode
                            AND h.prno                           = a.prno
                            AND CAST(h.prdate AS DATE)           = CONVERT(DATE, a.prdate, 103)
    LEFT JOIN dbo.IN_DEP d  ON  d.divcode = a.divcode
                            AND d.depcode = ISNULL(a.depcode, h.depcode)
    WHERE  a.divcode = @DivCode
      AND  CONVERT(DATE, a.amenddate, 103) BETWEEN @FDate AND @LDate
      AND  (@PrNo   IS NULL OR a.prno = @PrNo)
      AND  (
               @Search IS NULL
            OR RTRIM(CAST(a.prno AS VARCHAR)) LIKE '%' + @Search + '%'
            OR ISNULL(a.amendreason, '')     LIKE '%' + @Search + '%'
            OR ISNULL(d.Depname,     '')     LIKE '%' + @Search + '%'
           )
    ORDER BY a.amendno ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH  NEXT @PageSize ROWS ONLY;
END;
GO
