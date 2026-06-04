using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

public interface IPrCancellationService
{
    Task<IEnumerable<PrCancellablePrDto>> GetCancellablePRsAsync(string divCode, DateTime yfDate, DateTime ylDate);
    Task<PrForCancellationDetailDto?> GetPRForCancellationAsync(decimal prNo, string prDate, string depCode, string divCode);
    Task CancelPRAsync(PrCancelRequestDto request, string divCode, string userId, string? hostName, string? ipAddress);
    Task<IEnumerable<PrCancelledPrDto>> GetCancelledPRsForUndoAsync(string divCode, DateTime yfDate, DateTime ylDate);
    Task UndoCancellationAsync(PrUndoRequestDto request, string divCode, string userId, string? hostName, string? ipAddress);
}
