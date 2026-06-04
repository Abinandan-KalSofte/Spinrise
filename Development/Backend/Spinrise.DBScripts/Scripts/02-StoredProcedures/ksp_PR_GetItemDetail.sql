-- ============================================================
-- ksp_PR_GetItemDetail
-- Called when an item is selected in the grid.
-- Returns item master data + stock + rate options.
--
-- CurrentStock formula (ported from VB6 stkchk1):
--   Opening balance from IN_IDET (YEARMONTH = YYYYoo, TC = 0)
--   + FY receipts up to @PDate from IN_TRNTAIL (TCTYPE 1/3/5/7/9/12)
--   - FY issues  up to @PDate from IN_TRNTAIL (TCTYPE 2/4/6/8/11)
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
        ISNULL(i.maxlevel, 0)         AS MaxLevel,
        i.ITEMIMAGE                   AS ItemImage,
        RTRIM(ISNULL(i.ImagePath,'')) AS ImagePath
    FROM dbo.IN_ITEM i
    WHERE i.itemcode = @ItemCode
      AND ISNULL(i.IsItemActive, 1) = 1;

    -- Result set 2: Stock + rates
    -- oym: opening year-month key — e.g. FY start 01-Apr-2025 → '202500'
    DECLARE @OYM       VARCHAR(6)     = CAST(YEAR(@FDate) AS VARCHAR(4)) + '00';
    DECLARE @CurrentStock NUMERIC(12,3) = 0;

    SELECT @CurrentStock = ISNULL(SUM(ALLREC) - SUM(ALLISS), 0)
    FROM (
        -- 1. Opening balance: IN_IDET opening record (TC = 0)
        SELECT ISNULL(SUM(QUANTITY), 0)   AS ALLREC,
               CAST(0 AS NUMERIC(12,3))   AS ALLISS
        FROM   dbo.IN_IDET
        WHERE  DIVCODE   = @DivCode
          AND  ITEMCODE  = @ItemCode
          AND  YEARMONTH = @OYM
          AND  TC        = 0

        UNION ALL

        -- 2. FY receipts up to @PDate (TCTYPE = 1,3,5,7,9,12)
        SELECT ISNULL(SUM(A.QUANTITY), 0) AS ALLREC,
               CAST(0 AS NUMERIC(12,3))   AS ALLISS
        FROM   dbo.IN_TRNTAIL A
        INNER JOIN dbo.IN_TC  T ON T.TC = A.TC
        WHERE  A.DIVCODE  = @DivCode
          AND  A.ITEMCODE = @ItemCode
          AND  T.TCTYPE   IN (1, 3, 5, 7, 9, 12)
          AND  A.DOCDT   >= @FDate
          AND  A.DOCDT   <= @PDate

        UNION ALL

        -- 3. FY issues up to @PDate (TCTYPE = 2,4,6,8,11)
        SELECT CAST(0 AS NUMERIC(12,3))          AS ALLREC,
               ISNULL(SUM(ABS(A.QUANTITY)), 0)   AS ALLISS
        FROM   dbo.IN_TRNTAIL A
        INNER JOIN dbo.IN_TC  T ON T.TC = A.TC
        WHERE  A.DIVCODE  = @DivCode
          AND  A.ITEMCODE = @ItemCode
          AND  T.TCTYPE   IN (2, 4, 6, 8, 11)
          AND  A.DOCDT   >= @FDate
          AND  A.DOCDT   <= @PDate
    ) S;

    DECLARE @LpoRate NUMERIC(13,4) = NULL;
    DECLARE @LpoDate DATE          = NULL;
    SELECT TOP 1
        @LpoRate = pl.RATE,
        @LpoDate = CAST(ph.porddt AS DATE)
    FROM dbo.PO_ORDL pl
    INNER JOIN dbo.PO_ORDH ph
        ON  ph.divcode = pl.divcode
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
