using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.PoCancellation;

// Service-layer guards for PO Cancellation (FN §3 defence-in-depth). The
// balance/floor/clamp-WARN/stale-line behaviours are enforced inside
// ksp_PO_CancelLines (server-authoritative) and are covered by the live LT-01
// verification gate, not mockable at this layer — the repo-throw test models how
// those SP RAISERRORs surface through the service unchanged.
public class PoCancellationServiceTests
{
    private readonly Mock<IPoCancellationRepository> _repo = new();
    private readonly PoCancellationService _sut;

    private const string DivCode = "01";
    private const string UserId  = "testuser";
    private static readonly DateTime TransDate = new(2026, 7, 11);

    public PoCancellationServiceTests() => _sut = new PoCancellationService(_repo.Object);

    private static CancelSaveRequestDto Request(params CancelLineRequestDto[] lines) =>
        new(1234m, "2026-07-01", lines.ToList());

    private static CancelLineRequestDto Line(decimal qty = 5m, string reason = "R1", int sNo = 1) =>
        new(sNo, "ITEM001", reason, qty);

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetReasons")]
    public async Task GetReasonsAsync_DelegatesToRepo()
    {
        var expected = new List<CancellationReasonDto>();
        _repo.Setup(r => r.GetReasonsAsync()).ReturnsAsync(expected);

        (await _sut.GetReasonsAsync()).Should().BeSameAs(expected);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetOpenPOList")]
    public async Task GetOpenPOListAsync_DelegatesToRepo()
    {
        var yfDate = new DateTime(2026, 4, 1);
        var ylDate = new DateTime(2027, 3, 31);
        var expected = new List<PoOpenSummaryDto>();
        _repo.Setup(r => r.GetOpenPOListAsync(DivCode, yfDate, ylDate)).ReturnsAsync(expected);

        (await _sut.GetOpenPOListAsync(DivCode, yfDate, ylDate)).Should().BeSameAs(expected);
    }

    // 13-Jul-2026: same FY-bounds guard as PoApprovalService.GetPendingAsync (T-0153)
    // — a missing/default date binds to SQL DATETIME's min value and would surface
    // as an unhandled 500 (SqlTypeException) instead of a clean 400.
    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetOpenPOList")]
    [Trait("Type", "NegativeCase")]
    public async Task GetOpenPOListAsync_MissingFYBounds_Throws()
    {
        var act = () => _sut.GetOpenPOListAsync(DivCode, default, new DateTime(2027, 3, 31));

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*Financial year*");
        _repo.Verify(r => r.GetOpenPOListAsync(It.IsAny<string>(), It.IsAny<DateTime>(), It.IsAny<DateTime>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetLinesForCancel")]
    public async Task GetOpenLinesAsync_DelegatesToRepo()
    {
        var expected = new List<PoCancellationLineDto>();
        _repo.Setup(r => r.GetOpenLinesAsync(DivCode, 1234m, "2026-07-01")).ReturnsAsync(expected);

        (await _sut.GetOpenLinesAsync(DivCode, 1234m, "2026-07-01")).Should().BeSameAs(expected);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelLines")]
    [Trait("Type", "HappyPath")]
    public async Task CancelLinesAsync_ValidRequest_DelegatesToRepo()
    {
        var request = Request(Line(), Line(sNo: 2));
        _repo.Setup(r => r.CancelLinesAsync(request, DivCode, TransDate, UserId, null, null))
             .Returns(Task.CompletedTask);

        await _sut.CancelLinesAsync(request, DivCode, TransDate, UserId, null, null);

        _repo.Verify(r => r.CancelLinesAsync(request, DivCode, TransDate, UserId, null, null), Times.Once);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelLines")]
    [Trait("Type", "NegativeCase")]
    public async Task CancelLinesAsync_NoLines_Throws()
    {
        var act = () => _sut.CancelLinesAsync(Request(), DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*at least one item*");
        _repo.Verify(r => r.CancelLinesAsync(It.IsAny<CancelSaveRequestDto>(), It.IsAny<string>(),
            It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelLines")]
    [Trait("Type", "NegativeCase")]
    public async Task CancelLinesAsync_ZeroQty_Throws()
    {
        var act = () => _sut.CancelLinesAsync(Request(Line(qty: 0m)), DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*Cancel Quantity*");
        _repo.Verify(r => r.CancelLinesAsync(It.IsAny<CancelSaveRequestDto>(), It.IsAny<string>(),
            It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelLines")]
    [Trait("Type", "NegativeCase")]
    public async Task CancelLinesAsync_MissingReason_Throws()
    {
        var act = () => _sut.CancelLinesAsync(Request(Line(reason: "  ")), DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*Reason*");
        _repo.Verify(r => r.CancelLinesAsync(It.IsAny<CancelSaveRequestDto>(), It.IsAny<string>(),
            It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "CancelLines")]
    [Trait("Type", "ExceptionCase")]
    public async Task CancelLinesAsync_RepoThrowsStaleLine_Propagates()
    {
        var request = Request(Line());
        _repo.Setup(r => r.CancelLinesAsync(request, DivCode, TransDate, UserId, null, null))
             .ThrowsAsync(new InvalidOperationException("A selected cancellation line no longer exists."));

        var act = () => _sut.CancelLinesAsync(request, DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*no longer exists*");
    }
}
