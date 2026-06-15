-- ============================================================
-- ksp_PO_GetPRLines
-- Returns eligible PR lines for the PO PR Picker (BR-02).
-- Filter: DirectApp='Y', Fclosed<>'Y', balance qty > 0,
--         prstatus NOT IN ('O','E','C','Z','X'), PR not cancelled.
-- Balance = QTYREQD - QTYORD - Enq_Qty
-- PO_PRL has NO GST columns — CgstPer/SgstPer/IgstPer default to 0.
-- User sets tax codes in the GST modal after loading lines.
-- ⚠ VERIFY: IN_ITEM.hsncode column — may differ.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPRLines
(
    @DivCode    VARCHAR(2),
    @OrderType  VARCHAR(10) = NULL,
    @Search     VARCHAR(100) = NULL,
    @PageNumber INT          = 1,
    @PageSize   INT          = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        CAST(l.prno AS VARCHAR(20)) + '|' + CAST(l.prsno AS VARCHAR(10)) + '|' + RTRIM(l.itemcode) AS Id,
        l.prno                                                          AS PrNo,
        CONVERT(varchar(11), CAST(ISNULL(h.prdate, l.prdate) AS DATE), 106) AS PrDate,
        l.prsno                                                         AS PrSno,
        RTRIM(l.itemcode)                                               AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                                   AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                        AS Uom,
        ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0) - ISNULL(l.Enq_Qty, 0) AS BalanceQty,
        RTRIM(ISNULL(d.depname, ''))                                    AS Department,
        RTRIM(ISNULL(scc.SCCNAME, ''))                                  AS SubCostCentre,
        RTRIM(ISNULL(l.remarks, ''))                                    AS Remarks,
        RTRIM(ISNULL(i.hsncode, ''))                                    AS HsnCode,   -- ⚠ VERIFY: IN_ITEM.hsncode
        CAST(0 AS DECIMAL(10,2))                                        AS CgstPer,   -- PO_PRL has no GST columns
        CAST(0 AS DECIMAL(10,2))                                        AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                        AS IgstPer,
        ''                                                              AS GstTaxCode,
        RTRIM(ISNULL(h.REQNAME, ''))                                    AS RequesterId,
        RTRIM(ISNULL(e.ename, ''))                                      AS RequesterName
    FROM dbo.PO_PRL l
    INNER JOIN dbo.PO_PRH h
        ON h.divcode = l.divcode AND h.prno = l.prno
       AND CAST(h.prdate AS DATE) = CAST(l.prdate AS DATE)
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.itemcode
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = l.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.In_Scc scc
        ON scc.SCCCODE = l.CCCODE AND scc.Divcode = l.divcode
    OUTER APPLY (
        SELECT TOP 1 e.ename
        FROM dbo.PR_EMP e
        WHERE TRY_CAST(h.REQNAME AS DECIMAL(5,0)) = e.empno
        ORDER BY CASE WHEN e.divcode = @DivCode THEN 0 ELSE 1 END, e.empno
    ) e
    WHERE l.divcode = @DivCode
      AND ISNULL(l.DirectApp, 'N') = 'Y'
      AND ISNULL(l.FClosed,   'N') <> 'Y'
      AND ISNULL(l.AmdFlg,    '') <> 'Y'
      AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0) - ISNULL(l.Enq_Qty, 0)) > 0
      AND RTRIM(ISNULL(l.prstatus, '')) NOT IN ('O','E','C','Z','X')
      AND ISNULL(h.cancelflag, '') = ''
      AND (@OrderType IS NULL OR RTRIM(ISNULL(h.PO_GRP, '')) = @OrderType)
      AND (@Search IS NULL
           OR RTRIM(l.itemcode) LIKE @Search + '%'
           OR RTRIM(i.itemname) LIKE '%' + @Search + '%'
           OR CAST(l.prno AS VARCHAR(20)) LIKE @Search + '%')
    ORDER BY h.prdate, l.prno, l.prsno
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
