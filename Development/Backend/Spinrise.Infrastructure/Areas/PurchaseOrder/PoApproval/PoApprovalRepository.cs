using System.Data;
using System.Globalization;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.Interfaces;
using Spinrise.Application.Areas.Security.Division.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PoApproval;

public class PoApprovalRepository : IPoApprovalRepository
{
    private readonly IUnitOfWork _uow;
    private readonly IDivisionRepository _divisionRepo;

    public PoApprovalRepository(IUnitOfWork uow, IDivisionRepository divisionRepo)
    {
        _uow = uow;
        _divisionRepo = divisionRepo;
    }

    public async Task<IReadOnlyList<DivisionRowDto>> GetDivisionsAsync()
    {
        // 10-Jul-2026: was ksp_BindDiv_PO (StoredProcedures.Po.GetDivisionsForApproval) —
        // confirmed live on JAT via a runtime error (SqlException: 'ksp_BindDiv_PO'
        // expects parameter '@DBName', which was not supplied), but that's the same
        // "active divisions for the current DB" lookup ksp_Auth_GetActiveDivisions
        // already serves correctly. Switched to the shared IDivisionRepository instead
        // of patching the missing param — one division source across modules, not a
        // PO-Approval-specific one. Uses the current unit-of-work's resolved DB (no
        // explicit dbName override needed; PoApprovalRepository already runs against
        // whatever IUnitOfWork.Connection resolves to for this request).
        var rows = await _divisionRepo.GetActiveDivisionsAsync();
        return rows.Select(r => new DivisionRowDto(r.DivCode, r.DivName)).ToList();
    }

    public async Task<IReadOnlyList<PoApprovalLineDto>> GetPendingAsync(
        string level, string divCode, DateTime yfDate, DateTime ylDate, string? search)
    {
        var spName = PendingSp(level);
        var parameters = new
        {
            DivCode = divCode,
            YFDate = yfDate,
            YLDate = ylDate,
            Search = string.IsNullOrWhiteSpace(search) ? null : search,
        };

        if (level == "final")
        {
            var headers = await _uow.Connection.QueryAsync<HeaderRow>(
                spName, parameters, commandType: CommandType.StoredProcedure);
            return headers.Select(h => MapHeader(h, lines: null)).ToList();
        }

        using var multi = await _uow.Connection.QueryMultipleAsync(
            spName, parameters, commandType: CommandType.StoredProcedure);

        var headerRows = (await multi.ReadAsync<HeaderRow>()).ToList();
        var lineRows = (await multi.ReadAsync<LineRow>()).ToList();

        return headerRows.Select(h =>
        {
            var lines = lineRows
                .Where(l => l.PoNo == h.PoNo && l.PoDate == h.PoDate && l.DivCode == h.DivCode)
                .Select(l => new PoApprovalLineItemDto(
                    l.PordSno, l.ItemCode ?? string.Empty, l.ItemName ?? string.Empty,
                    l.Qty, l.Uom ?? string.Empty, l.Rate, l.Value,
                    l.OnlineRemarks ?? string.Empty, l.FClosed ?? "N"))
                .ToList();
            // 10-Jul-2026: First/Second's GET SPs never select LineCount (only Final's
            // aggregate does), so h.LineCount is always null here — count the lines
            // actually fetched instead, exact by construction.
            return MapHeader(h, lines, lineCountOverride: lines.Count);
        }).ToList();
    }

    public async Task<int> SetApprovalAsync(
        string level, PoApprovalSaveItemRequest item,
        string userId, string userName, string? ipAddress, string? hostName)
    {
        var spName = SetSp(level);
        var p = BuildSetApprovalParameters(item, userId, userName, ipAddress, hostName);

        await _uow.Connection.ExecuteAsync(spName, p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("Result");
    }

    // Extracted 10-Jul-2026 (/verify follow-up) so the parameter set sent to the SET
    // SPs is directly unit-testable — Dapper's ExecuteAsync is an extension method on
    // IDbConnection and can't be intercepted via Moq, which is exactly how the
    // @Disposition/@PostponeDate wiring gap shipped with zero test coverage.
    public static DynamicParameters BuildSetApprovalParameters(
        PoApprovalSaveItemRequest item, string userId, string userName, string? ipAddress, string? hostName)
    {
        var poDate = DateTime.ParseExact(item.PoDate, "yyyy-MM-dd", CultureInfo.InvariantCulture);

        var p = new DynamicParameters();
        // 10-Jul-2026 bug fix: divCode comes from item.DivCode (the row's real
        // division), never a request-level value — see PoApprovalSaveItemRequest.
        p.Add("DivCode", item.DivCode, DbType.String);
        p.Add("PoNo", item.PoNo, DbType.Decimal);
        p.Add("PoDate", poDate, DbType.Date);
        p.Add("UserId", userId, DbType.String);
        p.Add("UserName", userName, DbType.String);
        p.Add("IpAddress", ipAddress ?? string.Empty, DbType.String);
        p.Add("HostName", hostName ?? string.Empty, DbType.String);
        p.Add("Remarks", item.Remarks, DbType.String);
        // CD-08 gap (CR-PO-APPROVAL-01): frontend never supplies a row_version token —
        // pass NULL explicitly so the SP's own "@RowVersion IS NULL" bypass branch runs.
        // Each SP's own state guard (e.g. "must not already be approved") is the actual
        // double-action protection today, not row_version. Do not remove this comment
        // without re-reading the CR's Open Question 2.
        p.Add("RowVersion", null, DbType.Binary, size: 8);
        // 10-Jul-2026: CR-PO-APPROVAL-01's draft SET SPs (@Disposition/@PostponeDate)
        // confirmed applied to the target DB (user-run, ahead of the formal Sasi/CEO
        // ALTER sequence — see CR doc) — wiring the params now to match. Previously
        // left unsent deliberately (see git history) because the then-live SP signature
        // didn't accept them; without this, every save silently ran @Disposition's SP-side
        // default (2=Approved) regardless of what the user actually picked in the UI.
        p.Add("Disposition", item.Disposition, DbType.Int32);
        p.Add("PostponeDate", string.IsNullOrWhiteSpace(item.PostponeDate) ? null
            : (object)DateTime.ParseExact(item.PostponeDate, "yyyy-MM-dd", CultureInfo.InvariantCulture), DbType.Date);
        p.Add("Result", dbType: DbType.Int32, direction: ParameterDirection.Output);
        return p;
    }

    private static string PendingSp(string level) => level switch
    {
        "first"  => StoredProcedures.Po.GetPendingFirstApproval,
        "second" => StoredProcedures.Po.GetPendingSecondApproval,
        "final"  => StoredProcedures.Po.GetPendingFinalApproval,
        _ => throw new ArgumentException($"Unknown level: {level}")
    };

    private static string SetSp(string level) => level switch
    {
        "first"  => StoredProcedures.Po.SetFirstApproval,
        "second" => StoredProcedures.Po.SetSecondApproval,
        "final"  => StoredProcedures.Po.SetFinalApproval,
        _ => throw new ArgumentException($"Unknown level: {level}")
    };

    private static PoApprovalLineDto MapHeader(
        HeaderRow h, IReadOnlyList<PoApprovalLineItemDto>? lines, int? lineCountOverride = null)
    {
        PoApprovalProvenanceDto? firstLevel = !string.IsNullOrWhiteSpace(h.FirstLevelBy)
            ? new PoApprovalProvenanceDto(h.FirstLevelBy!, h.FirstLevelOn ?? string.Empty)
            : null;
        PoApprovalProvenanceDto? secondLevel = !string.IsNullOrWhiteSpace(h.SecondLevelBy)
            ? new PoApprovalProvenanceDto(h.SecondLevelBy!, h.SecondLevelOn ?? string.Empty)
            : null;

        return new PoApprovalLineDto(
            h.DivCode ?? string.Empty,
            h.DivName ?? string.Empty,
            h.PoNo,
            h.PoDate ?? string.Empty,
            h.OrderType ?? string.Empty,
            h.SupplierCode ?? string.Empty,
            h.SupplierName ?? string.Empty,
            h.SupplierPlace ?? string.Empty,
            h.Currency ?? string.Empty,
            h.PaymentTerm ?? string.Empty,
            h.NetTotal,
            h.AmendNo,
            h.FirstLevelApp ?? "N",
            h.SecondLevelApp ?? "N",
            h.Conflg ?? "N",
            lines,
            lineCountOverride ?? h.LineCount,
            h.PoValue,
            firstLevel,
            secondLevel);
    }

    // Property classes — Dapper maps by name, so SP column order/additions never cause
    // constructor errors. Shared across First/Second/Final: columns absent from a given
    // level's SELECT (e.g. LineCount on First) simply stay at their default/null.
    private sealed class HeaderRow
    {
        public string?  DivCode        { get; init; }
        public string?  DivName        { get; init; }
        public decimal  PoNo           { get; init; }
        public string?  PoDate         { get; init; }
        public string?  OrderType      { get; init; }
        public string?  SupplierCode   { get; init; }
        public string?  SupplierName   { get; init; }
        public string?  SupplierPlace  { get; init; }
        public string?  Currency       { get; init; }
        public string?  PaymentTerm    { get; init; }
        public decimal  NetTotal       { get; init; }
        public int      AmendNo        { get; init; }
        public string?  FirstLevelApp  { get; init; }
        public string?  SecondLevelApp { get; init; }
        public string?  Conflg         { get; init; }
        public int?     LineCount      { get; init; }
        public decimal? PoValue        { get; init; }
        public string?  FirstLevelBy   { get; init; }
        public string?  FirstLevelOn   { get; init; }
        public string?  SecondLevelBy  { get; init; }
        public string?  SecondLevelOn  { get; init; }
    }

    private sealed class LineRow
    {
        public int      PordSno       { get; init; }
        public string?  ItemCode      { get; init; }
        public string?  ItemName      { get; init; }
        public decimal  Qty           { get; init; }
        public string?  Uom           { get; init; }
        public decimal  Rate          { get; init; }
        public decimal  Value         { get; init; }
        public string?  OnlineRemarks { get; init; }
        public string?  FClosed       { get; init; }
        public string?  DivCode       { get; init; }
        public decimal  PoNo          { get; init; }
        public string?  PoDate        { get; init; }
    }
}
