-- ============================================================
-- ksp_PR_GetItemDetail
-- Called when an item is selected in the grid.
-- Returns item master data + stock (conservative min) + rate options.
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

    -- Item master
    SELECT
        RTRIM(i.itemcode)      AS ItemCode,
        RTRIM(i.itemname)      AS ItemName,
        RTRIM(i.uom)           AS Uom,
        ISNULL(i.minlevel, 0)  AS MinLevel,
        i.IMAGE                AS ItemImage
    FROM dbo.IN_ITEM i
    WHERE i.itemcode = @ItemCode
      AND ISNULL(i.IsItemActive, 1) = 1;

    -- Stock: stkchk1 — opening + receipts TC(1,3,5,7,9,12) - issues TC(2,4,6,8,11) up to @PDate
    DECLARE @Stkchk1 NUMERIC(12,3) = 0;
    SELECT @Stkchk1 = ISNULL(SUM(
        CASE
            WHEN t.TC IN (1,3,5,7,9,12) THEN  ISNULL(t.qty, 0)
            WHEN t.TC IN (2,4,6,8,11)   THEN -ISNULL(t.qty, 0)
            WHEN t.TC = 0               THEN  ISNULL(t.qty, 0)  -- opening
            ELSE 0
        END
    ), 0)
    FROM (
        -- Opening balance
        SELECT TC = 0, qty = ISNULL(d.OPQTY, 0)
        FROM dbo.IN_IDET d
        WHERE d.itemcode = @ItemCode
          AND d.divcode  = @DivCode
          AND d.yearmonth LIKE @FDate + '%'   -- '00' month suffix for opening
        UNION ALL
        -- Transactions up to today
        SELECT t.TC, t.qty
        FROM dbo.IN_TRNTAIL t
        INNER JOIN dbo.IN_TRNHEAD h
            ON h.divcode = t.divcode
           AND h.docno   = t.docno
           AND h.docdt   = t.docdt
        WHERE t.itemcode = @ItemCode
          AND t.divcode  = @DivCode
          AND CAST(h.docdt AS DATE) BETWEEN @FDate AND @PDate
          AND t.TC IN (1,2,3,4,5,6,7,8,9,11,12)
    ) t;

    -- Stock: stkchk2 — same but up to year-end, excludes TC=12
    DECLARE @Stkchk2 NUMERIC(12,3) = 0;
    SELECT @Stkchk2 = ISNULL(SUM(
        CASE
            WHEN t.TC IN (1,3,5,7,9)  THEN  ISNULL(t.qty, 0)   -- no TC=12
            WHEN t.TC IN (2,4,6,8,11) THEN -ISNULL(t.qty, 0)
            WHEN t.TC = 0             THEN  ISNULL(t.qty, 0)
            ELSE 0
        END
    ), 0)
    FROM (
        SELECT TC = 0, qty = ISNULL(d.OPQTY, 0)
        FROM dbo.IN_IDET d
        WHERE d.itemcode = @ItemCode
          AND d.divcode  = @DivCode
          AND d.yearmonth LIKE @FDate + '%'
        UNION ALL
        SELECT t.TC, t.qty
        FROM dbo.IN_TRNTAIL t
        INNER JOIN dbo.IN_TRNHEAD h
            ON h.divcode = t.divcode
           AND h.docno   = t.docno
           AND h.docdt   = t.docdt
        WHERE t.itemcode = @ItemCode
          AND t.divcode  = @DivCode
          AND CAST(h.docdt AS DATE) BETWEEN @FDate AND @LDate
          AND t.TC IN (1,2,3,4,5,6,7,8,9,11)
    ) t;

    -- Conservative minimum stock
    DECLARE @CurrentStock NUMERIC(12,3) = CASE WHEN @Stkchk1 <= @Stkchk2 THEN @Stkchk1 ELSE @Stkchk2 END;

    -- Rate options
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

    DECLARE @AvgRate NUMERIC(13,4) = NULL;
    SELECT @AvgRate = AVG(t.rate)
    FROM dbo.IN_TRNTAIL t
    INNER JOIN dbo.IN_TRNHEAD h
        ON h.divcode = t.divcode
       AND h.docno   = t.docno
       AND h.docdt   = t.docdt
    WHERE t.itemcode = @ItemCode
      AND t.divcode  = @DivCode
      AND t.TC = 1   -- GRN receipts
      AND CAST(h.docdt AS DATE) BETWEEN @FDate AND @LDate;

    SELECT
        @CurrentStock AS CurrentStock,
        @LpoRate      AS LpoRate,
        @LpoDate      AS LpoDate,
        @AvgRate      AS AvgRate;
END;
GO
