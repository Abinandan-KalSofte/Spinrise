using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.Interfaces;

public interface IPoApprovalRepository
{
    Task<IReadOnlyList<DivisionRowDto>> GetDivisionsAsync();

    // 10-Jul-2026: FY guard (yfDate/ylDate), same pattern as ksp_PR_GetPendingFirstApproval.
    Task<IReadOnlyList<PoApprovalLineDto>> GetPendingAsync(
        string level, string divCode, DateTime yfDate, DateTime ylDate, string? search);

    // Returns the SP's @Result output: 0=success, 2=prerequisite not met,
    // 3=concurrency conflict, 4=not found. divCode comes from item.DivCode
    // (10-Jul-2026 bug fix) — no separate request-level divCode anymore.
    Task<int> SetApprovalAsync(
        string level,
        PoApprovalSaveItemRequest item,
        string userId,
        string userName,
        string? ipAddress,
        string? hostName);
}
