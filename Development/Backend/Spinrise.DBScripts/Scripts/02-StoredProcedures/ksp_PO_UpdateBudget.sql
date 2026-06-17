-- ============================================================
-- ksp_PO_UpdateBudget  (SP #13)
-- Deducts PO order value from PO_BUDGET.BALAMT after a
-- successful PO save. Only runs when BudgetControl = 'Y'
-- in PO_PARA for the division.
-- Join chain: PO_ORDL → PO_PRL → PO_BUDGET
--   (CATCODE / CCCODE / BGRPCODE from PO_PRL)
-- YEARMON = YYYYMM derived from @PoDate.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_UpdateBudget
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check activation flag — exit silently if not active
    DECLARE @BudgetControl CHAR(1) = 'N';
    SELECT TOP 1 @BudgetControl = ISNULL(UPPER(RTRIM(BudgetControl)), 'N')
    FROM dbo.PO_PARA
    WHERE divcode = @DivCode;

    IF @BudgetControl <> 'Y'
        RETURN;

    DECLARE @YearMon INT = YEAR(@PoDate) * 100 + MONTH(@PoDate);

    UPDATE b
    SET
        b.BALAMT     = ISNULL(b.BALAMT,     0) - ROUND(l.Rate * l.ORDqty, 2),
        b.budutilamt = ISNULL(b.budutilamt, 0) + ROUND(l.Rate * l.ORDqty, 2)
    FROM dbo.PO_BUDGET b
    INNER JOIN dbo.PO_ORDL l
        ON  l.DIVCODE = @DivCode
        AND l.PORDNO  = @PoNo
        AND CAST(l.PORDDT AS DATE) = @PoDate
    INNER JOIN dbo.PO_PRL prl
        ON  prl.divcode = @DivCode
        AND prl.prno    = l.PRNO
        AND CAST(prl.prdate AS DATE) = CAST(l.PRDATE AS DATE)
        AND prl.prsno   = l.PRSNO
    WHERE b.DIVCODE = @DivCode
      AND b.CATCODE = prl.CATCODE
      AND b.CCCODE  = prl.CCCODE
      AND b.GRPCODE = prl.BGRPCODE
      AND b.YEARMON = @YearMon;
END;
GO
