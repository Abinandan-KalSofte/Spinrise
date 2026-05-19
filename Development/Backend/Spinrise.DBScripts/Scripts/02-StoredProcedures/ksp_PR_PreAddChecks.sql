-- ============================================================
-- ksp_PR_PreAddChecks
-- Runs all 3 pre-add existence checks in a single call.
-- Returns a row with flags for each check.
-- Called before opening Add mode.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_PreAddChecks
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemExists    BIT = 0;
    DECLARE @DeptExists    BIT = 0;
    DECLARE @DocParaExists BIT = 0;
    DECLARE @BackDateFlag  CHAR(1) = 'Y';
    DECLARE @MaxPrDate     DATE = NULL;

    -- Check 1: Item master has at least one record
    IF EXISTS (SELECT 1 FROM dbo.IN_ITEM)
        SET @ItemExists = 1;

    -- Check 2: Department master has records for this division
    IF EXISTS (SELECT 1 FROM dbo.IN_DEP WHERE divcode = @DivCode)
        SET @DeptExists = 1;

    -- Check 3: PO_DOC_PARA has a starting number defined for IND (Indent/PR)
    -- PO_DOC_PARA only has TC and STDOCNO columns
    IF EXISTS (SELECT 1 FROM dbo.PO_DOC_PARA WHERE TC = 'IND')
        SET @DocParaExists = 1;

    -- Backdate flag from IN_PARA (single-row config table — no divcode column)
    SELECT TOP 1 @BackDateFlag = ISNULL(UPPER(RTRIM(ip.BACKDATE)), 'Y')
    FROM dbo.IN_PARA ip;

    -- Max existing PR date in current financial year
    SELECT @MaxPrDate = CAST(MAX(h.prdate) AS DATE)
    FROM dbo.PO_PRH h
    WHERE h.divcode = @DivCode;

    SELECT
        @ItemExists    AS ItemMasterExists,
        @DeptExists    AS DeptMasterExists,
        @DocParaExists AS DocParaExists,
        @BackDateFlag  AS BackDateFlag,
        @MaxPrDate     AS MaxPrDate;
END;
GO
