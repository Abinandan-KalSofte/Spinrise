using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Shared.Models;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

public interface IPrForeclosureService
{
    Task<IEnumerable<PrForeclosureLineDto>> GetOpenLinesAsync(string divCode, DateOnly fDate, DateOnly lDate, string? prNoFilter);
    Task<int> SaveForeclosureAsync(PrForeclosureSaveRequestDto request, string divCode,
        string userId, string? hostName, string? ipAddress);
}
