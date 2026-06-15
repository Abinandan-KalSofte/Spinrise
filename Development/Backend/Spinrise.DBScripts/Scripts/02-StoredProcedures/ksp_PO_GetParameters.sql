-- ============================================================
-- ksp_PO_GetParameters
-- Reads PO_PARA for the given division.
-- Returns: parameter columns that drive PO screen behaviour.
-- Called on screen load.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetParameters
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(p.PoFirstLevelApp, 'N') AS PoFirstLevelApp,
        ISNULL(p.poprintapp,       'N') AS PoPrintApp,
        ISNULL(p.Po_Confirm,       'N') AS PoConf,
        ISNULL(p.budGrp,           'N') AS BudGrp,
        ISNULL(p.BudgetQty,        'N') AS BudgetQty,
        ISNULL(p.BudgetControl,    'N') AS BudgetControl,
        ISNULL(p.CurrCode,         '')  AS CurrCode,
        ISNULL(ip.BACKDATE,        'Y') AS BackDate,
        ISNULL(p.PDFExportFlag,    'N') AS PdfExportFlag
    FROM dbo.PO_PARA p
    CROSS JOIN (SELECT TOP 1 ISNULL(UPPER(RTRIM(BACKDATE)), 'Y') AS BACKDATE FROM dbo.IN_PARA) ip
    WHERE p.divcode = @DivCode;
END;
GO
