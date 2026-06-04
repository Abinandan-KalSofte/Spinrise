using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;

public interface IFinalLevelApprovalService
{
    Task<FinalApprovalGetResponse>      GetPendingAsync(FinalApprovalGetQuery query);
    Task<FinalApprovalSaveResponse>     SaveApprovalsAsync(FinalApprovalSaveRequest request, string finalAppUser);
    Task<IEnumerable<CompanyDto>>       GetCompaniesAsync();
    Task<IEnumerable<DivisionDto>>      GetDivisionsAsync(string dbName);
    Task<IEnumerable<ItemHistoryDto>>   GetItemHistoryAsync(string itemCode, string divCode);
}
