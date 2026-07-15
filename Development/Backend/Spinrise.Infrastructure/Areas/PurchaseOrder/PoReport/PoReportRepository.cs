using System.Data;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PoReport;

public class PoReportRepository : IPoReportRepository
{
    private readonly IUnitOfWork _uow;

    public PoReportRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IReadOnlyList<PoDateWiseRowDto>> GetDateWiseRowsAsync(
        PoReportRequest request, CancellationToken ct = default)
    {
        // ksp_PO_DateWise_Report has no @DepCode parameter — Date-wise has no department
        // filter in the UI (see reportConfigs.ts), and the SP doesn't declare one.
        var rows = (await _uow.Connection.QueryAsync<PoDateWiseRowDto>(
            StoredProcedures.PoReport.DateWiseReport,
            new
            {
                Divcode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        return rows;
    }

    public async Task<IReadOnlyList<PoDeptWiseRowDto>> GetDeptWiseRowsAsync(
        PoReportRequest request, CancellationToken ct = default)
    {
        var rows = (await _uow.Connection.QueryAsync<PoDeptWiseRowDto>(
            StoredProcedures.PoReport.DeptWiseReport,
            new
            {
                Divcode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
                DepCode  = string.IsNullOrWhiteSpace(request.DepCode) ? null : request.DepCode,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        return rows;
    }

    public async Task<IReadOnlyList<PoItemWiseRowDto>> GetItemWiseRowsAsync(
        PoReportRequest request, CancellationToken ct = default)
    {
        var fetchAll = request.AllItems || request.ItemCodes.Length != 1;
        var fItem    = fetchAll ? "A" : request.ItemCodes[0];
        var tItem    = fetchAll ? "A" : request.ItemCodes[0];

        var rows = (await _uow.Connection.QueryAsync<PoItemWiseRowDto>(
            StoredProcedures.PoReport.ItemWiseReport,
            new
            {
                DIVCODE  = request.DivCode,
                FromDate = request.FromDate.ToString("yyyy-MM-dd"),
                ToDate   = request.ToDate.ToString("yyyy-MM-dd"),
                FITEM    = fItem,
                TITEM    = tItem,
                Opt      = string.IsNullOrWhiteSpace(request.ConfirmStatus) ? "A" : request.ConfirmStatus,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        if (!request.AllItems && request.ItemCodes.Length > 1)
        {
            var codeSet = new HashSet<string>(request.ItemCodes, StringComparer.OrdinalIgnoreCase);
            rows = rows.Where(r => codeSet.Contains(r.ItemCode ?? "")).ToList();
        }

        return rows;
    }

    public async Task<IReadOnlyList<PoSupplierWiseRowDto>> GetSupplierWiseRowsAsync(
        PoReportRequest request, CancellationToken ct = default)
    {
        // Mirrors GetItemWiseRowsAsync's AllItems/ItemCodes pattern: the SP only accepts a single
        // @SupplierCode, so push the filter down to the SP when exactly one supplier is selected
        // (cheapest), otherwise fetch all and narrow in-memory for a genuine multi-select.
        var singleSupplier = !request.AllSuppliers && request.SupplierCodes.Length == 1
            ? request.SupplierCodes[0]
            : null;

        var rows = (await _uow.Connection.QueryAsync<PoSupplierWiseRowDto>(
            StoredProcedures.PoReport.SupplierWiseReport,
            new
            {
                Divcode       = request.DivCode,
                FromDate      = request.FromDate,
                ToDate        = request.ToDate,
                SupplierCode  = singleSupplier,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        if (!request.AllSuppliers && request.SupplierCodes.Length > 1)
        {
            var codeSet = new HashSet<string>(request.SupplierCodes, StringComparer.OrdinalIgnoreCase);
            rows = rows.Where(r => codeSet.Contains(r.SupplierCode ?? "")).ToList();
        }

        return rows;
    }
}
