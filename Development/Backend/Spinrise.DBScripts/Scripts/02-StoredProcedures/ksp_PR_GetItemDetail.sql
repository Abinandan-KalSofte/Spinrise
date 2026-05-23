-- ============================================================
-- ksp_PR_GetItemDetail
-- Called when an item is selected in the grid.
-- Returns item master data + stock + rate options.
-- NOTE: CurrentStock uses IN_ITEM.CURSTK (direct).
--       FY-based conservative stock calc (IN_IDET/IN_TRNTAIL)
--       will be restored once exact column names are confirmed.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItemDetail
(
    @DivCode   VARCHAR(2),
    @ItemCode  VARCHAR(10),
    @FDate     DATE,            -- financial year start
    @LDate     DATE,            -- financial year end
    @PDate     DATE             -- processing date (today)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Item master
    SELECT
        RTRIM(i.itemcode)             AS ItemCode,
        RTRIM(i.itemname)             AS ItemName,
        RTRIM(i.uom)                  AS Uom,
        ISNULL(i.minlevel, 0)         AS MinLevel,
        i.ITEMIMAGE                   AS ItemImage,
        RTRIM(ISNULL(i.ImagePath,'')) AS ImagePath
    FROM dbo.IN_ITEM i
    WHERE i.itemcode = @ItemCode
      AND ISNULL(i.IsItemActive, 1) = 1;

    -- Result set 2: Stock + rates
    DECLARE @CurrentStock NUMERIC(12,3) = 0;
    SELECT @CurrentStock = ISNULL(CURSTK, 0) FROM dbo.IN_ITEM WHERE itemcode = @ItemCode;

    DECLARE @LpoRate NUMERIC(13,4) = NULL;
    DECLARE @LpoDate DATE = NULL;
    SELECT TOP 1
        @LpoRate = pl.RATE,
        @LpoDate = CAST(ph.porddt AS DATE)
    FROM dbo.PO_ORDL pl
    INNER JOIN dbo.PO_ORDH ph
        ON ph.divcode = pl.divcode
       AND ph.pordno  = pl.pordno
       AND ph.porddt  = pl.porddt
    WHERE pl.itemcode = @ItemCode
      AND pl.divcode  = @DivCode
      AND ISNULL(ph.CANFLG, 'N') = 'N'
    ORDER BY ph.porddt DESC;

    SELECT
        @CurrentStock AS CurrentStock,
        @LpoRate      AS LpoRate,
        @LpoDate      AS LpoDate,
        NULL          AS AvgRate;
END;
GO
