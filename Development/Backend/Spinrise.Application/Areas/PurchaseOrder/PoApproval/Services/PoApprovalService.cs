using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.Services;

public class PoApprovalService : IPoApprovalService
{
    private static readonly HashSet<string> ValidLevels = new(StringComparer.OrdinalIgnoreCase)
    {
        "first", "second", "final"
    };

    private readonly IPoApprovalRepository _repo;
    private readonly ILogger<PoApprovalService> _logger;

    public PoApprovalService(IPoApprovalRepository repo, ILogger<PoApprovalService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public Task<IReadOnlyList<DivisionRowDto>> GetDivisionsAsync(string level)
    {
        EnsureValidLevel(level);
        return _repo.GetDivisionsAsync();
    }

    public async Task<PoApprovalPendingResponse> GetPendingAsync(
        string level, string divCode, DateTime yfDate, DateTime ylDate, string? search)
    {
        EnsureValidLevel(level);
        if (string.IsNullOrWhiteSpace(divCode))
            throw new InvalidOperationException("Division code is required.");
        // 10-Jul-2026 /verify finding: a missing yfDate/ylDate query param silently
        // binds to default(DateTime) (0001-01-01), which SQL Server's DATETIME type
        // rejects with an unhandled SqlTypeException (500) instead of a clean 400 —
        // ExceptionHandlingMiddleware only special-cases SqlException, not
        // System.Data.SqlTypes.SqlTypeException. Guard here, same pattern as the
        // divCode check above.
        if (yfDate == default || ylDate == default)
            throw new InvalidOperationException("Financial year bounds (yfDate/ylDate) are required.");

        var items = await _repo.GetPendingAsync(level.ToLowerInvariant(), divCode, yfDate, ylDate, search);
        return new PoApprovalPendingResponse(items);
    }

    public async Task<PoApprovalSaveResponse> SaveAsync(
        string level, PoApprovalSaveRequest request,
        string userId, string userName, string? ipAddress, string? hostName)
    {
        EnsureValidLevel(level);

        if (request.Items is null || request.Items.Count == 0)
            throw new InvalidOperationException("No records are selected to save.");

        // CEO/QA direction 02-Jul-2026 (Item 4), already enforced client-side via
        // poApprovalTypes.ts's isReasonRequired — enforced again here since client
        // validation is not trustworthy (server is the actual boundary).
        foreach (var item in request.Items)
        {
            // 10-Jul-2026 bug fix: divCode is per-item now (was request-level, which
            // silently sent the '0' ALL-divisions filter sentinel for every row when
            // the grid filter was "ALL Divisions" — no real DIVCODE ever equals '0',
            // so every save under that filter was failing as "not found").
            if (string.IsNullOrWhiteSpace(item.DivCode) || item.DivCode == "0")
            {
                throw new InvalidOperationException(
                    $"PO {item.PoNo} is missing its division code — cannot save.");
            }

            if (item.Disposition is 3 or 4 or 5 && string.IsNullOrWhiteSpace(item.Remarks))
            {
                throw new InvalidOperationException(
                    $"Remarks are mandatory for Hold/Declined/Postpone (PO {item.PoNo}).");
            }

            // CR-PO-APPROVAL-01 / BR-05 (legacy parity, 10-Jul-2026): Postpone requires
            // a re-surface date — the SP hides the PO from the queue until that date.
            if (item.Disposition == 5 && string.IsNullOrWhiteSpace(item.PostponeDate))
            {
                throw new InvalidOperationException(
                    $"A postpone date is mandatory for Postpone (PO {item.PoNo}).");
            }
        }

        var normalizedLevel = level.ToLowerInvariant();
        var saved = new List<decimal>();

        // CR-PO-APPROVAL-01 / CD-08: no case 3 (concurrency conflict) — the SP's
        // @RowVersion is always passed NULL from this frontend (no round-trip token
        // exists), so the SP's own NULL-bypass guarantees @Result can never actually
        // be 3. Removed per Sasi/CEO directive (09-Jul-2026) — dead code should not ship.
        foreach (var item in request.Items)
        {
            var result = await _repo.SetApprovalAsync(
                normalizedLevel, item, userId, userName, ipAddress, hostName);

            switch (result)
            {
                case 0:
                    saved.Add(item.PoNo);
                    break;
                case 2:
                    throw new InvalidOperationException(
                        $"PO {item.PoNo} cannot be actioned — prerequisite approval level is not complete.");
                case 4:
                    throw new InvalidOperationException($"PO {item.PoNo} not found.");
            }
        }

        _logger.LogInformation(
            "PoApproval Save | Level: {Level} | User: {User} | Saved: {Saved}/{Total}",
            normalizedLevel, userId, saved.Count, request.Items.Count);

        return new PoApprovalSaveResponse(saved);
    }

    private static void EnsureValidLevel(string level)
    {
        if (string.IsNullOrWhiteSpace(level) || !ValidLevels.Contains(level))
            throw new ArgumentException($"Unknown approval level: '{level}'. Expected first, second, or final.");
    }
}
