using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Services;

// FN §3 defence-in-depth: at least one line selected. Balance is never trusted from
// the client — the SP recomputes it server-side per line (FN §4A).
public class PoForeclosureService : IPoForeclosureService
{
    private readonly IPoForeclosureRepository _repo;

    public PoForeclosureService(IPoForeclosureRepository repo) => _repo = repo;

    public Task<IEnumerable<PoForeclosureLineDto>> GetOpenLinesAsync(string divCode) =>
        _repo.GetOpenLinesAsync(divCode);

    public async Task<int> ForecloseLinesAsync(
        ForeclosureSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        if (request.Lines is null || request.Lines.Count == 0)
            throw new InvalidOperationException("Select at least one item to complete the transaction.");

        return await _repo.ForecloseLinesAsync(request, divCode, transDate, userId, hostName, ipAddress);
    }
}
