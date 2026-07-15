using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Interfaces;

public interface IPoForeclosureRepository
{
    Task<IEnumerable<PoForeclosureLineDto>> GetOpenLinesAsync(string divCode);

    Task<int> ForecloseLinesAsync(
        ForeclosureSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress);
}
