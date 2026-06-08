using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

public class PrService : IPrService
{
    private readonly IPrRepository _repo;
    private readonly ILogger<PrService> _logger;

    public PrService(IPrRepository repo, ILogger<PrService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public Task<PrParametersDto?> GetParametersAsync(string divCode) =>
        _repo.GetParametersAsync(divCode);

    public Task<PreAddChecksDto> RunPreAddChecksAsync(string divCode) =>
        _repo.RunPreAddChecksAsync(divCode);

    public Task<IEnumerable<DepartmentDto>> GetDepartmentsAsync(string divCode, string? search) =>
        _repo.GetDepartmentsAsync(divCode, search);

    public Task<IEnumerable<EmployeeDto>> GetEmployeesAsync(string divCode, string empCommon, string? search) =>
        _repo.GetEmployeesAsync(divCode, empCommon, search);

    public Task<IEnumerable<PrTypeDto>> GetPrTypesAsync(bool activeOnly) =>
        _repo.GetPrTypesAsync(activeOnly);

    public Task<IEnumerable<ItemLookupDto>> GetItemsAsync(string divCode, string? search, string? itemGrpCode, int page, int pageSize) =>
        _repo.GetItemsAsync(divCode, search, itemGrpCode, page, pageSize);

    public Task<ItemDetailDto?> GetItemDetailAsync(string divCode, string itemCode, DateOnly fDate, DateOnly lDate, DateOnly pDate) =>
        _repo.GetItemDetailAsync(divCode, itemCode, fDate, lDate, pDate);

    public Task<PrHeaderDto?> GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate) =>
        _repo.GetLastRecordAsync(divCode, fDate, lDate);

    public Task<PrHeaderDto?> GetByIdAsync(string divCode, decimal prNo, DateOnly prDate) =>
        _repo.GetByIdAsync(divCode, prNo, prDate);

    public Task<IEnumerable<PrSummaryDto>> GetListAsync(string divCode, DateOnly fDate, DateOnly lDate, string mode,
        string? depCode, string? reqName, string? poGrp, string? search, int page, int pageSize) =>
        _repo.GetListAsync(divCode, fDate, lDate, mode, depCode, reqName, poGrp, search, page, pageSize);

    public async Task<decimal> AddAsync(string divCode, SavePrRequest request, string userId,
        string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        ValidateForSave(request, "ADD");
        var prNo = await _repo.SaveAsync("ADD", divCode, request, userId, hostName, ipAddress, fDate, lDate);
        _logger.LogInformation("PR Add | Div: {DivCode} | PR: {PrNo} | User: {UserId}", divCode, prNo, userId);
        return prNo;
    }

    public async Task<decimal> ModifyAsync(string divCode, SavePrRequest request, string userId,
        string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        if (request.ExistingPrNo is null || request.ExistingPrDate is null)
            throw new InvalidOperationException("PR number and date are required to update this record.");

        ValidateForSave(request, "MODIFY");
        var prNo = await _repo.SaveAsync("MODIFY", divCode, request, userId, hostName, ipAddress, fDate, lDate);
        _logger.LogInformation("PR Modify | Div: {DivCode} | PR: {PrNo} | User: {UserId}", divCode, prNo, userId);
        return prNo;
    }

    public async Task DeleteAsync(string divCode, DeletePrRequest request, string userId, string? hostName, string? ipAddress)
    {
        await _repo.DeleteAsync(divCode, request, userId, hostName, ipAddress);
        _logger.LogInformation("PR Delete | Div: {DivCode} | PR: {PrNo} | User: {UserId}", divCode, request.PrNo, userId);
    }

    public Task<PendingOrderDto?> CheckPendingOrderAsync(string divCode, DateOnly fDate, DateOnly lDate,
        string depCode, string itemCode) =>
        _repo.CheckPendingOrderAsync(divCode, fDate, lDate, depCode, itemCode);

    public Task<UserPermissionsDto> GetUserPermissionsAsync(string userId, string divCode) =>
        _repo.GetUserPermissionsAsync(userId, divCode);

    public Task<IEnumerable<MachineLookupDto>> GetMachineLookupAsync(string divCode, string depCode, string? search) =>
        _repo.GetMachineLookupAsync(divCode, depCode, search);

    public Task<IEnumerable<CostCentreDto>> GetCostCentreLookupAsync(string divCode, string? search) =>
        _repo.GetCostCentreLookupAsync(divCode, search);

    public Task<PrPrintDto?> GetPrintDataAsync(string divCode, decimal prNo, DateOnly prDate) =>
        _repo.GetPrintDataAsync(divCode, prNo, prDate);

    public Task<string?> GetItemImagePathAsync(string itemCode) =>
        _repo.GetItemImagePathAsync(itemCode);

    private static void ValidateForSave(SavePrRequest request, string mode)
    {
        if (string.IsNullOrWhiteSpace(request.DepCode))
            throw new InvalidOperationException("Please select a department before saving.");

        var validLines = request.Lines
            .Where(l => !string.IsNullOrWhiteSpace(l.ItemCode))
            .ToList();

        if (validLines.Count == 0)
            throw new InvalidOperationException("Please add at least one item to the requisition.");

        foreach (var line in validLines)
        {
            if (line.QtyInd <= 0)
                throw new InvalidOperationException("Required quantity must be greater than zero for all items.");

            if (line.RateSource == "MANUAL" && string.IsNullOrWhiteSpace(line.RateJustification))
                throw new InvalidOperationException("Please enter a rate justification for all items with a manual rate.");
        }
    }
}
