using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.Amendment;

public class PrAmendmentServiceTests
{
    private readonly Mock<IPrAmendmentRepository>       _repo   = new();
    private readonly Mock<ILogger<PrAmendmentService>>  _logger = new();
    private readonly PrAmendmentService _sut;

    private static readonly DateOnly FDate  = new(2025, 4, 1);
    private static readonly DateOnly LDate  = new(2026, 3, 31);
    private static readonly DateOnly PrDate = new(2026, 1, 15);
    private const string DivCode  = "01";
    private const string UserId   = "testuser";

    private static SaveAmendmentRequest MakeRequest(
        string reason  = "Price adjustment",
        string prNo    = "12345",
        string prDate  = "2026-01-15",
        string pDate   = "2026-01-20",
        List<SaveAmendmentLineRequest>? lines = null) => new()
    {
        AmendmentReason = reason,
        PrNo            = prNo,
        PrDate          = prDate,
        AmendDate       = "2026-01-20",
        PDate           = pDate,
        Lines           = lines ?? [],
    };

    public PrAmendmentServiceTests()
    {
        _sut = new PrAmendmentService(_repo.Object, _logger.Object);
    }

    // ── AddAsync — validation failures ────────────────────────────────────────

    [Fact]
    public async Task AddAsync_EmptyAmendmentReason_ThrowsArgumentException()
    {
        var request = MakeRequest(reason: "   ");
        var act = () => _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Amendment Reason*");
        _repo.Verify(r => r.SaveAsync(
            It.IsAny<string>(), It.IsAny<decimal>(), It.IsAny<DateOnly>(),
            It.IsAny<SaveAmendmentRequest>(), It.IsAny<string>(), It.IsAny<DateOnly>(), It.IsAny<DateOnly>(),
            It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task AddAsync_InvalidPrNo_ThrowsArgumentException()
    {
        var request = MakeRequest(prNo: "NOTANUMBER");
        var act = () => _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Invalid PR number*");
    }

    [Fact]
    public async Task AddAsync_InvalidPrDate_ThrowsArgumentException()
    {
        var request = MakeRequest(prDate: "not-a-date");
        var act = () => _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        await act.Should().ThrowAsync<ArgumentException>();
    }

    [Fact]
    public async Task AddAsync_InvalidPDate_ThrowsArgumentException()
    {
        var request = MakeRequest(pDate: "bad-pdate");
        var act = () => _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*processing date*");
    }

    [Fact]
    public async Task AddAsync_ManualRateWithoutJustification_ThrowsArgumentException()
    {
        var line = new SaveAmendmentLineRequest
        {
            PrSno             = 1m,
            ItemCode          = "ITEM001",
            QtyInd            = 5m,
            Rate              = 100m,
            RateSource        = "MANUAL",
            RateJustification = null,
        };
        var request = MakeRequest(lines: [line]);
        var act = () => _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Rate Justification*");
    }

    // ── AddAsync — happy path ─────────────────────────────────────────────────

    [Fact]
    public async Task AddAsync_ValidRequest_CallsRepoAndReturnsAmendNo()
    {
        var request = MakeRequest();
        _repo.Setup(r => r.SaveAsync(DivCode, 12345m, PrDate,
            request, UserId, FDate, LDate, null, null))
             .ReturnsAsync(1);

        var result = await _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        result.Should().Be(1);
        _repo.Verify(r => r.SaveAsync(DivCode, 12345m, PrDate,
            request, UserId, FDate, LDate, null, null), Times.Once);
    }
}
