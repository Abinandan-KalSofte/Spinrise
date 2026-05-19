using System.Data;
using System.Text.Json;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseRequisition;

public class PrRepository : IPrRepository
{
    private readonly IUnitOfWork _uow;

    public PrRepository(IUnitOfWork uow)
    {
        _uow = uow;
    }

    public async Task<PrParametersDto?> GetParametersAsync(string divCode)
    {
        return await _uow.Connection.QueryFirstOrDefaultAsync<PrParametersDto>(
            StoredProcedures.Pr.GetParameters,
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PreAddChecksDto> RunPreAddChecksAsync(string divCode)
    {
        return await _uow.Connection.QueryFirstAsync<PreAddChecksDto>(
            StoredProcedures.Pr.PreAddChecks,
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<DepartmentDto>> GetDepartmentsAsync(string divCode, string? search)
    {
        return await _uow.Connection.QueryAsync<DepartmentDto>(
            StoredProcedures.Pr.GetDepartments,
            new { DivCode = divCode, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<EmployeeDto>> GetEmployeesAsync(string divCode, string empCommon, string? search)
    {
        return await _uow.Connection.QueryAsync<EmployeeDto>(
            StoredProcedures.Pr.GetEmployees,
            new { DivCode = divCode, EmpCommon = empCommon, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PrTypeDto>> GetPrTypesAsync(bool activeOnly)
    {
        return await _uow.Connection.QueryAsync<PrTypeDto>(
            StoredProcedures.Pr.GetPrTypes,
            new { ActiveOnly = activeOnly ? 1 : 0 },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<ItemLookupDto>> GetItemsAsync(string divCode, string? search, string? itemGrpCode, int page, int pageSize)
    {
        return await _uow.Connection.QueryAsync<ItemLookupDto>(
            StoredProcedures.Pr.GetItems,
            new { DivCode = divCode, Search = search, ItemGrpCode = itemGrpCode, PageNumber = page, PageSize = pageSize },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<ItemDetailDto?> GetItemDetailAsync(string divCode, string itemCode, DateOnly fDate, DateOnly lDate, DateOnly pDate)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.Pr.GetItemDetail,
            new { DivCode = divCode, ItemCode = itemCode, FDate = fDate, LDate = lDate, PDate = pDate },
            commandType: CommandType.StoredProcedure);

        var master = await multi.ReadFirstOrDefaultAsync<dynamic>();
        if (master is null) return null;

        var rates = await multi.ReadFirstOrDefaultAsync<dynamic>();

        return new ItemDetailDto(
            ItemCode:     master.ItemCode,
            ItemName:     master.ItemName,
            Uom:          master.Uom,
            MinLevel:     master.MinLevel,
            ItemImage:    master.ItemImage,
            CurrentStock: rates?.CurrentStock ?? 0m,
            LpoRate:      rates?.LpoRate,
            LpoDate:      rates?.LpoDate is DateTime ld ? (DateOnly?)DateOnly.FromDateTime(ld) : null,
            AvgRate:      rates?.AvgRate
        );
    }

    public async Task<PrHeaderDto?> GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate)
    {
        return await LoadPrAsync(StoredProcedures.Pr.GetLastRecord,
            new { DivCode = divCode, FDate = fDate, LDate = lDate });
    }

    public async Task<PrHeaderDto?> GetByIdAsync(string divCode, decimal prNo, DateOnly prDate)
    {
        return await LoadPrAsync(StoredProcedures.Pr.GetById,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate });
    }

    private async Task<PrHeaderDto?> LoadPrAsync(string spName, object param)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            spName, param, commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<dynamic>();
        if (header is null) return null;

        var lines = (await multi.ReadAsync<PrLineDto>()).ToList();

        return new PrHeaderDto(
            DivCode:    header.DivCode,
            PrNo:       header.PrNo,
            PrDate:     header.PrDate is DateTime pd ? DateOnly.FromDateTime(pd) : default,
            DepCode:    header.DepCode ?? string.Empty,
            DepName:    header.DepName ?? string.Empty,
            ReqName:    header.ReqName ?? string.Empty,
            ReqEmpName: header.ReqEmpName ?? string.Empty,
            Section:    header.Section ?? string.Empty,
            IType:      header.IType ?? string.Empty,
            IDesc:      header.IDesc ?? string.Empty,
            RefNo:      header.RefNo ?? string.Empty,
            PoGrp:      header.PoGrp ?? string.Empty,
            AppFlg:     header.AppFlg ?? "N",
            CancelFlag: header.CancelFlag,
            AmendNo:    header.AmendNo ?? 0m,
            PrStatus:   header.PrStatus ?? "REQUESTED",
            CreatedBy:  header.CreatedBy ?? string.Empty,
            CreatedDt:  header.CreatedDt ?? string.Empty,
            UserId:     header.UserId ?? string.Empty,
            Lines:      lines
        );
    }

    public async Task<IEnumerable<PrSummaryDto>> GetListAsync(string divCode, DateOnly fDate, DateOnly lDate,
        string mode, string? depCode, string? reqName, string? poGrp, int page, int pageSize)
    {
        return await _uow.Connection.QueryAsync<PrSummaryDto>(
            StoredProcedures.Pr.GetList,
            new
            {
                DivCode = divCode, FDate = fDate, LDate = lDate,
                Mode = mode, DepCode = depCode, ReqName = reqName,
                PoGrp = poGrp, PageNumber = page, PageSize = pageSize
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<decimal> SaveAsync(string mode, string divCode, SavePrRequest request,
        string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        var linesJson = JsonSerializer.Serialize(request.Lines);

        var result = await _uow.Connection.QueryFirstAsync<dynamic>(
            StoredProcedures.Pr.Save,
            new
            {
                Mode          = mode,
                DivCode       = divCode,
                PrDate        = request.PrDate,
                DepCode       = request.DepCode,
                ReqName       = request.ReqName,
                Section       = request.Section,
                IType         = request.IType,
                RefNo         = request.RefNo,
                PoGrp         = request.PoGrp,
                UserId        = userId,
                HostName      = hostName,
                IpAddress     = ipAddress,
                ExistingPrNo  = request.ExistingPrNo,
                ExistingPrDate= request.ExistingPrDate,
                LinesJson     = linesJson,
                FDate         = fDate,
                LDate         = lDate
            },
            commandType: CommandType.StoredProcedure);

        return (decimal)result.PrNo;
    }

    public async Task DeleteAsync(string divCode, DeletePrRequest request, string userId)
    {
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Pr.Delete,
            new
            {
                DivCode      = divCode,
                PrNo         = request.PrNo,
                PrDate       = request.PrDate,
                DeleteMode   = request.DeleteMode,
                PrSno        = request.PrSno,
                UserId       = userId,
                DeleteReason = request.DeleteReason
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PendingOrderDto?> CheckPendingOrderAsync(string divCode, DateOnly fDate, DateOnly lDate,
        string depCode, string itemCode)
    {
        return await _uow.Connection.QueryFirstOrDefaultAsync<PendingOrderDto>(
            StoredProcedures.Pr.CheckPendingOrder,
            new { DivCode = divCode, FDate = fDate, LDate = lDate, DepCode = depCode, ItemCode = itemCode },
            commandType: CommandType.StoredProcedure);
    }
}
