-- ============================================================
-- ksp_PR_GetList
-- Returns PR list for Find / Modify / Delete lookups.
-- Modify/Delete: excludes approved, cancelled, amended PRs.
-- Find: returns all (read-only view).
-- Supports date range, dept, requester, order type filters.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetList
(
    @DivCode       VARCHAR(2),
    @FDate         DATE,
    @LDate         DATE,
    @Mode          VARCHAR(10) = 'FIND',  -- FIND | MODIFY | DELETE
    @StatusFilter  VARCHAR(30) = NULL,
    @DepCode       VARCHAR(3)  = NULL,
    @ReqName       VARCHAR(10) = NULL,
    @PoGrp         VARCHAR(5)  = NULL,
    @PageNumber    INT         = 1,
    @PageSize      INT         = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(h.divcode)                AS DivCode,
        h.prno                          AS PrNo,
        CAST(h.prdate AS DATE)          AS PrDate,
        RTRIM(ISNULL(h.depcode,''))     AS DepCode,
        RTRIM(ISNULL(d.depname,''))     AS DepName,
        RTRIM(ISNULL(h.REQNAME,''))     AS ReqName,
        RTRIM(ISNULL(e.ename,  ''))     AS ReqEmpName,
        RTRIM(ISNULL(h.ITYPE,  ''))     AS IType,
        RTRIM(ISNULL(it.IDESC, ''))     AS IDesc,
        RTRIM(ISNULL(h.PO_GRP,''))      AS PoGrp,
        ISNULL(h.APPFLG, 'N')           AS AppFlg,
        -- PR Status: derived from PO_PRL line-level prstatus (not a PO_PRH column)
        CASE
            WHEN ISNULL(h.cancelflag, '') <> ''
                THEN 'PR. CANCELLED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='O' AND ISNULL(lx.qtyord,0)>0)
                THEN 'ORDERED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='O')
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='E')
                THEN 'ENQUIRED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='C')
                THEN 'RECEIVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            ELSE 'REQUESTED'
        END                             AS PrStatus,
        (SELECT COUNT(*) FROM dbo.PO_PRL lc
         WHERE lc.divcode=h.divcode AND lc.prno=h.prno AND lc.prdate=h.prdate
           AND ISNULL(lc.AmdFlg,'') <> 'Y') AS TotalLines
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PR_EMP e
        ON CAST(e.empno AS VARCHAR(10)) = h.REQNAME
    LEFT JOIN dbo.PO_INDENTTYPE it
        ON it.ITYPE = h.ITYPE
    WHERE h.divcode = @DivCode
      AND CAST(h.prdate AS DATE) BETWEEN @FDate AND @LDate
      -- Modify/Delete guards: exclude approved, cancelled, amended
      AND (@Mode = 'FIND'
           OR (
               ISNULL(h.APPFLG,      'N') <> 'Y'
           AND ISNULL(h.cancelflag,  '')  = ''
           AND ISNULL(h.amendno,      0)  = 0
           AND ISNULL(
               (SELECT TOP 1 l2.AmdFlg FROM dbo.PO_PRL l2
                WHERE l2.divcode=h.divcode AND l2.prno=h.prno AND l2.prdate=h.prdate), 'N') <> 'Y'
           ))
      AND (@DepCode  IS NULL OR h.depcode  = @DepCode)
      AND (@ReqName  IS NULL OR h.REQNAME  = @ReqName)
      AND (@PoGrp    IS NULL OR h.PO_GRP   = @PoGrp)
    ORDER BY h.prdate DESC, h.prno DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
