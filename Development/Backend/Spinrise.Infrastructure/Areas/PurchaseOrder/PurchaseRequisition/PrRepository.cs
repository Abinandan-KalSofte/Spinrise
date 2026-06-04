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

        var master = await multi.ReadFirstOrDefaultAsync<ItemMasterRow>();
        if (master is null) return null;

        var rates = await multi.ReadFirstOrDefaultAsync<ItemRatesRow>();

        return new ItemDetailDto(
            ItemCode:     master.ItemCode     ?? string.Empty,
            ItemName:     master.ItemName     ?? string.Empty,
            Uom:          master.Uom          ?? string.Empty,
            MinLevel:     master.MinLevel,
            MaxLevel:     master.MaxLevel,
            ItemImage:    master.ItemImage,
            ImagePath:    string.IsNullOrWhiteSpace(master.ImagePath) ? null : master.ImagePath,
            CurrentStock: rates?.CurrentStock ?? 0m,
            LpoRate:      rates?.LpoRate,
            LpoDate:      rates?.LpoDate.HasValue == true ? DateOnly.FromDateTime(rates.LpoDate.Value) : null,
            AvgRate:      rates?.AvgRate
        );
    }

    public async Task<string?> GetItemImagePathAsync(string itemCode)
    {
        var result = await _uow.Connection.QueryFirstOrDefaultAsync<string>(
            StoredProcedures.Pr.GetItemImagePath,
            new { ItemCode = itemCode },
            commandType: CommandType.StoredProcedure);
        return string.IsNullOrWhiteSpace(result) ? null : result;
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

        var header = await multi.ReadFirstOrDefaultAsync<PrHeaderRow>();
        if (header is null) return null;

        var lines = (await multi.ReadAsync<PrLineDto>()).ToList();

        return new PrHeaderDto(
            DivCode:      header.DivCode     ?? string.Empty,
            PrNo:         header.PrNo,
            PrDate:       header.PrDate.HasValue ? DateOnly.FromDateTime(header.PrDate.Value) : default,
            DepCode:      header.DepCode     ?? string.Empty,
            DepName:      header.DepName     ?? string.Empty,
            ReqName:      header.ReqName     ?? string.Empty,
            ReqEmpName:   header.ReqEmpName  ?? string.Empty,
            Section:      header.Section     ?? string.Empty,
            IType:        header.IType       ?? string.Empty,
            IDesc:        header.IDesc       ?? string.Empty,
            RefNo:        header.RefNo       ?? string.Empty,
            PoGrp:        header.PoGrp       ?? string.Empty,
            AppFlg:       header.AppFlg      ?? "N",
            CancelFlag:   null,
            CancelReason: null,
            AmendNo:      0m,
            PrStatus:     header.PrStatus    ?? "REQUESTED",
            CreatedBy:    header.CreatedBy   ?? string.Empty,
            CreatedDt:    header.CreatedDt   ?? string.Empty,
            UserId:       header.UserId      ?? string.Empty,
            Lines:        lines
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

        var result = await _uow.Connection.QueryFirstAsync<PrSaveResult>(
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

        return result.PrNo;
    }

    public async Task DeleteAsync(string divCode, DeletePrRequest request, string userId, string? hostName, string? ipAddress)
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
                DeleteReason = request.DeleteReason,
                HostName     = hostName,
                IpAddress    = ipAddress
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

    public async Task<UserPermissionsDto> GetUserPermissionsAsync(string userId, string divCode)
    {
        var row = await _uow.Connection.QueryFirstOrDefaultAsync<UserPermissionsRaw>(
            StoredProcedures.Pr.GetUserPermissions,
            new { UserId = userId, DivCode = divCode },
            commandType: CommandType.StoredProcedure);

        return row is null
            ? new UserPermissionsDto(true, true, true)
            : new UserPermissionsDto(row.CanAdd == 1, row.CanModify == 1, row.CanDelete == 1);
    }

    public async Task<IEnumerable<MachineLookupDto>> GetMachineLookupAsync(string divCode, string depCode, string? search)
    {
        return await _uow.Connection.QueryAsync<MachineLookupDto>(
            StoredProcedures.Pr.GetMachineLookup,
            new { DivCode = divCode, DepCode = depCode, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<CostCentreDto>> GetCostCentreLookupAsync(string divCode, string? search)
    {
        return await _uow.Connection.QueryAsync<CostCentreDto>(
            StoredProcedures.Pr.GetCostCentreLookup,
            new { DivCode = divCode, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    private record PrSaveResult(decimal PrNo);
    private record UserPermissionsRaw(int CanAdd, int CanModify, int CanDelete);

    // Raw row types for SP result sets that have no matching DTO constructor
    private sealed record ItemMasterRow(
        string?  ItemCode,
        string?  ItemName,
        string?  Uom,
        decimal  MinLevel,
        decimal  MaxLevel,
        byte[]?  ItemImage,
        string?  ImagePath);

    private sealed record ItemRatesRow(
        decimal   CurrentStock,
        decimal?  LpoRate,
        DateTime? LpoDate,
        decimal?  AvgRate);

    private sealed record PrHeaderRow(
        string?   DivCode,
        decimal   PrNo,
        DateTime? PrDate,
        string?   DepCode,
        string?   DepName,
        string?   ReqName,
        string?   ReqEmpName,
        string?   Section,
        string?   IType,
        string?   IDesc,
        string?   RefNo,
        string?   PoGrp,
        string?   AppFlg,
        string?   PrStatus,
        string?   CreatedBy,
        string?   CreatedDt,
        string?   UserId);

    public async Task<PrPrintDto?> GetPrintDataAsync(string divCode, decimal prNo, DateOnly prDate)
    {
        var rows = (await _uow.Connection.QueryAsync<PrPrintRowDto>(
            StoredProcedures.Pr.GetPrint,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate },
            commandType: CommandType.StoredProcedure)).ToList();

        if (rows.Count == 0) return null;

        var h = rows[0];

        var firstApp     = rows.FirstOrDefault(r => !string.IsNullOrWhiteSpace(r.FirstAppUser));
        var secondApp    = rows.FirstOrDefault(r => !string.IsNullOrWhiteSpace(r.SecondAppUser));
        var thirdApp     = rows.FirstOrDefault(r => !string.IsNullOrWhiteSpace(r.ThirdAppUser));
        var finalApp     = rows.FirstOrDefault(r => !string.IsNullOrWhiteSpace(r.FinalAppUser));
        var presidentRow = rows.FirstOrDefault(r => !string.IsNullOrWhiteSpace(r.PresidentAppDate));

        var lines = rows.Select(r => new PrPrintLineDto(
            PrSno:        r.PrSno,
            ItemCode:     r.ItemCode,
            ItemName:     r.ItemName,
            Uom:          r.Uom,
            CatNo:        r.CatNo,
            DrawNo:       r.DrawNo,
            MacNo:        r.MacNo,
            MacModel:     r.MacModel,
            MacMake:      r.MacMake,
            QtyInd:       r.QtyInd,
            ReqdDate:     r.ReqdDate,
            Rate:         r.Rate,
            LastPoRate:   r.LastPoRate,
            LastPoDate:   r.LastPoDate,
            CurrentStock: r.CurrentStock,
            AppCost:      r.AppCost,
            Remarks:      r.Remarks
        )).ToList();

        return new PrPrintDto(
            DivLogo:          h.DivLogo,
            DivName:          h.DivName,
            DivPrintName:     h.DivPrintName,
            DivUnitName:      h.DivUnitName,
            DivAddress1:      h.DivAddress1,
            DivAddress2:      h.DivAddress2,
            DivAddress3:      h.DivAddress3,
            DivPinCode:       h.DivPinCode,
            DivState:         h.DivState,
            DivPhone:         h.DivPhone,
            DivEmail:         h.DivEmail,
            DivCode:          h.DivCode,
            PrNo:             h.PrNo,
            PrDate:           h.PrDate,
            DepCode:          h.DepCode,
            DepName:          h.DepName,
            ReqName:          h.ReqName,
            ReqEmpName:       h.ReqEmpName,
            Section:          h.Section,
            RefNo:            h.RefNo,
            PoGrp:            h.PoGrp,
            IDesc:            h.IDesc,
            AppFlg:           h.AppFlg,
            CreatedBy:        h.CreatedBy,
            CreatedDt:        h.CreatedDt,
            FirstAppUser:     firstApp?.FirstAppUser      ?? "",
            SecondAppUser:    secondApp?.SecondAppUser    ?? "",
            ThirdAppUser:     thirdApp?.ThirdAppUser      ?? "",
            FinalAppUser:     finalApp?.FinalAppUser      ?? "",
            PresidentAppDate: presidentRow?.PresidentAppDate ?? "",
            Lines: lines
        );
    }
}
