using System.Data;
using System.Text.Json;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.FirstLevelApproval;

public class PrFirstApprovalRepository : IPrFirstApprovalRepository
{
    private readonly IUnitOfWork _uow;

    public PrFirstApprovalRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<PoParaDto?> GetPoParaAsync(string divCode)
    {
        var row = await _uow.Connection.QueryFirstOrDefaultAsync<dynamic>(
            StoredProcedures.PrFirstLevelApproval.GetPoPara,
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);

        if (row is null) return null;

        return new PoParaDto(
            DivCode:       row.DivCode       ?? divCode,
            AppUserLevel1: row.AppUserLevel1 is null ? null : Convert.ToString(Convert.ToDecimal(row.AppUserLevel1)),
            AppUserLevel2: row.AppUserLevel2 is null ? null : Convert.ToString(Convert.ToDecimal(row.AppUserLevel2)),
            AppUserLevel3: row.AppUserLevel3 is null ? null : Convert.ToString(Convert.ToDecimal(row.AppUserLevel3)),
            AppUserLabel1: row.AppUserLabel1 ?? "SM",
            AppUserLabel2: row.AppUserLabel2 ?? "FM",
            AppUserLabel3: row.AppUserLabel3 ?? "GM",
            YFDate:        Convert.ToDateTime(row.YFDate),
            YLDate:        Convert.ToDateTime(row.YLDate)
        );
    }

    public async Task<(string? UserLevel, bool IsFirstLevel)> CheckUserApprovalLevelAsync(string divCode, string userId)
    {
        var row = await _uow.Connection.QueryFirstOrDefaultAsync<dynamic>(
            StoredProcedures.PrFirstLevelApproval.CheckUserLevel,
            new { DivCode = divCode, UserId = userId },
            commandType: CommandType.StoredProcedure);

        if (row is null) return (null, false);

        string? userLevel     = row.UserLevel     is null ? null : Convert.ToString(Convert.ToDecimal(row.UserLevel));
        string? appUserLevel1 = row.AppUserLevel1 is null ? null : Convert.ToString(Convert.ToDecimal(row.AppUserLevel1));

        var isFirstLevel = !string.IsNullOrWhiteSpace(appUserLevel1)
                        && string.Equals(userLevel, appUserLevel1, StringComparison.OrdinalIgnoreCase);

        return (userLevel, isFirstLevel);
    }

    public async Task<IEnumerable<ApprovalDeptDto>> GetDeptForUserAsync(string divCode, string userId)
    {
        return await _uow.Connection.QueryAsync<ApprovalDeptDto>(
            StoredProcedures.PrFirstLevelApproval.GetDeptForUser,
            new { DivCode = divCode, UserId = userId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PrApprovalSummaryDto>> GetPendingListAsync(
        string divCode, string dep, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<PrApprovalSummaryDto>(
            StoredProcedures.PrFirstLevelApproval.GetPendingList,
            new { DivCode = divCode, Dep = dep, YFDate = yfDate, YLDate = ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PrApprovalSummaryDto>> GetApprovedListAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<PrApprovalSummaryDto>(
            StoredProcedures.PrFirstLevelApproval.GetApprovedList,
            new { DivCode = divCode, YFDate = yfDate, YLDate = ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PrApprovalHeaderDto?> GetHeaderAsync(string divCode, decimal prNo, DateTime prDate)
    {
        var row = await _uow.Connection.QueryFirstOrDefaultAsync<dynamic>(
            StoredProcedures.PrFirstLevelApproval.GetHeader,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate },
            commandType: CommandType.StoredProcedure);

        if (row is null) return null;

        return new PrApprovalHeaderDto(
            DivCode:   row.DivCode   as string ?? divCode,
            PrNo:      Convert.ToDecimal(row.PrNo),
            PrDate:    Convert.ToDateTime(row.PrDate),
            DepCode:   row.DepCode   as string ?? string.Empty,
            DepName:   row.DepName   as string ?? string.Empty,
            RefNo:     row.RefNo     as string,
            Section:   row.Section   as string,
            SubCost:   row.SubCost   as string,
            SccName:   row.SccName   as string,
            App1:      row.App1      as string,
            App2:      row.App2      as string,
            App3:      row.App3      as string,
            AppFlg:    row.AppFlg    as string,
            App1Date:  row.App1Date is DateTime d ? (DateTime?)d : null,
            ReqName:   row.ReqName   as string
        );
    }

    public async Task<IEnumerable<PrApprovalLineDto>> GetLinesAsync(string divCode, decimal prNo, DateTime prDate)
    {
        return await _uow.Connection.QueryAsync<PrApprovalLineDto>(
            StoredProcedures.PrFirstLevelApproval.GetLines,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task SaveAsync(string divCode, SaveFirstApprovalRequest request,
        string userId, string userName,
        string? ipAddress, string? hostName, int moduleNo)
    {
        var linesJson = JsonSerializer.Serialize(request.Lines.Select(l => new
        {
            prSno       = l.PrSno,
            itemCode    = l.ItemCode,
            depCode     = l.DepCode,
            qtyReqd     = l.QtyReqd,
            firstAppQty = l.FirstAppQty,
            rate        = l.Rate,
            macNo       = l.MacNo ?? string.Empty,
            subCost     = l.SubCost ?? string.Empty,
            uom         = l.Uom ?? string.Empty,
        }));

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.PrFirstLevelApproval.Save,
            new
            {
                DivCode   = divCode,
                PrNo      = request.PrNo,
                PrDate    = request.PrDate,
                AppDate   = request.AppDate,
                UserId    = userId,
                UserName  = userName,
                IpAddress = ipAddress ?? string.Empty,
                HostName  = hostName  ?? string.Empty,
                ModuleNo  = moduleNo,
                LinesJson = linesJson,
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteAsync(string divCode, DeleteFirstApprovalRequest request,
        string userId, string userName,
        string? ipAddress, string? hostName, int moduleNo)
    {
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.PrFirstLevelApproval.Delete,
            new
            {
                DivCode   = divCode,
                PrNo      = request.PrNo,
                PrDate    = request.PrDate,
                UserId    = userId,
                UserName  = userName,
                IpAddress = ipAddress ?? string.Empty,
                HostName  = hostName  ?? string.Empty,
                ModuleNo  = moduleNo,
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PrApprovalReportDto?> GetReportDataAsync(string divCode, decimal prNo, DateTime prDate, string approverLabel)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrFirstLevelApproval.GetReportData,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate },
            commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<dynamic>();
        if (header is null) return null;

        var lines = (await multi.ReadAsync<PrApprovalReportLineDto>()).ToList();

        return new PrApprovalReportDto(
            DivLogo:         header.DivLogo as byte[],
            DivName:         header.DivName         ?? string.Empty,
            DivPrintName:    header.DivPrintName     ?? string.Empty,
            DivUnitName:     header.DivUnitName      ?? string.Empty,
            DivAddress1:     header.DivAddress1      ?? string.Empty,
            DivAddress2:     header.DivAddress2      ?? string.Empty,
            DivAddress3:     header.DivAddress3      ?? string.Empty,
            DivPinCode:      header.DivPinCode       ?? string.Empty,
            DivState:        header.DivState         ?? string.Empty,
            DivPhone:        header.DivPhone         ?? string.Empty,
            DivEmail:        header.DivEmail         ?? string.Empty,
            DivCode:         divCode,
            PrNo:            Convert.ToDecimal(header.PrNo),
            PrDate:          Convert.ToDateTime(header.PrDate),
            DepCode:         header.DepCode          ?? string.Empty,
            DepName:         header.DepName          ?? string.Empty,
            RefNo:           header.RefNo,
            Section:         header.Section,
            App1Date:        header.App1Date is DateTime d ? (DateTime?)d : null,
            ReqName:         header.ReqName,
            ApproverName:    header.ApproverName,
            ApproverLabel:   approverLabel,
            CreatedBy:       header.CreatedBy        ?? string.Empty,
            CreatedDt:       header.CreatedDt        ?? string.Empty,
            Lines:           lines
        );
    }
}
