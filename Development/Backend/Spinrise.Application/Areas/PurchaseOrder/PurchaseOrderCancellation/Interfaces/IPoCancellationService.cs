using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Interfaces;

public interface IPoCancellationService
{
    Task<IEnumerable<CancellationReasonDto>> GetReasonsAsync();

    Task<IEnumerable<PoOpenSummaryDto>> GetOpenPOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate);

    Task<IEnumerable<PoCancellationLineDto>> GetOpenLinesAsync(
        string divCode, decimal poNo, string poDate);

    Task CancelLinesAsync(
        CancelSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);
}
