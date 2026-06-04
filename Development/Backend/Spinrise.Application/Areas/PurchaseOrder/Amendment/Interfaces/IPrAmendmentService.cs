using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;

public interface IPrAmendmentService
{
    Task<IEnumerable<PrAmendmentSummaryDto>> GetListAsync(
        string divCode, DateOnly fDate, DateOnly lDate,
        decimal? prNo, string? search, int page, int pageSize);

    Task<PrAmendmentHeaderDto?> GetByIdAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo);

    Task<PrAmendmentHeaderDto?> GetForNewAsync(
        string divCode, decimal prNo, DateOnly prDate);

    Task<int> AddAsync(
        string divCode, SaveAmendmentRequest request,
        string userId, DateOnly fDate, DateOnly lDate,
        string? hostName, string? ipAddress);

    Task<int> ModifyAsync(
        string divCode, int amendNo, SaveAmendmentRequest request,
        string userId, DateOnly fDate, DateOnly lDate,
        string? hostName, string? ipAddress);

    Task<int> DeleteAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo,
        string rowVersion, string userId, string? hostName, string? ipAddress);

    Task<int> DeleteLineAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo, int prSno,
        string rowVersion, DateOnly pDate, string userId, string? hostName, string? ipAddress);

    Task<PrAmendmentPrintDto?> GetPrintDataAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo);
}
