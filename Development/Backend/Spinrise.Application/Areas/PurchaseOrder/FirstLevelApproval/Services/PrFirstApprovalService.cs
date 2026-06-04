using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Services;

public class PrFirstApprovalService : IPrFirstApprovalService
{
    private readonly IPrFirstApprovalRepository _repo;
    private readonly ILogger<PrFirstApprovalService> _logger;

    public PrFirstApprovalService(IPrFirstApprovalRepository repo, ILogger<PrFirstApprovalService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public Task<PoParaDto?> GetPoParaAsync(string divCode)
        => _repo.GetPoParaAsync(divCode);

    public Task<IEnumerable<ApprovalDeptDto>> GetDeptForUserAsync(string divCode, string userId)
        => _repo.GetDeptForUserAsync(divCode, userId);

    public Task<IEnumerable<PrApprovalSummaryDto>> GetPendingListAsync(
        string divCode, string dep, DateTime yfDate, DateTime ylDate)
        => _repo.GetPendingListAsync(divCode, dep, yfDate, ylDate);

    public Task<IEnumerable<PrApprovalSummaryDto>> GetApprovedListAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
        => _repo.GetApprovedListAsync(divCode, yfDate, ylDate);

    public async Task<PrApprovalDetailDto?> GetDetailAsync(string divCode, decimal prNo, DateTime prDate)
    {
        var header = await _repo.GetHeaderAsync(divCode, prNo, prDate);
        if (header is null) return null;
        var lines = (await _repo.GetLinesAsync(divCode, prNo, prDate)).ToList();
        return new PrApprovalDetailDto(header, lines);
    }

    public async Task SaveAsync(string divCode, SaveFirstApprovalRequest request,
        string userId, string userName,
        string? ipAddress, string? hostName, int moduleNo)
    {
        var (_, isFirstLevel) = await _repo.CheckUserApprovalLevelAsync(divCode, userId);
        if (!isFirstLevel)
            throw new UnauthorizedAccessException("You are not authorised to perform first-level approval.");

        if (request.Lines is null || request.Lines.Count == 0)
            throw new InvalidOperationException("Please select at least one line before saving.");

        if (request.AppDate.Date > DateTime.Today)
            throw new InvalidOperationException("Approval date cannot be in the future. Please check the date and try again.");

        // FA-ADD-09: reject zero or negative FirstAppQty
        var zeroOrNegativeLines = request.Lines.Where(l => l.FirstAppQty <= 0).ToList();
        if (zeroOrNegativeLines.Count > 0)
            throw new InvalidOperationException(
                $"First Approval Quantity must be greater than zero on row(s): " +
                string.Join(", ", zeroOrNegativeLines.Select(l => l.PrSno)));

        // DEF-FA-01: server-side guard — reject if any line has FirstAppQty > QtyReqd
        var invalidLines = request.Lines.Where(l => l.FirstAppQty > l.QtyReqd).ToList();
        if (invalidLines.Count > 0)
            throw new InvalidOperationException(
                $"First Approval Quantity exceeds Quantity Required on row(s): " +
                string.Join(", ", invalidLines.Select(l => l.PrSno)));

        await _repo.SaveAsync(divCode, request, userId, userName, ipAddress, hostName, moduleNo);
        _logger.LogInformation("FirstApproval Save | Div: {DivCode} | PR: {PrNo} | Lines: {LineCount} | User: {UserId}",
            divCode, request.PrNo, request.Lines.Count, userId);
    }

    public async Task DeleteAsync(string divCode, DeleteFirstApprovalRequest request,
        string userId, string userName,
        string? ipAddress, string? hostName, int moduleNo)
    {
        var (_, isFirstLevel) = await _repo.CheckUserApprovalLevelAsync(divCode, userId);
        if (!isFirstLevel)
            throw new UnauthorizedAccessException("You are not authorised to undo first-level approval.");

        await _repo.DeleteAsync(divCode, request, userId, userName, ipAddress, hostName, moduleNo);
        _logger.LogInformation("FirstApproval Undo | Div: {DivCode} | PR: {PrNo} | User: {UserId}",
            divCode, request.PrNo, userId);
    }

    public async Task<PrApprovalReportDto?> GetReportDataAsync(string divCode, decimal prNo, DateTime prDate)
    {
        var para  = await _repo.GetPoParaAsync(divCode);
        var label = para?.AppUserLabel1 ?? "SM";
        return await _repo.GetReportDataAsync(divCode, prNo, prDate, label);
    }
}
