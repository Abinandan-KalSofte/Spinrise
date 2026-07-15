using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Services;

// FN §3 defence-in-depth: only the checks that need no server recompute live here.
// Budget (§3.9), GST tax-code activity (§3.5), the RCVDQTY+CANQTY floor (§3.4
// dynamic half) and the changed-line AmendReason re-check (§3.6) are the SP's
// (FN §4.B — "do not trust client-sent amounts"). Rate>0 / Qty>0 (§3.4 static) are
// enforced by DataAnnotations on AmendmentLineSaveDto at model binding.
public class PoAmendmentService : IPoAmendmentService
{
    private readonly IPoAmendmentRepository _repo;

    public PoAmendmentService(IPoAmendmentRepository repo) => _repo = repo;

    public Task<IEnumerable<AmendablePoSummaryDto>> GetAmendablePOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate) =>
        _repo.GetAmendablePOListAsync(divCode, yfDate, ylDate);

    public Task<PoAmendmentHeaderDto?> GetPOForAmendAsync(
        string divCode, decimal poNo, string poDate, string poGrp) =>
        _repo.GetPOForAmendAsync(divCode, poNo, poDate, poGrp);

    public Task<IEnumerable<AmendmentSummaryDto>> GetAmendmentListAsync(
        string divCode, DateTime yfDate, DateTime ylDate) =>
        _repo.GetAmendmentListAsync(divCode, yfDate, ylDate);

    public async Task<AmendmentSaveResponseDto> SaveAmendmentAsync(
        AmendmentSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        // §3.1 — at least one line (VB6 saved zero-change amendments; blocked here).
        if (request.Lines is null || request.Lines.Count == 0)
            throw new InvalidOperationException(
                "No changes to amend — modify at least one item to complete the transaction.");

        // §3.2 — Carrier mandatory.
        if (string.IsNullOrWhiteSpace(request.Carrier))
            throw new InvalidOperationException("Carrier cannot be empty.");

        // §3.3 — Order Type (PO Group) mandatory.
        if (string.IsNullOrWhiteSpace(request.PoGroup))
            throw new InvalidOperationException("Order Type cannot be empty.");

        // Supplier became amendable on the 13-Jul ruling (header follows VB6), so it
        // now has to be validated on the way in. Existence is checked in the SP against
        // FA_SLMAS — a code that isn't in the master must not reach the UPDATE, because
        // the GST route is derived from that master row.
        if (string.IsNullOrWhiteSpace(request.Supplier))
            throw new InvalidOperationException("Supplier cannot be empty.");

        var amendNo = await _repo.SaveAmendmentAsync(
            request, divCode, transDate, userId, hostName, ipAddress);

        return new AmendmentSaveResponseDto(
            amendNo,
            $"Amendment Saved Successfully — Amendment No: {amendNo}.");
    }

    public async Task DeleteOrderAsync(
        DeleteOrderRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        if (string.IsNullOrWhiteSpace(request.PoGroup))
            throw new InvalidOperationException("Order Type cannot be empty.");

        await _repo.DeleteOrderAsync(request, divCode, transDate, userId, hostName, ipAddress);
    }

    public async Task DeleteLinesAsync(
        DeleteLinesRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        if (request.Lines is null || request.Lines.Count == 0)
            throw new InvalidOperationException("Select at least one line to delete.");

        await _repo.DeleteLinesAsync(request, divCode, transDate, userId, hostName, ipAddress);
    }
}
