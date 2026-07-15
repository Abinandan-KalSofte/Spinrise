using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.Interfaces;

public interface IPoApprovalService
{
    Task<IReadOnlyList<DivisionRowDto>> GetDivisionsAsync(string level);

    // 10-Jul-2026: FY guard (yfDate/ylDate), same pattern as PR module.
    Task<PoApprovalPendingResponse> GetPendingAsync(
        string level, string divCode, DateTime yfDate, DateTime ylDate, string? search);

    Task<PoApprovalSaveResponse> SaveAsync(
        string level,
        PoApprovalSaveRequest request,
        string userId,
        string userName,
        string? ipAddress,
        string? hostName);
}
