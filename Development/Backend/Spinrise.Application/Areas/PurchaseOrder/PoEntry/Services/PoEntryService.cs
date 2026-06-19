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

    public Task<IEnumerable<BankOptionDto>> GetBanksAsync(string divCode, string? search) =>
        _repo.GetBanksAsync(divCode, search);

    public Task<IEnumerable<FormTypeOptionDto>> GetFormTypesAsync() =>
        _repo.GetFormTypesAsync();

    public Task<IEnumerable<GstTaxCodeOptionDto>> GetGstTaxCodesAsync(string? search) =>
        _repo.GetGstTaxCodesAsync(search);

    public Task<IEnumerable<AddressOptionDto>> GetAddressesAsync(string divCode, string kind, string? search) =>
        _repo.GetAddressesAsync(divCode, kind, search);

    public Task<IEnumerable<CurrencyOptionDto>> GetCurrenciesAsync(string? search) =>
        _repo.GetCurrenciesAsync(search);

    public Task<IEnumerable<AddressOptionDto>> GetPricingTermsAsync(string? search) =>
        _repo.GetPricingTermsAsync(search);

    public Task<IEnumerable<PayTermOptionDto>> GetPayTermsAsync() =>
        _repo.GetPayTermsAsync();

    public Task<GstRoutingResultDto> GetGstRoutingAsync(string divCode, string slCode) =>
        _repo.GetGstRoutingAsync(divCode, slCode);

    public Task<IEnumerable<EligiblePrLineDto>> GetEligiblePrLinesAsync(
        string divCode, string? orderType, string? search, int page, int pageSize) =>
        _repo.GetEligiblePrLinesAsync(divCode, orderType, search, page, pageSize);

    public Task<IEnumerable<PoSummaryDto>> GetListAsync(
        string divCode, DateOnly fDate, DateOnly lDate, string? search, string? supplier, int page, int pageSize) =>
        _repo.GetListAsync(divCode, fDate, lDate, search, supplier, page, pageSize);

    public Task<PoHeaderDto?> GetByIdAsync(string divCode, decimal poNo, DateOnly poDate) =>
        _repo.GetByIdAsync(divCode, poNo, poDate);

    public Task<PoHeaderDto?> GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate) =>
        _repo.GetLastRecordAsync(divCode, fDate, lDate);

    public async Task<PoSaveResultDto> AddAsync(string divCode, AddPoRequest request,
        string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        // OA-03: qty > 0 with no date → 400 (reversed from silent-skip per Sasi/CEO 17-Jun-2026)
        foreach (var line in request.Lines)
            foreach (var slot in line.Slots)
                if (slot.Qty > 0 && slot.ShDate is null)
                    throw new InvalidOperationException(
                        $"Delivery slot date is required when quantity is specified (item: {line.ItemCode}, slot {slot.SlotNo}).");

        // POT-PM-04: Advance Amount cannot exceed PO Order Value (base Rate×Qty — matches SP @OrdVal)
        if (request.Header.AdvAmt > 0)
        {
            var orderValue = Math.Round(request.Lines.Sum(l => l.Rate * l.Qty), 2);
            if (orderValue > 0 && request.Header.AdvAmt > orderValue)
                throw new InvalidOperationException(
                    $"Advance Amount ({request.Header.AdvAmt:N2}) cannot exceed PO Order Value ({orderValue:N2}).");
        }

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

    public Task<PoPrintDto?> GetPrintDataAsync(string divCode, decimal poNo, DateOnly poDate) =>
        _repo.GetPrintDataAsync(divCode, poNo, poDate);

    public Task UpdatePrintFlagAsync(string divCode, decimal poNo, DateOnly poDate) =>
        _repo.UpdatePrintFlagAsync(divCode, poNo, poDate);
}
