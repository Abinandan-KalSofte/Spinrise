using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Interfaces;

public interface IPoCancellationRepository
{
    Task<IEnumerable<CancellationReasonDto>> GetReasonsAsync();

    // 13-Jul-2026: open-PO picker source (FN §5), same FY-guard pattern as
    // ksp_PR_GetPendingFirstApproval / PoApproval's GetPendingAsync.
    Task<IEnumerable<PoOpenSummaryDto>> GetOpenPOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate);

    Task<IEnumerable<PoCancellationLineDto>> GetOpenLinesAsync(
        string divCode, decimal poNo, string poDate);

    Task CancelLinesAsync(
        CancelSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);
}
