using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Interfaces;

// Data access for PO Amendment (FN-PO-Amendment v1.2 §5). All 6 SPs are authored
// by Mariyaiya (CEO 12-Jul); this contract calls them by name via
// StoredProcedures.Po.Amendment. No @Result output param — RAISERROR bubbles as
// SqlException → ExceptionHandlingMiddleware, same as Cancellation/Foreclosure.
public interface IPoAmendmentRepository
{
    // ksp_PO_GetAmendablePOList — FN §1 lookup (AmdAfterGRN predicate is the SP's
    // internal logic; caller supplies only division + FY window).
    Task<IEnumerable<AmendablePoSummaryDto>> GetAmendablePOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate);

    // ksp_PO_GetPOForAmend — header + lines + delivery schedule for one PO.
    Task<PoAmendmentHeaderDto?> GetPOForAmendAsync(
        string divCode, decimal poNo, string poDate, string poGrp);

    // ksp_PO_GetAmendmentList — Find mode: saved amendments for the year.
    Task<IEnumerable<AmendmentSummaryDto>> GetAmendmentListAsync(
        string divCode, DateTime yfDate, DateTime ylDate);

    // ksp_PO_AmendOrder — save (A–H). Returns the allocated Amendment No.
    Task<int> SaveAmendmentAsync(
        AmendmentSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);

    // ksp_PO_DeleteOrder — whole-PO cascade delete.
    Task DeleteOrderAsync(
        DeleteOrderRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);

    // ksp_PO_DeleteLines — line-level delete.
    Task DeleteLinesAsync(
        DeleteLinesRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);
}
