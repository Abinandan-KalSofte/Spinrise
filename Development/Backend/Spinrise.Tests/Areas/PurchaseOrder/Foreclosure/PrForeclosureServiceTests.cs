using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.Foreclosure;

public class PrForeclosureServiceTests
{
    private readonly Mock<IPrForeclosureRepository> _repo = new();
    private readonly PrForeclosureService _sut;

    private const string DivCode = "01";
    private const string UserId  = "testuser";

    private static readonly DateOnly FDate = new(2025, 4, 1);
    private static readonly DateOnly LDate = new(2026, 3, 31);

    private static PrForeclosureLineKeyDto MakeLine(decimal prNo = 1m, int prSno = 1) =>
        new(prNo, "2026-01-15", prSno, "ITEM001", "ENG", 5m);

    public PrForeclosureServiceTests()
    {
        _sut = new PrForeclosureService(_repo.Object);
    }

    // ── GetOpenLinesAsync ─────────────────────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetOpenLinesForForeclosure")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetOpenLinesAsync_DelegatesToRepo()
    {
        var expected = new List<PrForeclosureLineDto>();
        _repo.Setup(r => r.GetOpenForForeclosureAsync(DivCode, FDate, LDate, null))
             .ReturnsAsync(expected);

        var result = await _sut.GetOpenLinesAsync(DivCode, FDate, LDate, null);

        result.Should().BeSameAs(expected);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetOpenLinesForForeclosure")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetOpenLinesAsync_WithPrNoFilter_PassesFilterToRepo()
    {
        var expected = new List<PrForeclosureLineDto>();
        _repo.Setup(r => r.GetOpenForForeclosureAsync(DivCode, FDate, LDate, "12345"))
             .ReturnsAsync(expected);

        var result = await _sut.GetOpenLinesAsync(DivCode, FDate, LDate, "12345");

        result.Should().BeSameAs(expected);
        _repo.Verify(r => r.GetOpenForForeclosureAsync(DivCode, FDate, LDate, "12345"), Times.Once);
    }

    // ── SaveForeclosureAsync — validation ────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveForeclosure")]
    [Trait("Layer", "Service")]
    [Trait("Type", "NegativeCase")]
    public async Task SaveForeclosureAsync_NullLines_ThrowsInvalidOperationException()
    {
        var request = new PrForeclosureSaveRequestDto(null!);

        var act = () => _sut.SaveForeclosureAsync(request, DivCode, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*at least one item*");
        _repo.Verify(r => r.SaveForeclosureAsync(
            It.IsAny<List<PrForeclosureLineKeyDto>>(), It.IsAny<string>(),
            It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveForeclosure")]
    [Trait("Layer", "Service")]
    [Trait("Type", "NegativeCase")]
    public async Task SaveForeclosureAsync_EmptyLines_ThrowsInvalidOperationException()
    {
        var request = new PrForeclosureSaveRequestDto([]);

        var act = () => _sut.SaveForeclosureAsync(request, DivCode, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*at least one item*");
        _repo.Verify(r => r.SaveForeclosureAsync(
            It.IsAny<List<PrForeclosureLineKeyDto>>(), It.IsAny<string>(),
            It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    // ── SaveForeclosureAsync — happy path ─────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveForeclosure")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task SaveForeclosureAsync_ValidLines_ReturnsCountFromRepo()
    {
        var lines   = new List<PrForeclosureLineKeyDto> { MakeLine(1m, 1), MakeLine(2m, 1) };
        var request = new PrForeclosureSaveRequestDto(lines);
        _repo.Setup(r => r.SaveForeclosureAsync(lines, DivCode, UserId, null, null))
             .ReturnsAsync(2);

        var count = await _sut.SaveForeclosureAsync(request, DivCode, UserId, null, null);

        count.Should().Be(2);
        _repo.Verify(r => r.SaveForeclosureAsync(lines, DivCode, UserId, null, null), Times.Once);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveForeclosure")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task SaveForeclosureAsync_SingleLine_ReturnsOneFromRepo()
    {
        var lines   = new List<PrForeclosureLineKeyDto> { MakeLine() };
        var request = new PrForeclosureSaveRequestDto(lines);
        _repo.Setup(r => r.SaveForeclosureAsync(lines, DivCode, UserId, null, null))
             .ReturnsAsync(1);

        var count = await _sut.SaveForeclosureAsync(request, DivCode, UserId, null, null);

        count.Should().Be(1);
    }
}
