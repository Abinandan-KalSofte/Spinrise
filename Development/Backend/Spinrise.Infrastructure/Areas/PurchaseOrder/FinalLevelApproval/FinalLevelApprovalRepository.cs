using System.Data;
using System.Globalization;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.FinalLevelApproval;

public class FinalLevelApprovalRepository : IFinalLevelApprovalRepository
{
    private readonly IUnitOfWork _uow;

    public FinalLevelApprovalRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<FinalApprovalLineDto>> GetPendingAsync(int imode, string divCode, int bypass)
    {
        var rows = await _uow.Connection.QueryAsync<FinalApprovalLineRow>(
            StoredProcedures.PrFinalLevelApproval.Approve,
            new { imode, divcode = divCode, Bypass = bypass, Result = 0 },
            commandType: CommandType.StoredProcedure);

        return rows.Select(r => new FinalApprovalLineDto(
            DivCode:        r.DivCode        ?? string.Empty,
            PrNo:           r.PrNo,
            PrDate:         r.PrDate         ?? string.Empty,
            PrSno:          r.PrSno,
            DbName:         string.Empty,
            Department:     r.Department     ?? string.Empty,
            ItemCode:       r.ItemCode       ?? string.Empty,
            ItemName:       r.ItemName       ?? string.Empty,
            Uom:            r.Uom            ?? string.Empty,
            CurrentStock:   r.CurrentStock,
            QtyRequired:    r.QtyRequired,
            QtyApproved:    r.QtyApproved,
            Disposition:    r.Disposition,
            LpoRate:        r.LpoRate,
            LpoDate:        r.LpoDate,
            ApproxCost:     r.ApproxCost,
            ApprovalStatus: r.ApprovalStatus ?? "first",
            RowVersion:     r.RowVersion is not null ? Convert.ToHexString(r.RowVersion) : string.Empty
        ));
    }

    public async Task<int> SaveItemAsync(FinalApprovalSaveItemRequest item, string finalAppUser, int bypass)
    {
        // SP returns date as DD/MM/YYYY (CONVERT format 103) — ParseExact required
        var prDate = DateTime.ParseExact(item.PrDate, "dd/MM/yyyy", CultureInfo.InvariantCulture);

        // rowVersion is uppercase hex from Convert.ToHexString (no "0x" prefix).
        // Strip "0x"/"0X" defensively in case the value comes from a different source.
        var rawVersion = (item.RowVersion ?? string.Empty).Trim();
        var hexStr = rawVersion.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
            ? rawVersion[2..]
            : rawVersion;
        var rowVersionBytes = Convert.FromHexString(hexStr);

        var p = new DynamicParameters();
        p.Add("imode",               4,                   DbType.Int32);
        p.Add("divcode",             item.DivCode,        DbType.String);
        p.Add("Prno",                item.PrNo,           DbType.Decimal);
        p.Add("Prdate",              prDate,              DbType.DateTime);
        p.Add("Prsno",               item.PrSno,          DbType.Decimal);
        p.Add("FinalAppUser",        finalAppUser,        DbType.String);
        p.Add("FinalAppQty",         item.QtyApproved,    DbType.Decimal);
        p.Add("FinalLevel_Remarks",  item.Disposition,    DbType.Int32);
        p.Add("Bypass",              bypass,              DbType.Int32);
        p.Add("row_version",         rowVersionBytes,     DbType.Binary, size: 8);
        p.Add("Result",              dbType: DbType.Int32, direction: ParameterDirection.Output);

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.PrFinalLevelApproval.Approve,
            p,
            commandType: CommandType.StoredProcedure);

        return p.Get<int>("Result");
    }

    public async Task<IEnumerable<CompanyDto>> GetCompaniesAsync()
    {
        return await _uow.Connection.QueryAsync<CompanyDto>(
            StoredProcedures.PrFinalLevelApproval.GetCompanies,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<DivisionDto>> GetDivisionsAsync(string dbName)
    {
        return await _uow.Connection.QueryAsync<DivisionDto>(
            StoredProcedures.PrFinalLevelApproval.GetDivisions,
            new { DbName = dbName },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<ItemHistoryDto>> GetItemHistoryAsync(string itemCode, string divCode)
    {
        // TODO: wire up to existing item purchase history SP once confirmed
        // Placeholder — returns empty until SP is identified or created
        await Task.CompletedTask;
        return [];
    }

    // Raw row type — matches SP imode=2/3 column aliases exactly
    private sealed record FinalApprovalLineRow(
        string?  DivCode,
        decimal  PrNo,
        string?  PrDate,
        decimal  PrSno,
        string?  Department,
        string?  ItemCode,
        string?  ItemName,
        string?  Uom,
        decimal  CurrentStock,
        decimal  QtyRequired,
        decimal  QtyApproved,
        int      Disposition,
        decimal  LpoRate,
        string?  LpoDate,
        decimal? ApproxCost,
        string?  ApprovalStatus,
        byte[]?  RowVersion);
}
