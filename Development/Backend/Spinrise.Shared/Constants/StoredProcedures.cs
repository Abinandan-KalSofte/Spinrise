namespace Spinrise.Shared.Constants;

public static class StoredProcedures
{
    public static class Auth
    {
        public const string ValidateUser       = "ksp_Auth_ValidateUser";
        public const string GetUserById        = "ksp_Auth_GetUserById";
        public const string GetActiveDivisions = "ksp_Auth_GetActiveDivisions";
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
        public const string CheckPendingOrder   = "ksp_PR_CheckPendingOrder";
    }
}
