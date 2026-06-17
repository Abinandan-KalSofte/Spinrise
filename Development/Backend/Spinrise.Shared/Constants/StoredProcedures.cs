namespace Spinrise.Shared.Constants;

public static class StoredProcedures
{
    public static class System
    {
        public const string GetDatabases = "ksp_GetDatabases";
    }

    public static class Auth
    {
        public const string ValidateUser       = "ksp_Auth_ValidateUser";
        public const string GetUserById        = "ksp_Auth_GetUserById";
        public const string GetActiveDivisions = "ksp_Auth_GetActiveDivisions";
        public const string GetActiveCompanies = "ksp_Auth_GetCompanies";
    }

    public static class PrAmendment
    {
        public const string GetNextAmendNo    = "usp_GetNextAmendNo";
        public const string GetList           = "ksp_PR_GetAmendmentList";
        public const string GetById           = "ksp_PR_GetAmendmentById";
        public const string GetForNew         = "ksp_PR_GetAmendmentForNew";
        public const string Save              = "ksp_PR_SaveAmendment";
        public const string GetPrint          = "ksp_PR_GetAmendmentPrint";
    }

    public static class PrForeclosure
    {
        public const string GetOpenLines = "ksp_PR_GetOpenForForeclosure";
        public const string SaveLine     = "ksp_PR_SaveForeclosureLine";
    }

    public static class PrCancellation
    {
        public const string GetCancellable      = "ksp_PR_GetCancellablePRs";
        public const string GetCancelledForUndo = "ksp_PR_GetCancelledPRsForUndo";
        public const string GetForCancellation  = "ksp_PR_GetForCancellation";
        public const string Cancel              = "ksp_PR_Cancel";
        public const string UndoCancellation    = "ksp_PR_UndoCancellation";
    }

    public static class PrFinalLevelApproval
    {
        public const string Approve      = "ksp_po_finalapproval";
        public const string GetCompanies = "ksp_po_GetFinalApprovalCompanies";
        public const string GetDivisions = "ksp_po_GetFinalApprovalDivisions";
    }

    public static class PrFirstLevelApproval
    {
        public const string GetDeptForUser         = "ksp_PR_GetDeptForUser";
        public const string GetPoPara              = "ksp_PR_GetPoParaForApproval";
        public const string GetPendingList         = "ksp_PR_GetPendingFirstApproval";
        public const string GetApprovedList        = "ksp_PR_GetFirstApprovedForDeletion";
        public const string GetHeader              = "ksp_PR_GetFirstApprovalHeader";
        public const string GetLines               = "ksp_PR_GetFirstApprovalLines";
        public const string Save                   = "ksp_PR_SaveFirstApproval";
        public const string Delete                 = "ksp_PR_DeleteFirstApproval";
        public const string GetReportData          = "ksp_PR_GetFirstApprovalReport";
        public const string CheckUserLevel         = "ksp_PR_CheckUserApprovalLevel";
    }

    public static class Po
    {
        public const string GetParameters      = "ksp_PO_GetParameters";
        public const string GetPreAddChecks    = "ksp_PO_GetPreAddChecks";
        public const string GetUserLevel       = "ksp_PO_GetUserLevel";
        public const string GetSuppliers       = "ksp_PO_GetSuppliers";
        public const string GetOrderTypes      = "ksp_PO_GetOrderTypes";
        public const string GetCarriers        = "ksp_PO_GetCarriers";
        public const string GetBanks           = "ksp_PO_GetBanks";
        public const string GetFormTypes       = "ksp_PO_GetFormTypes";
        public const string GetGstTaxCodes     = "ksp_PO_GetGstTaxCodes";
        public const string GetGstRouting      = "ksp_PO_GetGSTRouting";
        public const string GetEligiblePrLines = "ksp_PO_GetPRLines";
        public const string GetById            = "ksp_PO_GetPOHeader";
        public const string GetLines           = "ksp_PO_GetPOLines";
        public const string GetDeliverySchedule= "ksp_PO_GetDeliverySchedule";
        public const string GetList            = "ksp_PO_GetPOList";
        public const string GetLastRecord      = "ksp_PO_GetLastPO";
        public const string SaveEntry          = "ksp_PO_SaveEntry";
        public const string DeletePo           = "ksp_PO_DeletePO";
        public const string GetAddresses       = "ksp_PO_GetAddresses";
        public const string GetCurrencies      = "ksp_PO_GetCurrencies";
        public const string GetPricingTerms    = "ksp_PO_GetPricingTerms";
        public const string GetPrintData       = "ksp_PO_GetPrint";
        public const string SetPrintFlag       = "ksp_PO_SetPrintFlag";
        public const string UpdateBudget       = "ksp_PO_UpdateBudget";
        public const string UpdateBudgetQty    = "ksp_PO_UpdateBudgetQty";
    }

    public static class Pr
    {
        public const string GetParameters       = "ksp_PR_GetParameters";
        public const string PreAddChecks        = "ksp_PR_PreAddChecks";
        public const string GetDepartments      = "ksp_PR_GetDepartments";
        public const string GetEmployees        = "ksp_PR_GetEmployees";
        public const string GetPrTypes          = "ksp_PR_GetPrTypes";
        public const string GetItems            = "ksp_PR_GetItems";
        public const string GetItemDetail       = "ksp_PR_GetItemDetail";
        public const string GetLastRecord       = "ksp_PR_GetLastRecord";
        public const string GetById             = "ksp_PR_GetById";
        public const string GetList             = "ksp_PR_GetList";
        public const string Save                = "ksp_PR_Save";
        public const string Delete              = "ksp_PR_Delete";
        public const string CheckPendingOrder      = "ksp_PR_CheckPendingOrder";
        public const string GetUserPermissions    = "ksp_PR_GetUserPermissions";
        public const string GetMachineLookup      = "ksp_PR_GetMachineLookup";
        public const string GetCostCentreLookup   = "ksp_PR_GetCostCentreLookup";
        public const string GetPrint              = "ksp_PR_GetPrint";
        public const string GetItemImagePath      = "ksp_PR_GetItemImagePath";
    }
}
