using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.Cancellation;

public class PrCancellationServiceTests
{
    private readonly Mock<IPrCancellationRepository> _repo = new();
    private readonly PrCancellationService _sut;

    private const string DivCode   = "01";
    private const string UserId    = "testuser";
    private const decimal PrNo     = 12345m;
    private const string PrDate    = "2026-01-15";
    private const string DepCode   = "ENG";
    private const string RowVer    = "AAAAAAAAAA==";

    public PrCancellationServiceTests()
    {
        _sut = new PrCancellationService(_repo.Object);
    }

    // ── GetCancellablePRsAsync ────────────────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetCancellablePRs")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetCancellablePRsAsync_DelegatesToRepo()
    {
        var expected = new List<PrCancellablePrDto>();
        _repo.Setup(r => r.GetCancellablePRsAsync(DivCode, It.IsAny<DateTime>(), It.IsAny<DateTime>()))
             .ReturnsAsync(expected);

        var result = await _sut.GetCancellablePRsAsync(DivCode, DateTime.Today, DateTime.Today);

        result.Should().BeSameAs(expected);
    }

    // ── CancelPRAsync — validation ────────────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelPR")]
    [Trait("Layer", "Service")]
    [Trait("Type", "NegativeCase")]
    public async Task CancelPRAsync_EmptyReason_ThrowsInvalidOperationException()
    {
        var request = new PrCancelRequestDto(PrNo, PrDate, DepCode, "   ");

        var act = () => _sut.CancelPRAsync(request, DivCode, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*Reason*");
        _repo.Verify(r => r.CancelPRAsync(
            It.IsAny<PrCancelRequestDto>(), It.IsAny<string>(),
            It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelPR")]
    [Trait("Layer", "Service")]
    [Trait("Type", "NegativeCase")]
    public async Task CancelPRAsync_NullReason_ThrowsInvalidOperationException()
    {
        var request = new PrCancelRequestDto(PrNo, PrDate, DepCode, null!);

        var act = () => _sut.CancelPRAsync(request, DivCode, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>();
        _repo.Verify(r => r.CancelPRAsync(
            It.IsAny<PrCancelRequestDto>(), It.IsAny<string>(),
            It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelPR")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task CancelPRAsync_ValidReason_CallsRepoCancel()
    {
        var request = new PrCancelRequestDto(PrNo, PrDate, DepCode, "Vendor not available");
        _repo.Setup(r => r.CancelPRAsync(request, DivCode, UserId, null, null))
             .Returns(Task.CompletedTask);

        await _sut.CancelPRAsync(request, DivCode, UserId, null, null);

        _repo.Verify(r => r.CancelPRAsync(request, DivCode, UserId, null, null), Times.Once);
    }

    // ── UndoCancellationAsync — happy path + DEF-PRC-02 regression ───────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "UndoCancellation")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task UndoCancellationAsync_ValidRequest_DelegatesToRepo()
    {
        var request = new PrUndoRequestDto(PrNo, PrDate, DepCode, RowVer);
        _repo.Setup(r => r.UndoCancellationAsync(request, DivCode, UserId, null, null))
             .Returns(Task.CompletedTask);

        await _sut.UndoCancellationAsync(request, DivCode, UserId, null, null);

        _repo.Verify(r => r.UndoCancellationAsync(request, DivCode, UserId, null, null), Times.Once);
    }

    // DEF-PRC-02 regression: UndoCancellation should NOT throw a RowVersion exception from the
    // service layer. The SP fix (commit d6e3674) removed the rowversion guard that caused this.
    // This test documents the expected service behaviour post-fix.
    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "UndoCancellation")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Regression")]
    [Trait("DefectRef", "DEF-PRC-02")]
    public async Task UndoCancellationAsync_RowVersionProvided_DoesNotThrowAtServiceLayer()
    {
        var request = new PrUndoRequestDto(PrNo, PrDate, DepCode, RowVer);
        _repo.Setup(r => r.UndoCancellationAsync(request, DivCode, UserId, null, null))
             .Returns(Task.CompletedTask);

        var act = () => _sut.UndoCancellationAsync(request, DivCode, UserId, null, null);

        await act.Should().NotThrowAsync(
            "service must not add its own RowVersion guard — DEF-PRC-02 was caused by an SP-level issue");
    }

    // ── GetCancelledPRsForUndoAsync ───────────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetCancelledForUndo")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetCancelledPRsForUndoAsync_DelegatesToRepo()
    {
        var expected = new List<PrCancelledPrDto>();
        _repo.Setup(r => r.GetCancelledPRsForUndoAsync(DivCode, It.IsAny<DateTime>(), It.IsAny<DateTime>()))
             .ReturnsAsync(expected);

        var result = await _sut.GetCancelledPRsForUndoAsync(DivCode, DateTime.Today, DateTime.Today);

        result.Should().BeSameAs(expected);
    }
}
