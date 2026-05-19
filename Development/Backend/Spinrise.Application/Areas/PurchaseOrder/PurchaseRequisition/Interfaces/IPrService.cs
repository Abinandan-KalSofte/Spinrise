using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

public interface IPrService
{
    Task<PrParametersDto?>           GetParametersAsync(string divCode);
    Task<PreAddChecksDto>            RunPreAddChecksAsync(string divCode);
    Task<IEnumerable<DepartmentDto>> GetDepartmentsAsync(string divCode, string? search);
    Task<IEnumerable<EmployeeDto>>   GetEmployeesAsync(string divCode, string empCommon, string? search);
    Task<IEnumerable<PrTypeDto>>     GetPrTypesAsync(bool activeOnly);
    Task<IEnumerable<ItemLookupDto>> GetItemsAsync(string divCode, string? search, string? itemGrpCode, int page, int pageSize);
    Task<ItemDetailDto?>             GetItemDetailAsync(string divCode, string itemCode, DateOnly fDate, DateOnly lDate, DateOnly pDate);
    Task<PrHeaderDto?>               GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate);
    Task<PrHeaderDto?>               GetByIdAsync(string divCode, decimal prNo, DateOnly prDate);
    Task<IEnumerable<PrSummaryDto>>  GetListAsync(string divCode, DateOnly fDate, DateOnly lDate, string mode, string? depCode, string? reqName, string? poGrp, int page, int pageSize);
    Task<decimal>                    AddAsync(string divCode, SavePrRequest request, string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate);
    Task<decimal>                    ModifyAsync(string divCode, SavePrRequest request, string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate);
    Task                             DeleteAsync(string divCode, DeletePrRequest request, string userId);
    Task<PendingOrderDto?>           CheckPendingOrderAsync(string divCode, DateOnly fDate, DateOnly lDate, string depCode, string itemCode);
    Task<UserPermissionsDto>         GetUserPermissionsAsync(string userId, string divCode);
}
