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
        var rows = await _uow.Connection.QueryAsync<dynamic>(
            StoredProcedures.PrFinalLevelApproval.Approve,
            new { imode, divcode = divCode, Bypass = bypass, Result = 0 },
            commandType: CommandType.StoredProcedure);

        return rows.Select(r => new FinalApprovalLineDto(
            DivCode:        r.divcode        ?? string.Empty,
            PrNo:           Convert.ToDecimal(r.prno),
            PrDate:         r.prdate         ?? string.Empty,
            PrSno:          Convert.ToDecimal(r.prsno),
            DbName:         string.Empty,
            Department:     r.department     ?? string.Empty,
            ItemCode:       r.itemCode       ?? string.Empty,
            ItemName:       r.itemName       ?? string.Empty,
            Uom:            r.uom            ?? string.Empty,
            CurrentStock:   Convert.ToDecimal(r.currentStock),
            QtyRequired:    Convert.ToDecimal(r.qtyRequired),
            QtyApproved:    Convert.ToDecimal(r.qtyApproved),
            Disposition:    Convert.ToInt32(r.disposition),
            LpoRate:        Convert.ToDecimal(r.lpoRate),
            LpoDate:        r.lpoDate        as string,
            ApproxCost:     r.approxCost == null ? (decimal?)null : Convert.ToDecimal(r.approxCost),
            ApprovalStatus: r.approvalStatus ?? "first",
            RowVersion:     r.rowVersion is byte[] rv ? Convert.ToHexString(rv) : (r.rowVersion?.ToString() ?? string.Empty)
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
}
