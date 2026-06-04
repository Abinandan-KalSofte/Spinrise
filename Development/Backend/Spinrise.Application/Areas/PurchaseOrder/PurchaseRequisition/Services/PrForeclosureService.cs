using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

public class PrForeclosureService : IPrForeclosureService
{
    private readonly IPrForeclosureRepository _repo;

    public PrForeclosureService(IPrForeclosureRepository repo) => _repo = repo;

    public Task<IEnumerable<PrForeclosureLineDto>> GetOpenLinesAsync(string divCode, DateOnly fDate, DateOnly lDate, string? prNoFilter) =>
        _repo.GetOpenForForeclosureAsync(divCode, fDate, lDate, prNoFilter);

    public async Task<int> SaveForeclosureAsync(PrForeclosureSaveRequestDto request, string divCode,
        string userId, string? hostName, string? ipAddress)
    {
        if (request.Lines == null || request.Lines.Count == 0)
            throw new InvalidOperationException("Select at least one item to complete the transaction.");

        return await _repo.SaveForeclosureAsync(request.Lines, divCode, userId, hostName, ipAddress);
    }
}
