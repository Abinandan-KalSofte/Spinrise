using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

public interface IPrForeclosureRepository
{
    Task<IEnumerable<PrForeclosureLineDto>> GetOpenForForeclosureAsync(string divCode, DateOnly fDate, DateOnly lDate, string? prNoFilter);
    Task<int> SaveForeclosureAsync(List<PrForeclosureLineKeyDto> lines, string divCode,
        string userId, string? hostName, string? ipAddress);
}
