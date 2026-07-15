using System.Data;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PendingPrReport;

public class PendingPrReportRepository : IPendingPrReportRepository
{
    private readonly IUnitOfWork _uow;

    public PendingPrReportRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IReadOnlyList<PendingPrDateWiseRowDto>> GetDateWiseRowsAsync(
        PrReportRequest request, CancellationToken ct = default)
    {
        return (await _uow.Connection.QueryAsync<PendingPrDateWiseRowDto>(
            StoredProcedures.PendingPrReport.DateWiseReport,
            new
            {
                DivCode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
            },
            commandType: CommandType.StoredProcedure)).ToList();
    }

    public async Task<IReadOnlyList<PendingPrDeptWiseRowDto>> GetDeptWiseRowsAsync(
        PrReportRequest request, CancellationToken ct = default)
    {
        return (await _uow.Connection.QueryAsync<PendingPrDeptWiseRowDto>(
            StoredProcedures.PendingPrReport.DeptWiseReport,
            new
            {
                DivCode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
                DepCode  = string.IsNullOrWhiteSpace(request.DepCode) ? null : request.DepCode,
            },
            commandType: CommandType.StoredProcedure)).ToList();
    }

    public async Task<IReadOnlyList<PendingPrItemWiseRowDto>> GetItemWiseRowsAsync(
        PrReportRequest request, CancellationToken ct = default)
    {
        // Empty string = all items in SP. Single item: FItem = TItem = code.
        // For multiple items: fetch all (FItem=''), post-filter in C# (same pattern as PrReport ItemWise).
        var fetchAll = request.AllItems || request.ItemCodes.Length != 1;
        var fItem    = fetchAll ? "" : request.ItemCodes[0];
        var tItem    = fetchAll ? "" : request.ItemCodes[0];

        var rows = (await _uow.Connection.QueryAsync<PendingPrItemWiseRowDto>(
            StoredProcedures.PendingPrReport.ItemWiseReport,
            new
            {
                DivCode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
                FItem    = fItem,
                TItem    = tItem,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        if (!request.AllItems && request.ItemCodes.Length > 1)
        {
            var codeSet = new HashSet<string>(request.ItemCodes, StringComparer.OrdinalIgnoreCase);
            rows = rows.Where(r => codeSet.Contains(r.ItemCode)).ToList();
        }

        foreach (var row in rows)
            row.PrStatus = DecodePrStatus(row.PrStatusCode);

        return rows;
    }

    private static string DecodePrStatus(string? code)
    {
        if (string.IsNullOrWhiteSpace(code)) return "Requested";
        return code.Trim().ToUpperInvariant() switch
        {
            "X" => "Requested",
            "O" => "Ordered",
            "C" => "Received",
            "Z" => "Force Closed",
            "D" => "Final Level Approved",
            "F" => "First Level Approved",
            _   => "Requested",
        };
    }
}
