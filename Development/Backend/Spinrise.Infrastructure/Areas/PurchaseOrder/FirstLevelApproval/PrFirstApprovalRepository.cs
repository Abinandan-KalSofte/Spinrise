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
        var row = await _uow.Connection.QueryFirstOrDefaultAsync<PoParaRow>(
            StoredProcedures.PrFirstLevelApproval.GetPoPara,
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);

        if (row is null) return null;

        return new PoParaDto(
            DivCode:       row.DivCode ?? divCode,
            AppUserLevel1: row.AppUserLevel1.HasValue ? row.AppUserLevel1.Value.ToString("0") : null,
            AppUserLevel2: row.AppUserLevel2.HasValue ? row.AppUserLevel2.Value.ToString("0") : null,
            AppUserLevel3: row.AppUserLevel3.HasValue ? row.AppUserLevel3.Value.ToString("0") : null,
            AppUserLabel1: row.AppUserLabel1 ?? "SM",
            AppUserLabel2: row.AppUserLabel2 ?? "FM",
            AppUserLabel3: row.AppUserLabel3 ?? "GM",
            YFDate:        row.YFDate,
            YLDate:        row.YLDate
        );
    }

    public async Task<(string? UserLevel, bool IsFirstLevel)> CheckUserApprovalLevelAsync(string divCode, string userId)
    {
        var row = await _uow.Connection.QueryFirstOrDefaultAsync<CheckLevelRow>(
            StoredProcedures.PrFirstLevelApproval.CheckUserLevel,
            new { DivCode = divCode, UserId = userId },
            commandType: CommandType.StoredProcedure);

        if (row is null) return (null, false);

        string userLevel     = row.UserLevel.ToString("0");
        string appUserLevel1 = row.AppUserLevel1.ToString("0");

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
        return await _uow.Connection.QueryFirstOrDefaultAsync<PrApprovalHeaderDto>(
            StoredProcedures.PrFirstLevelApproval.GetHeader,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate },
            commandType: CommandType.StoredProcedure);
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

        var header = await multi.ReadFirstOrDefaultAsync<ReportHeaderRow>();
        if (header is null) return null;

        var lines = (await multi.ReadAsync<PrApprovalReportLineDto>()).ToList();

        return new PrApprovalReportDto(
            DivLogo:         header.DivLogo,
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
            PrNo:            header.PrNo,
            PrDate:          header.PrDate,
            DepCode:         header.DepCode          ?? string.Empty,
            DepName:         header.DepName          ?? string.Empty,
            RefNo:           header.RefNo,
            Section:         header.Section,
            App1Date:        header.App1Date,
            ReqName:         header.ReqName,
            ApproverName:    header.ApproverName,
            ApproverLabel:   approverLabel,
            CreatedBy:       header.CreatedBy        ?? string.Empty,
            CreatedDt:       header.CreatedDt        ?? string.Empty,
            Lines:           lines
        );
    }

    // Property classes — Dapper maps by name, so SP column order and additions never cause constructor errors.
    private sealed class PoParaRow
    {
        public string?   DivCode        { get; init; }
        public decimal?  AppUserLevel1  { get; init; }
        public decimal?  AppUserLevel2  { get; init; }
        public decimal?  AppUserLevel3  { get; init; }
        public string?   AppUserLabel1  { get; init; }
        public string?   AppUserLabel2  { get; init; }
        public string?   AppUserLabel3  { get; init; }
        public DateTime  YFDate         { get; init; }
        public DateTime  YLDate         { get; init; }
    }

    private sealed class CheckLevelRow
    {
        public decimal   UserLevel      { get; init; }
        public decimal   AppUserLevel1  { get; init; }
        public decimal   AppUserLevel2  { get; init; }
        public decimal   AppUserLevel3  { get; init; }
        public string?   AppUserLabel1  { get; init; }
        public string?   AppUserLabel2  { get; init; }
        public string?   AppUserLabel3  { get; init; }
    }

    private sealed class ReportHeaderRow
    {
        public byte[]?   DivLogo        { get; init; }
        public string?   DivName        { get; init; }
        public string?   DivPrintName   { get; init; }
        public string?   DivUnitName    { get; init; }
        public string?   DivAddress1    { get; init; }
        public string?   DivAddress2    { get; init; }
        public string?   DivAddress3    { get; init; }
        public string?   DivPinCode     { get; init; }
        public string?   DivState       { get; init; }
        public string?   DivPhone       { get; init; }
        public string?   DivEmail       { get; init; }
        public decimal   PrNo           { get; init; }
        public DateTime  PrDate         { get; init; }
        public string?   DepCode        { get; init; }
        public string?   DepName        { get; init; }
        public string?   RefNo          { get; init; }
        public string?   Section        { get; init; }
        public DateTime? App1Date       { get; init; }
        public string?   ReqName        { get; init; }
        public string?   ApproverName   { get; init; }
        public string?   CreatedBy      { get; init; }
        public string?   CreatedDt      { get; init; }
    }
}
