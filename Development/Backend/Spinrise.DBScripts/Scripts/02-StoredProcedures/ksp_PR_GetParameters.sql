-- ============================================================
-- ksp_PR_GetParameters
-- Reads PO_PARA for the given division.
-- Returns: all parameter columns needed by the PR screen.
-- Called on screen load (precheck + param-driven logic).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetParameters
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(p.Manual_IndNo,     'N') AS ManualIndNo,
        ISNULL(p.BudgetQty,        'N') AS BudgetQty,
        ISNULL(p.PendingOrderPara, 'N') AS PendingOrderPara,
        ISNULL(p.Penpodetails,     'N') AS Penpodetails,
        ISNULL(p.InditemGrp,       'N') AS InditemGrp,
        ISNULL(p.purtypeflg,        0 ) AS PurTypeFlg,
        ISNULL(p.EmpMasterComm,    'N') AS EmpMasterComm,
        ISNULL(p.PDFExportFlag,    'N') AS PdfExportFlag,
        ISNULL(p.PRSMSSendFlg,     'N') AS PrSmsSendFlg,
        ISNULL(p.PRSMSStatusFlg,   'N') AS PrSmsStatusFlg,
        ISNULL(p.Pr_ILevel,        'N') AS PrILevel,
        ISNULL(p.Pr_FLevel,        'N') AS PrFLevel,
        NULL                            AS DefaultPrType,
        'N'                             AS MultiSelectLookup
    FROM dbo.PO_PARA p
    WHERE p.divcode = @DivCode;
END;
GO
