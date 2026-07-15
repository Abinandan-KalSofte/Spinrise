using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Interfaces;

// Business layer for PO Amendment. Enforces the static half of FN §3 (defence in
// depth behind React) before delegating to the repository; server recompute of
// taxes/values/floor stays in the SP (FN §4.B).
public interface IPoAmendmentService
{
    Task<IEnumerable<AmendablePoSummaryDto>> GetAmendablePOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate);

    Task<PoAmendmentHeaderDto?> GetPOForAmendAsync(
        string divCode, decimal poNo, string poDate, string poGrp);

    Task<IEnumerable<AmendmentSummaryDto>> GetAmendmentListAsync(
        string divCode, DateTime yfDate, DateTime ylDate);

    Task<AmendmentSaveResponseDto> SaveAmendmentAsync(
        AmendmentSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);

    Task DeleteOrderAsync(
        DeleteOrderRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);

    Task DeleteLinesAsync(
        DeleteLinesRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);
}
