-- ============================================================
-- ksp_PR_GetItems
-- Item lookup for the PR item selection modal.
-- Supports type-ahead search by code or name, optional group filter.
-- Returns item details + last PO rate for the rate selector.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItems
(
    @DivCode       VARCHAR(2),
    @Search        VARCHAR(50) = NULL,   -- partial code or name
    @ItemGrpCode   VARCHAR(10) = NULL,   -- filter by sgrpcode when InditemGrp='Y'
    @PageNumber    INT         = 1,
    @PageSize      INT         = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(i.itemcode)              AS ItemCode,
        RTRIM(i.itemname)              AS ItemName,
        RTRIM(i.uom)                   AS Uom,
        ISNULL(i.minlevel,   0)        AS MinLevel,
        ISNULL(i.maxlevel,   0)        AS MaxLevel,
        i.ITEMIMAGE                    AS ItemImage,
        -- Last PO Rate for this item + division
        (
            SELECT TOP 1 pl.RATE
            FROM dbo.PO_ORDL pl
            INNER JOIN dbo.PO_ORDH ph
                ON ph.divcode = pl.divcode
               AND ph.pordno  = pl.pordno
               AND ph.porddt  = pl.porddt
            WHERE pl.itemcode = i.itemcode
              AND pl.divcode  = @DivCode
              AND ISNULL(ph.CANFLG, 'N') = 'N'
            ORDER BY ph.porddt DESC
        ) AS LpoRate,
        (
            SELECT TOP 1 CAST(ph.porddt AS DATE)
            FROM dbo.PO_ORDL pl
            INNER JOIN dbo.PO_ORDH ph
                ON ph.divcode = pl.divcode
               AND ph.pordno  = pl.pordno
               AND ph.porddt  = pl.porddt
            WHERE pl.itemcode = i.itemcode
              AND pl.divcode  = @DivCode
              AND ISNULL(ph.CANFLG, 'N') = 'N'
            ORDER BY ph.porddt DESC
        ) AS LpoDate
    FROM dbo.IN_ITEM i
    WHERE ISNULL(i.IsItemActive, 1) = 1
      AND (
            @ItemGrpCode IS NULL
            OR RTRIM(i.sgrpcode) = @ItemGrpCode
          )
      AND (
            @Search IS NULL
            OR i.itemcode LIKE '%' + @Search + '%'
            OR i.itemname LIKE '%' + @Search + '%'
          )
    ORDER BY i.itemcode
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
