using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

public class PrService : IPrService
{
    private readonly IPrRepository _repo;

    public PrService(IPrRepository repo)
    {
        _repo = repo;
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
        string? depCode, string? reqName, string? poGrp, int page, int pageSize) =>
        _repo.GetListAsync(divCode, fDate, lDate, mode, depCode, reqName, poGrp, page, pageSize);

    public async Task<decimal> AddAsync(string divCode, SavePrRequest request, string userId,
        string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        ValidateForSave(request, "ADD");
        return await _repo.SaveAsync("ADD", divCode, request, userId, hostName, ipAddress, fDate, lDate);
    }

    public async Task<decimal> ModifyAsync(string divCode, SavePrRequest request, string userId,
        string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        if (request.ExistingPrNo is null || request.ExistingPrDate is null)
            throw new InvalidOperationException("ExistingPrNo and ExistingPrDate are required for Modify.");

        ValidateForSave(request, "MODIFY");
        return await _repo.SaveAsync("MODIFY", divCode, request, userId, hostName, ipAddress, fDate, lDate);
    }

    public Task DeleteAsync(string divCode, DeletePrRequest request, string userId) =>
        _repo.DeleteAsync(divCode, request, userId);

    public Task<PendingOrderDto?> CheckPendingOrderAsync(string divCode, DateOnly fDate, DateOnly lDate,
        string depCode, string itemCode) =>
        _repo.CheckPendingOrderAsync(divCode, fDate, lDate, depCode, itemCode);

    private static void ValidateForSave(SavePrRequest request, string mode)
    {
        if (string.IsNullOrWhiteSpace(request.DepCode))
            throw new InvalidOperationException("Department Cannot be empty.");

        var validLines = request.Lines
            .Where(l => !string.IsNullOrWhiteSpace(l.ItemCode))
            .ToList();

        if (validLines.Count == 0)
            throw new InvalidOperationException("Purchase Requisition Requires at least one Item.");

        foreach (var line in validLines)
        {
            if (line.QtyInd <= 0)
                throw new InvalidOperationException("Required quantity cannot be empty.");

            if (line.RateSource == "MANUAL" && string.IsNullOrWhiteSpace(line.RateJustification))
                throw new InvalidOperationException("Rate justification is required when Manual rate is selected.");
        }
    }
}
