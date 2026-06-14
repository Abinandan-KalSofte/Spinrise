using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.Interfaces;

public interface IPoEntryService
{
    Task<PoParametersDto?>                GetParametersAsync(string divCode);
    Task<PoPreAddChecksDto>               GetPreAddChecksAsync(string divCode);
    Task<PoUserPermissionsDto>            GetUserPermissionsAsync(string userId, string divCode);
    Task<IEnumerable<SupplierOptionDto>>  GetSuppliersAsync(string divCode, string? search);
    Task<IEnumerable<OrderTypeOptionDto>> GetOrderTypesAsync(bool activeOnly);
    Task<IEnumerable<CarrierOptionDto>>   GetCarriersAsync(string? search);
    Task<IEnumerable<BankOptionDto>>      GetBanksAsync(string? search);
    Task<IEnumerable<FormTypeOptionDto>>  GetFormTypesAsync();
    Task<IEnumerable<GstTaxCodeOptionDto>>  GetGstTaxCodesAsync(string? search);
    Task<IEnumerable<AddressOptionDto>>     GetAddressesAsync(string divCode, string kind, string? search);
    Task<GstRoutingResultDto>             GetGstRoutingAsync(string divCode, string slCode);
    Task<IEnumerable<EligiblePrLineDto>>  GetEligiblePrLinesAsync(string divCode, string? orderType, string? search, int page, int pageSize);
    Task<IEnumerable<PoSummaryDto>>       GetListAsync(string divCode, DateOnly fDate, DateOnly lDate, string? search, string? supplier, int page, int pageSize);
    Task<PoHeaderDto?>                    GetByIdAsync(string divCode, decimal poNo, DateOnly poDate);
    Task<PoHeaderDto?>                    GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate);
    Task<PoSaveResultDto>                 AddAsync(string divCode, AddPoRequest request, string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate);
    Task                                  DeleteAsync(string divCode, DeletePoRequest request, string userId, string? hostName, string? ipAddress);
    Task<PoPrintDto?>                     GetPrintDataAsync(string divCode, decimal poNo, DateOnly poDate);
    Task                                  UpdatePrintFlagAsync(string divCode, decimal poNo, DateOnly poDate);
}
