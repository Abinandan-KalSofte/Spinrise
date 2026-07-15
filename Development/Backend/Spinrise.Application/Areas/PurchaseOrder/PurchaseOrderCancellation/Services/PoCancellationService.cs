using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Services;

// Re-validates FN §3 as defence-in-depth before the SP runs. The SP repeats these
// guards on the live row (server-authoritative balance); this layer fails fast with
// a 400 (InvalidOperationException) on obviously invalid payloads.
public class PoCancellationService : IPoCancellationService
{
    private readonly IPoCancellationRepository _repo;

    public PoCancellationService(IPoCancellationRepository repo) => _repo = repo;

    public Task<IEnumerable<CancellationReasonDto>> GetReasonsAsync() =>
        _repo.GetReasonsAsync();

    public Task<IEnumerable<PoOpenSummaryDto>> GetOpenPOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        // Same guard as PoApprovalService.GetPendingAsync (T-0153): a missing/default
        // date binds to SQL DATETIME's min value and surfaces as an unhandled 500
        // (SqlTypeException) instead of a clean 400.
        if (yfDate == default || ylDate == default)
            throw new InvalidOperationException("Financial year bounds (yfDate/ylDate) are required.");

        return _repo.GetOpenPOListAsync(divCode, yfDate, ylDate);
    }

    public Task<IEnumerable<PoCancellationLineDto>> GetOpenLinesAsync(
        string divCode, decimal poNo, string poDate) =>
        _repo.GetOpenLinesAsync(divCode, poNo, poDate);

    public async Task CancelLinesAsync(
        CancelSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        if (request.Lines is null || request.Lines.Count == 0)
            throw new InvalidOperationException("Select at least one item to complete the transaction.");

        foreach (var line in request.Lines)
        {
            if (line.CancelQty <= 0)
                throw new InvalidOperationException("Please Enter Cancel Quantity...!");
            if (string.IsNullOrWhiteSpace(line.ReasonCode))
                throw new InvalidOperationException("Please Enter Cancellation Reason..!");
        }

        await _repo.CancelLinesAsync(request, divCode, transDate, userId, hostName, ipAddress);
    }
}
