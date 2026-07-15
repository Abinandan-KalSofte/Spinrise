using System.Data;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PrReport;

public class PrReportRepository : IPrReportRepository
{
    private readonly IUnitOfWork _uow;

    public PrReportRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IReadOnlyList<PrDateWiseRowDto>> GetDateWiseRowsAsync(
        PrReportRequest request, CancellationToken ct = default)
    {
        var rows = (await _uow.Connection.QueryAsync<PrDateWiseRowDto>(
            StoredProcedures.PrReport.DateWiseReport,
            new
            {
                Divcode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
                FrmDep   = string.IsNullOrWhiteSpace(request.DepCode) ? null : request.DepCode,
                ToDep    = string.IsNullOrWhiteSpace(request.DepCode) ? null : request.DepCode,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        foreach (var row in rows)
            row.PrStatus = PrStatusDescribe(row.PrStatusCode, row.SecondApp);

        return rows;
    }

    public async Task<IReadOnlyList<PrDeptWiseRowDto>> GetDeptWiseRowsAsync(
        PrReportRequest request, CancellationToken ct = default)
    {
        var rows = (await _uow.Connection.QueryAsync<PrDeptWiseRowDto>(
            StoredProcedures.PrReport.DeptWiseReport,
            new
            {
                Divcode  = request.DivCode,
                FromDate = request.FromDate,
                ToDate   = request.ToDate,
                DepCode  = string.IsNullOrWhiteSpace(request.DepCode) ? null : request.DepCode,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        foreach (var row in rows)
            row.PrStatus = PrStatusDescribe(row.PrStatusCode, row.SecondApp);

        return rows;
    }

    public async Task<IReadOnlyList<PrItemWiseRowDto>> GetItemWiseRowsAsync(
        PrReportRequest request, CancellationToken ct = default)
    {
        // KSP_PR_ITEMWISE treats "A" as no-bound on either parameter.
        // Single item:    FITEM = code,  TITEM = code   → exact match
        // All / multiple: FITEM = "A",   TITEM = "A"   → fetch all, post-filter below
        var fetchAll   = request.AllItems || request.ItemCodes.Length != 1;
        var fItem      = fetchAll ? "A" : request.ItemCodes[0];
        var tItem      = fetchAll ? "A" : request.ItemCodes[0];

        var rows = (await _uow.Connection.QueryAsync<PrItemWiseRowDto>(
            StoredProcedures.PrReport.ItemWiseReport,
            new
            {
                DIVCODE = request.DivCode,
                FPRDT   = request.FromDate.ToString("yyyy-MM-dd"),
                TPRDT   = request.ToDate.ToString("yyyy-MM-dd"),
                FITEM   = fItem,
                TITEM   = tItem,
            },
            commandType: CommandType.StoredProcedure)).ToList();

        // Post-filter for multiple specific items (SP only supports range, not arbitrary list)
        if (!request.AllItems && request.ItemCodes.Length > 1)
        {
            var codeSet = new HashSet<string>(request.ItemCodes, StringComparer.OrdinalIgnoreCase);
            rows = rows.Where(r => codeSet.Contains(r.ItemCode ?? "")).ToList();
        }

        foreach (var row in rows)
            row.PrStatus = NormalizeItemWiseStatus(row.PrStatus);

        return rows;
    }

    // Status decode — mirrors Crystal formula (PrStatus.Describe / PrStatusDescribe.Describe)
    private static string PrStatusDescribe(string? code, string? secondApp)
    {
        if (string.IsNullOrWhiteSpace(code)) return "Requested";
        var c = code.Trim().ToUpperInvariant();
        if (c == "O") return "Ordered";
        if (c == "C") return "Received";
        if (c == "Z") return "Force Closed";
        if (c == "D") return "Final Level Approved";
        if (!string.IsNullOrWhiteSpace(secondApp) && secondApp.Trim().ToUpperInvariant() == "Y")
            return "Second Level Approved";
        if (c == "F") return "First Level Approved";
        if (c == "X") return "Cancelled";
        return $"Status {c}";
    }

    // KSP_PR_ITEMWISE already decodes status text; normalise legacy labels only
    private static string? NormalizeItemWiseStatus(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return "Requested";
        return raw switch
        {
            "Fore Closed" => "Force Closed",
            "Indent"      => "Requested",
            _             => raw,
        };
    }
}
