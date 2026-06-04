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
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<decimal>(), It.IsAny<DateOnly>(),
            It.IsAny<SaveAmendmentRequest>(), It.IsAny<string>(), It.IsAny<DateOnly>(), It.IsAny<DateOnly>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<int?>()), Times.Never);
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
        _repo.Setup(r => r.SaveAsync("ADD", DivCode, 12345m, PrDate,
            request, UserId, FDate, LDate, null, null, null))
             .ReturnsAsync(1);

        var result = await _sut.AddAsync(DivCode, request, UserId, FDate, LDate, null, null);

        result.Should().Be(1);
        _repo.Verify(r => r.SaveAsync("ADD", DivCode, 12345m, PrDate,
            request, UserId, FDate, LDate, null, null, null), Times.Once);
    }

    // ── ModifyAsync — validation failure ─────────────────────────────────────

    [Fact]
    public async Task ModifyAsync_EmptyAmendmentReason_ThrowsArgumentException()
    {
        var request = MakeRequest(reason: "");
        var act = () => _sut.ModifyAsync(DivCode, amendNo: 1, request, UserId, FDate, LDate, null, null);

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Amendment Reason*");
        _repo.Verify(r => r.SaveAsync(
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<decimal>(), It.IsAny<DateOnly>(),
            It.IsAny<SaveAmendmentRequest>(), It.IsAny<string>(), It.IsAny<DateOnly>(), It.IsAny<DateOnly>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<int?>()), Times.Never);
    }

    // ── ModifyAsync — happy path ──────────────────────────────────────────────

    [Fact]
    public async Task ModifyAsync_ValidRequest_CallsRepoWithModifyMode()
    {
        var request = MakeRequest();
        _repo.Setup(r => r.SaveAsync("MODIFY", DivCode, 12345m, PrDate,
            request, UserId, FDate, LDate, null, null, 2))
             .ReturnsAsync(2);

        var result = await _sut.ModifyAsync(DivCode, amendNo: 2, request, UserId, FDate, LDate, null, null);

        result.Should().Be(2);
        _repo.Verify(r => r.SaveAsync("MODIFY", DivCode, 12345m, PrDate,
            request, UserId, FDate, LDate, null, null, 2), Times.Once);
    }

    // ── DeleteAsync — happy path ──────────────────────────────────────────────

    [Fact]
    public async Task DeleteAsync_ValidRequest_CallsRepoWithDeleteMode()
    {
        _repo.Setup(r => r.SaveAsync("DELETE", DivCode, 12345m, PrDate,
            It.IsAny<SaveAmendmentRequest>(), UserId, PrDate, PrDate, null, null, 1))
             .ReturnsAsync(1);

        var result = await _sut.DeleteAsync(DivCode, 12345m, PrDate, amendNo: 1,
            rowVersion: "AAAAAAAAAA==", UserId, null, null);

        result.Should().Be(1);
        _repo.Verify(r => r.SaveAsync("DELETE", DivCode, 12345m, PrDate,
            It.IsAny<SaveAmendmentRequest>(), UserId, PrDate, PrDate, null, null, 1), Times.Once);
    }

    // ── DeleteLineAsync — happy path ──────────────────────────────────────────

    [Fact]
    public async Task DeleteLineAsync_ValidRequest_CallsRepoDeleteLine()
    {
        var rowVersionBase64 = Convert.ToBase64String([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]);
        var expectedBytes    = Convert.FromBase64String(rowVersionBase64);

        _repo.Setup(r => r.DeleteLineAsync(DivCode, 12345m, PrDate, 1, 2,
            It.Is<byte[]>(b => b.SequenceEqual(expectedBytes)),
            FDate, UserId, null, null))
             .ReturnsAsync(1);

        var result = await _sut.DeleteLineAsync(DivCode, 12345m, PrDate, amendNo: 1, prSno: 2,
            rowVersionBase64, FDate, UserId, null, null);

        result.Should().Be(1);
    }
}
