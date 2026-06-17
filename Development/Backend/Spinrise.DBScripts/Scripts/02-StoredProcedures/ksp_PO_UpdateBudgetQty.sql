-- ============================================================
-- ksp_PO_UpdateBudgetQty  (SP #14)
-- Deducts PO ordered quantity from PO_BUDGETQTY_YEAR.BUD_BALQTY
-- after a successful PO save. Only runs when BudgetQty = 'Y'
-- in PO_PARA for the division.
-- Join: PO_ORDL → PO_BUDGETQTY_YEAR on DIVCODE + ITEMCODE + YEAR.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_UpdateBudgetQty
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check activation flag — exit silently if not active
    DECLARE @BudgetQty CHAR(1) = 'N';
    SELECT TOP 1 @BudgetQty = ISNULL(UPPER(RTRIM(BudgetQty)), 'N')
    FROM dbo.PO_PARA
    WHERE divcode = @DivCode;

    IF @BudgetQty <> 'Y'
        RETURN;

    DECLARE @Year INT = YEAR(@PoDate);

    UPDATE b
    SET
        b.BUD_BALQTY  = ISNULL(b.BUD_BALQTY,  0) - l.ORDqty,
        b.BUD_UTILQTY = ISNULL(b.BUD_UTILQTY, 0) + l.ORDqty
    FROM dbo.PO_BUDGETQTY_YEAR b
    INNER JOIN dbo.PO_ORDL l
        ON  l.DIVCODE = @DivCode
        AND l.PORDNO  = @PoNo
        AND CAST(l.PORDDT AS DATE) = @PoDate
    WHERE b.DIVCODE  = @DivCode
      AND b.ITEMCODE = l.ITEMCODE
      AND b.YEAR     = @Year;
END;
GO
