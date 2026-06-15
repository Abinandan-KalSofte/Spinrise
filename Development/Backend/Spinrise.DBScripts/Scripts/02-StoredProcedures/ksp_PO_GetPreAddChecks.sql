-- ============================================================
-- ksp_PO_GetPreAddChecks
-- Gate checks before entering ADD mode.
-- Returns: flags for approved PR lines, doc para, backdate, max PO date.
-- ⚠ VERIFY: PO_DOC_PARA TC value for Purchase Order — may be 'PO' or 'PORDER'.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPreAddChecks
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ApprovedPrLinesExist BIT = 0;
    DECLARE @DocParaExists        BIT = 0;
    DECLARE @BackDateFlag         CHAR(1) = 'Y';
    DECLARE @MaxPoDate            DATE = NULL;

    -- Check 1: At least one approved PR line with balance > 0 (BR-02)
    IF EXISTS (
        SELECT 1
        FROM dbo.PO_PRL l
        INNER JOIN dbo.PO_PRH h
            ON h.divcode = l.divcode AND h.prno = l.prno
        WHERE l.divcode = @DivCode
          AND ISNULL(l.DirectApp, 'N') = 'Y'
          AND ISNULL(l.FClosed,   'N') <> 'Y'
          AND (ISNULL(l.QTYREQD, 0) - ISNULL(l.QTYORD, 0) - ISNULL(l.enq_qty, 0)) > 0
          AND RTRIM(ISNULL(l.prstatus, '')) NOT IN ('O','E','C','Z','X')
          AND ISNULL(h.cancelflag, '') = ''
    )
        SET @ApprovedPrLinesExist = 1;

    -- Check 2: PO doc series defined in PO_DOC_PARA
    -- ⚠ VERIFY: TC value for Purchase Order in this installation
    IF EXISTS (SELECT 1 FROM dbo.PO_DOC_PARA WHERE TC = 'PO')
        SET @DocParaExists = 1;

    -- Backdate flag
    SELECT TOP 1 @BackDateFlag = ISNULL(UPPER(RTRIM(BACKDATE)), 'Y')
    FROM dbo.IN_PARA;

    -- Max existing PO date for this division
    SELECT @MaxPoDate = CAST(MAX(PORDDT) AS DATE)
    FROM dbo.PO_ORDH
    WHERE divcode = @DivCode
      AND ISNULL(CANFLG, '') = '';

    SELECT
        @ApprovedPrLinesExist AS ApprovedPrLinesExist,
        @DocParaExists        AS DocParaExists,
        @BackDateFlag         AS BackDateFlag,
        @MaxPoDate            AS MaxPoDate;
END;
GO
