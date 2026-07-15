using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.PoApproval;

public class PoApprovalServiceTests
{
    private readonly Mock<IPoApprovalRepository>      _repo   = new();
    private readonly Mock<ILogger<PoApprovalService>> _logger = new();
    private readonly PoApprovalService _sut;

    private const string UserId   = "abinandan";
    private const string UserName = "Abinandan";

    public PoApprovalServiceTests()
    {
        _sut = new PoApprovalService(_repo.Object, _logger.Object);
    }

    private static PoApprovalSaveItemRequest MakeItem(
        decimal poNo = 100m, int disposition = 2, string? remarks = null,
        string? postponeDate = null, string divCode = "01") =>
        new(divCode, poNo, "2026-07-09", disposition, remarks, postponeDate);

    // ── SaveAsync — invalid level ──────────────────────────────────────────────

    [Fact]
    public async Task SaveAsync_InvalidLevel_ThrowsArgumentException()
    {
        var request = new PoApprovalSaveRequest([MakeItem()]);
        var act = () => _sut.SaveAsync("bogus", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<ArgumentException>();
        _repo.Verify(r => r.SetApprovalAsync(
            It.IsAny<string>(), It.IsAny<PoApprovalSaveItemRequest>(),
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    // ── SaveAsync — empty items ────────────────────────────────────────────────

    [Fact]
    public async Task SaveAsync_EmptyItems_ThrowsInvalidOperationException()
    {
        var request = new PoApprovalSaveRequest([]);
        var act = () => _sut.SaveAsync("first", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*selected*");
    }

    // ── SaveAsync — missing/sentinel divCode (10-Jul-2026 bug fix) ─────────────

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("0")]
    public async Task SaveAsync_MissingOrSentinelDivCode_ThrowsInvalidOperationException(string? divCode)
    {
        var request = new PoApprovalSaveRequest([MakeItem(divCode: divCode!)]);
        var act = () => _sut.SaveAsync("first", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*division code*");
        _repo.Verify(r => r.SetApprovalAsync(
            It.IsAny<string>(), It.IsAny<PoApprovalSaveItemRequest>(),
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    // ── SaveAsync — mandatory-reason rule (disposition 3/4/5) ─────────────────

    [Theory]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(5)]
    public async Task SaveAsync_HoldDeclinedPostponeWithoutRemarks_ThrowsInvalidOperationException(int disposition)
    {
        var request = new PoApprovalSaveRequest([MakeItem(disposition: disposition, remarks: "")]);
        var act = () => _sut.SaveAsync("first", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*Remarks are mandatory*");
        _repo.Verify(r => r.SetApprovalAsync(
            It.IsAny<string>(), It.IsAny<PoApprovalSaveItemRequest>(),
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task SaveAsync_HoldWithRemarks_ReachesRepository()
    {
        var item    = MakeItem(disposition: 3, remarks: "Awaiting budget confirmation");
        var request = new PoApprovalSaveRequest([item]);
        _repo.Setup(r => r.SetApprovalAsync("first", item, UserId, UserName, null, null))
             .ReturnsAsync(0);

        var result = await _sut.SaveAsync("first", request, UserId, UserName, null, null);

        result.Saved.Should().ContainSingle().Which.Should().Be(100m);
    }

    // ── SaveAsync — postpone-date mandatory for disposition=5 (BR-05, legacy parity) ──

    [Fact]
    public async Task SaveAsync_PostponeWithoutDate_ThrowsInvalidOperationException()
    {
        var request = new PoApprovalSaveRequest(
            [MakeItem(disposition: 5, remarks: "Supplier confirmation pending", postponeDate: null)]);
        var act = () => _sut.SaveAsync("first", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*postpone date is mandatory*");
        _repo.Verify(r => r.SetApprovalAsync(
            It.IsAny<string>(), It.IsAny<PoApprovalSaveItemRequest>(),
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task SaveAsync_PostponeWithDateAndRemarks_ReachesRepository()
    {
        var item    = MakeItem(disposition: 5, remarks: "Awaiting revised quote", postponeDate: "2026-07-20");
        var request = new PoApprovalSaveRequest([item]);
        _repo.Setup(r => r.SetApprovalAsync("first", item, UserId, UserName, null, null))
             .ReturnsAsync(0);

        var result = await _sut.SaveAsync("first", request, UserId, UserName, null, null);

        result.Saved.Should().ContainSingle().Which.Should().Be(100m);
    }

    // ── SaveAsync — happy path (Approve, no remarks required) ──────────────────

    [Fact]
    public async Task SaveAsync_ApprovedItem_ReturnsSavedPoNo()
    {
        var item    = MakeItem(poNo: 555m, disposition: 2, divCode: "02");
        var request = new PoApprovalSaveRequest([item]);
        _repo.Setup(r => r.SetApprovalAsync("final", item, UserId, UserName, null, null))
             .ReturnsAsync(0);

        var result = await _sut.SaveAsync("final", request, UserId, UserName, null, null);

        result.Saved.Should().ContainSingle().Which.Should().Be(555m);
    }

    // ── SaveAsync — mixed divisions in one batch (ALL-divisions filter scenario) ──

    [Fact]
    public async Task SaveAsync_ItemsFromDifferentDivisions_EachUsesItsOwnDivCode()
    {
        var item1   = MakeItem(poNo: 100m, divCode: "01");
        var item2   = MakeItem(poNo: 200m, divCode: "02");
        var request = new PoApprovalSaveRequest([item1, item2]);
        _repo.Setup(r => r.SetApprovalAsync("first", item1, UserId, UserName, null, null)).ReturnsAsync(0);
        _repo.Setup(r => r.SetApprovalAsync("first", item2, UserId, UserName, null, null)).ReturnsAsync(0);

        var result = await _sut.SaveAsync("first", request, UserId, UserName, null, null);

        result.Saved.Should().BeEquivalentTo([100m, 200m]);
        _repo.Verify(r => r.SetApprovalAsync("first", item1, UserId, UserName, null, null), Times.Once);
        _repo.Verify(r => r.SetApprovalAsync("first", item2, UserId, UserName, null, null), Times.Once);
    }

    // ── SaveAsync — repository returns 2 (prerequisite not met) ────────────────

    [Fact]
    public async Task SaveAsync_PrerequisiteNotMet_ThrowsInvalidOperationException()
    {
        var item    = MakeItem();
        var request = new PoApprovalSaveRequest([item]);
        _repo.Setup(r => r.SetApprovalAsync("second", item, UserId, UserName, null, null))
             .ReturnsAsync(2);

        var act = () => _sut.SaveAsync("second", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*prerequisite*");
    }

    // ── SaveAsync — repository returns 3 (unreachable per CR-PO-APPROVAL-01/CD-08 —
    // RowVersion is always NULL, so the SP can never actually return 3; if it somehow
    // did, the item is silently skipped — neither saved nor thrown) ────────────────

    [Fact]
    public async Task SaveAsync_UnexpectedResultThree_IsSilentlySkipped()
    {
        var item    = MakeItem();
        var request = new PoApprovalSaveRequest([item]);
        _repo.Setup(r => r.SetApprovalAsync("first", item, UserId, UserName, null, null))
             .ReturnsAsync(3);

        var result = await _sut.SaveAsync("first", request, UserId, UserName, null, null);

        result.Saved.Should().BeEmpty();
    }

    // ── SaveAsync — repository returns 4 (not found) ───────────────────────────

    [Fact]
    public async Task SaveAsync_NotFound_ThrowsInvalidOperationException()
    {
        var item    = MakeItem();
        var request = new PoApprovalSaveRequest([item]);
        _repo.Setup(r => r.SetApprovalAsync("first", item, UserId, UserName, null, null))
             .ReturnsAsync(4);

        var act = () => _sut.SaveAsync("first", request, UserId, UserName, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*not found*");
    }

    // ── GetPendingAsync — invalid level ────────────────────────────────────────

    private static readonly DateTime YfDate = new(2026, 4, 1);
    private static readonly DateTime YlDate = new(2027, 3, 31);

    [Fact]
    public async Task GetPendingAsync_InvalidLevel_ThrowsArgumentException()
    {
        var act = () => _sut.GetPendingAsync("nope", "01", YfDate, YlDate, null);
        await act.Should().ThrowAsync<ArgumentException>();
    }

    [Fact]
    public async Task GetPendingAsync_ValidLevel_DelegatesToRepository()
    {
        _repo.Setup(r => r.GetPendingAsync("first", "01", YfDate, YlDate, null))
             .ReturnsAsync(new List<PoApprovalLineDto>());

        var result = await _sut.GetPendingAsync("first", "01", YfDate, YlDate, null);

        result.Items.Should().BeEmpty();
        _repo.Verify(r => r.GetPendingAsync("first", "01", YfDate, YlDate, null), Times.Once);
    }

    // 10-Jul-2026 /verify finding: missing yfDate/ylDate query params silently bound
    // to default(DateTime), which SQL Server's DATETIME type rejected with an
    // unhandled 500 (SqlTypeException) instead of a clean 400. Locks in the fix.
    [Fact]
    public async Task GetPendingAsync_MissingFYBounds_ThrowsInvalidOperationException()
    {
        var act = () => _sut.GetPendingAsync("first", "01", default, YlDate, null);
        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*Financial year*");

        _repo.Verify(r => r.GetPendingAsync(
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<DateTime>(), It.IsAny<DateTime>(), It.IsAny<string?>()), Times.Never);
    }
}
