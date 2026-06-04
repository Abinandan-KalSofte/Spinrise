using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;

public interface IFinalLevelApprovalRepository
{
    Task<IEnumerable<FinalApprovalLineDto>> GetPendingAsync(int imode, string divCode, int bypass);
    Task<int>                               SaveItemAsync(FinalApprovalSaveItemRequest item, string finalAppUser, int bypass);
    Task<IEnumerable<CompanyDto>>           GetCompaniesAsync();
    Task<IEnumerable<DivisionDto>>          GetDivisionsAsync(string dbName);
    Task<IEnumerable<ItemHistoryDto>>       GetItemHistoryAsync(string itemCode, string divCode);
}
