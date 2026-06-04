using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Interfaces;

public interface IPrFirstApprovalService
{
    Task<PoParaDto?>                           GetPoParaAsync(string divCode);
    Task<IEnumerable<ApprovalDeptDto>>         GetDeptForUserAsync(string divCode, string userId);
    Task<IEnumerable<PrApprovalSummaryDto>>    GetPendingListAsync(string divCode, string dep, DateTime yfDate, DateTime ylDate);
    Task<IEnumerable<PrApprovalSummaryDto>>    GetApprovedListAsync(string divCode, DateTime yfDate, DateTime ylDate);
    Task<PrApprovalDetailDto?>                 GetDetailAsync(string divCode, decimal prNo, DateTime prDate);
    Task                                       SaveAsync(string divCode, SaveFirstApprovalRequest request,
                                                   string userId, string userName,
                                                   string? ipAddress, string? hostName, int moduleNo);
    Task                                       DeleteAsync(string divCode, DeleteFirstApprovalRequest request,
                                                   string userId, string userName,
                                                   string? ipAddress, string? hostName, int moduleNo);
    Task<PrApprovalReportDto?>                 GetReportDataAsync(string divCode, decimal prNo, DateTime prDate);
}
