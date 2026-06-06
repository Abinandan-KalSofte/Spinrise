using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;

public interface IPrAmendmentRepository
{
    Task<IEnumerable<PrAmendmentSummaryDto>> GetListAsync(
        string divCode, DateOnly fDate, DateOnly lDate,
        decimal? prNo, string? search, int page, int pageSize);

    Task<PrAmendmentHeaderDto?> GetByIdAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo);

    Task<PrAmendmentHeaderDto?> GetForNewAsync(
        string divCode, decimal prNo, DateOnly prDate);

    Task<int> SaveAsync(
        string divCode, decimal prNo, DateOnly prDate,
        SaveAmendmentRequest request, string userId, DateOnly fDate, DateOnly lDate,
        string? hostName, string? ipAddress);

    Task<PrAmendmentPrintDto?> GetPrintDataAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo, string userId);
}
