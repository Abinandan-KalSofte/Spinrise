using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

public class PrCancellationService : IPrCancellationService
{
    private readonly IPrCancellationRepository _repo;

    public PrCancellationService(IPrCancellationRepository repo) => _repo = repo;

    public Task<IEnumerable<PrCancellablePrDto>> GetCancellablePRsAsync(
        string divCode, DateTime yfDate, DateTime ylDate) =>
        _repo.GetCancellablePRsAsync(divCode, yfDate, ylDate);

    public Task<PrForCancellationDetailDto?> GetPRForCancellationAsync(
        decimal prNo, string prDate, string depCode, string divCode) =>
        _repo.GetPRForCancellationAsync(prNo, prDate, depCode, divCode);

    public async Task CancelPRAsync(PrCancelRequestDto request, string divCode,
        string userId, string? hostName, string? ipAddress)
    {
        if (string.IsNullOrWhiteSpace(request.CancelReason))
            throw new InvalidOperationException("Please enter the Reason.");

        await _repo.CancelPRAsync(request, divCode, userId, hostName, ipAddress);
    }

    public Task<IEnumerable<PrCancelledPrDto>> GetCancelledPRsForUndoAsync(
        string divCode, DateTime yfDate, DateTime ylDate) =>
        _repo.GetCancelledPRsForUndoAsync(divCode, yfDate, ylDate);

    public Task UndoCancellationAsync(PrUndoRequestDto request, string divCode,
        string userId, string? hostName, string? ipAddress) =>
        _repo.UndoCancellationAsync(request, divCode, userId, hostName, ipAddress);
}
