using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.Services;

public class PoEntryService : IPoEntryService
{
    private readonly IPoEntryRepository _repo;
    private readonly ILogger<PoEntryService> _logger;

    public PoEntryService(IPoEntryRepository repo, ILogger<PoEntryService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public Task<PoParametersDto?> GetParametersAsync(string divCode) =>
        _repo.GetParametersAsync(divCode);

    public Task<PoPreAddChecksDto> GetPreAddChecksAsync(string divCode) =>
        _repo.GetPreAddChecksAsync(divCode);

    public Task<PoUserPermissionsDto> GetUserPermissionsAsync(string userId, string divCode) =>
        _repo.GetUserPermissionsAsync(userId, divCode);

    public Task<IEnumerable<SupplierOptionDto>> GetSuppliersAsync(string divCode, string? search) =>
        _repo.GetSuppliersAsync(divCode, search);

    public Task<IEnumerable<OrderTypeOptionDto>> GetOrderTypesAsync(bool activeOnly) =>
        _repo.GetOrderTypesAsync(activeOnly);

    public Task<IEnumerable<CarrierOptionDto>> GetCarriersAsync(string? search) =>
        _repo.GetCarriersAsync(search);

    public Task<IEnumerable<BankOptionDto>> GetBanksAsync(string? search) =>
        _repo.GetBanksAsync(search);

    public Task<IEnumerable<FormTypeOptionDto>> GetFormTypesAsync() =>
        _repo.GetFormTypesAsync();

    public Task<IEnumerable<GstTaxCodeOptionDto>> GetGstTaxCodesAsync(string? search) =>
        _repo.GetGstTaxCodesAsync(search);

    public Task<GstRoutingResultDto> GetGstRoutingAsync(string divCode, string slCode) =>
        _repo.GetGstRoutingAsync(divCode, slCode);

    public Task<IEnumerable<EligiblePrLineDto>> GetEligiblePrLinesAsync(
        string divCode, string? orderType, string? search, int page, int pageSize) =>
        _repo.GetEligiblePrLinesAsync(divCode, orderType, search, page, pageSize);

    public Task<PoHeaderDto?> GetByIdAsync(string divCode, decimal poNo, DateOnly poDate) =>
        _repo.GetByIdAsync(divCode, poNo, poDate);

    public Task<PoHeaderDto?> GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate) =>
        _repo.GetLastRecordAsync(divCode, fDate, lDate);

    public async Task<PoSaveResultDto> AddAsync(string divCode, AddPoRequest request,
        string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        var result = await _repo.SaveAsync(divCode, request, userId, hostName, ipAddress, fDate, lDate);
        _logger.LogInformation("PO Add | Div: {DivCode} | PO: {PoNo} | User: {UserId}", divCode, result.PoNo, userId);
        return result;
    }

    public async Task DeleteAsync(string divCode, DeletePoRequest request,
        string userId, string? hostName, string? ipAddress)
    {
        await _repo.DeleteAsync(divCode, request, userId, hostName, ipAddress);
        _logger.LogInformation("PO Delete | Div: {DivCode} | PO: {PoNo} | User: {UserId}", divCode, request.PoNo, userId);
    }
}
