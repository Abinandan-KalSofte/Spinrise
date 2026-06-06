using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.Services;

public class PrAmendmentService : IPrAmendmentService
{
    private readonly IPrAmendmentRepository _repo;
    private readonly ILogger<PrAmendmentService> _logger;

    public PrAmendmentService(IPrAmendmentRepository repo, ILogger<PrAmendmentService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public Task<IEnumerable<PrAmendmentSummaryDto>> GetListAsync(
        string divCode, DateOnly fDate, DateOnly lDate,
        decimal? prNo, string? search, int page, int pageSize)
        => _repo.GetListAsync(divCode, fDate, lDate, prNo, search, page, pageSize);

    public Task<PrAmendmentHeaderDto?> GetByIdAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo)
        => _repo.GetByIdAsync(divCode, prNo, prDate, amendNo);

    public Task<PrAmendmentHeaderDto?> GetForNewAsync(
        string divCode, decimal prNo, DateOnly prDate)
        => _repo.GetForNewAsync(divCode, prNo, prDate);

    public async Task<int> AddAsync(
        string divCode, SaveAmendmentRequest request,
        string userId, DateOnly fDate, DateOnly lDate,
        string? hostName, string? ipAddress)
    {
        ValidateRequest(request);
        var amendNo = await _repo.SaveAsync(divCode,
            decimal.Parse(request.PrNo), ParsePrDate(request.PrDate),
            request, userId, fDate, lDate, hostName, ipAddress);
        _logger.LogInformation("Amendment Add | Div: {DivCode} | PR: {PrNo} | AmendNo: {AmendNo} | User: {UserId}",
            divCode, request.PrNo, amendNo, userId);
        return amendNo;
    }

    public Task<PrAmendmentPrintDto?> GetPrintDataAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo, string userId)
        => _repo.GetPrintDataAsync(divCode, prNo, prDate, amendNo, userId);

    // Accepts both ISO (YYYY-MM-DD) and display (DD/MM/YYYY) formats.
    private static DateOnly ParsePrDate(string raw)
    {
        if (DateOnly.TryParseExact(raw, "dd/MM/yyyy", null,
                System.Globalization.DateTimeStyles.None, out var d1)) return d1;
        if (DateOnly.TryParseExact(raw, "yyyy-MM-dd", null,
                System.Globalization.DateTimeStyles.None, out var d2)) return d2;
        if (DateOnly.TryParse(raw, out var d3)) return d3;
        throw new ArgumentException("The PR date format is not recognised. Please use a valid date.");
    }

    private static void ValidateRequest(SaveAmendmentRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.AmendmentReason))
            throw new ArgumentException("Amendment Reason is required.");

        if (!decimal.TryParse(req.PrNo, out _))
            throw new ArgumentException("Invalid PR number.");

        if (!DateOnly.TryParse(req.PrDate, out _))
            throw new ArgumentException("Invalid PR Date.");

        if (!DateOnly.TryParse(req.PDate, out _))
            throw new ArgumentException("The processing date is invalid. Please check and try again.");

        foreach (var line in req.Lines)
        {
            if (line.RateSource == "MANUAL" && string.IsNullOrWhiteSpace(line.RateJustification))
                throw new ArgumentException(
                    $"Rate Justification is required for item {line.ItemCode} when rate is manually overridden.");
        }
    }
}
