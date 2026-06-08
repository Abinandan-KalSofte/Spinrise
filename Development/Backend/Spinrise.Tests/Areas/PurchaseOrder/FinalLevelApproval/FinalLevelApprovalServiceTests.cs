using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Services;
using Spinrise.Shared.Models;

namespace Spinrise.Tests.Areas.PurchaseOrder.FinalLevelApproval;

public class FinalLevelApprovalServiceTests
{
    private readonly Mock<IFinalLevelApprovalRepository>        _repo   = new();
    private readonly Mock<ILogger<FinalLevelApprovalService>>   _logger = new();
    private readonly FinalLevelApprovalService _sut;

    private const string FinalAppUser = "approver01";

    private static FinalApprovalSaveItemRequest MakeItem(
        decimal prNo = 1m, decimal prSno = 1m, int disposition = 0) =>
        new()
        {
            DivCode     = "01",
            PrNo        = prNo,
            PrDate      = "2026-01-01",
            PrSno       = prSno,
            QtyApproved = 5m,
            Disposition = disposition,
            RowVersion  = "AAAAAAAAAA==",
        };

    public FinalLevelApprovalServiceTests()
    {
        _sut = new FinalLevelApprovalService(_repo.Object, _logger.Object);
    }

    // ── SaveApprovalsAsync — guard: empty list ────────────────────────────────

    [Fact]
    public async Task SaveApprovalsAsync_EmptyItems_ThrowsInvalidOperationException()
    {
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [] };
        var act = () => _sut.SaveApprovalsAsync(request, FinalAppUser);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*No records*");
        _repo.Verify(r => r.SaveItemAsync(
            It.IsAny<FinalApprovalSaveItemRequest>(),
            It.IsAny<string>(), It.IsAny<int>()), Times.Never);
    }

    // ── SaveApprovalsAsync — guard: PL Discuss item ───────────────────────────

    [Fact]
    public async Task SaveApprovalsAsync_PlDiscussItem_ThrowsInvalidOperationException()
    {
        var request = new FinalApprovalSaveRequest
        {
            DbName = "JAT",
            Items  = [MakeItem(disposition: 1)]
        };
        var act = () => _sut.SaveApprovalsAsync(request, FinalAppUser);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*PL Discuss*");
        _repo.Verify(r => r.SaveItemAsync(
            It.IsAny<FinalApprovalSaveItemRequest>(),
            It.IsAny<string>(), It.IsAny<int>()), Times.Never);
    }

    // ── SaveApprovalsAsync — conflict: repo returns 3 ────────────────────────

    [Fact]
    public async Task SaveApprovalsAsync_ConflictResult_ThrowsConcurrencyConflictException()
    {
        var item    = MakeItem(prNo: 10m, prSno: 2m);
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [item] };
        _repo.Setup(r => r.SaveItemAsync(item, FinalAppUser, 0)).ReturnsAsync(3);

        var act = () => _sut.SaveApprovalsAsync(request, FinalAppUser);

        await act.Should().ThrowAsync<ConcurrencyConflictException>();
    }

    // ── SaveApprovalsAsync — happy path ───────────────────────────────────────

    [Fact]
    public async Task SaveApprovalsAsync_TwoValidItems_ReturnsSavedCount()
    {
        var item1   = MakeItem(prNo: 1m, prSno: 1m);
        var item2   = MakeItem(prNo: 1m, prSno: 2m);
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [item1, item2] };
        _repo.Setup(r => r.SaveItemAsync(item1, FinalAppUser, 0)).ReturnsAsync(0);
        _repo.Setup(r => r.SaveItemAsync(item2, FinalAppUser, 0)).ReturnsAsync(0);

        var result = await _sut.SaveApprovalsAsync(request, FinalAppUser);

        result.ApprovedCount.Should().Be(2);
        result.Message.Should().Contain("Completed");
    }

    // ── SaveApprovalsAsync — repo returns 2 (cancelled PR) ───────────────────

    [Fact]
    public async Task SaveApprovalsAsync_CancelledPr_ThrowsInvalidOperationException()
    {
        var item    = MakeItem(prNo: 5m, prSno: 1m);
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [item] };
        _repo.Setup(r => r.SaveItemAsync(item, FinalAppUser, 0)).ReturnsAsync(2);

        var act = () => _sut.SaveApprovalsAsync(request, FinalAppUser);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*cancelled*");
    }

    // ── SaveApprovalsAsync — repo returns 4 (not found) ──────────────────────

    [Fact]
    public async Task SaveApprovalsAsync_NotFoundPr_ThrowsInvalidOperationException()
    {
        var item    = MakeItem(prNo: 6m, prSno: 1m);
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [item] };
        _repo.Setup(r => r.SaveItemAsync(item, FinalAppUser, 0)).ReturnsAsync(4);

        var act = () => _sut.SaveApprovalsAsync(request, FinalAppUser);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*not found*");
    }

    // ── SaveApprovalsAsync — bypass flag ─────────────────────────────────────

    [Fact]
    public async Task SaveApprovalsAsync_BypassAllTrue_PassesBypassOneToRepo()
    {
        var item    = MakeItem();
        var request = new FinalApprovalSaveRequest { DbName = "JAT", BypassAll = true, Items = [item] };
        _repo.Setup(r => r.SaveItemAsync(item, FinalAppUser, 1)).ReturnsAsync(0);

        var result = await _sut.SaveApprovalsAsync(request, FinalAppUser);

        result.ApprovedCount.Should().Be(1);
        _repo.Verify(r => r.SaveItemAsync(item, FinalAppUser, 1), Times.Once);
    }

    // ── Regression: FA-DS-01 (disposition default must be Approved=2, not 0) ──
    // Root cause: SP not deployed to JAT live DB + FE defaulting to 0 instead of 2 (commit a45490d).
    // The service does not guard disposition values (only blocks PL Discuss=1).
    // Regression tests here verify: disposition=2 passes through; disposition=1 is still blocked.
    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveFinalApproval")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Regression")]
    [Trait("DefectRef", "FA-DS-01")]
    public async Task SaveApprovalsAsync_DispositionApproved_IsAcceptedAndReachesRepo()
    {
        var item = MakeItem(disposition: 2); // 2 = Approved
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [item] };
        _repo.Setup(r => r.SaveItemAsync(item, FinalAppUser, 0)).ReturnsAsync(0);

        var result = await _sut.SaveApprovalsAsync(request, FinalAppUser);

        result.ApprovedCount.Should().Be(1, "disposition=2 (Approved) must reach the SP — FA-DS-01");
        _repo.Verify(r => r.SaveItemAsync(item, FinalAppUser, 0), Times.Once);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveFinalApproval")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Regression")]
    [Trait("DefectRef", "FA-DS-01")]
    public async Task SaveApprovalsAsync_DispositionPlDiscuss_StillBlockedAfterFix()
    {
        // disposition=1 (PL Discuss) must remain blocked post FA-DS-01 fix — ensure no regression
        var request = new FinalApprovalSaveRequest { DbName = "JAT", Items = [MakeItem(disposition: 1)] };

        var act = () => _sut.SaveApprovalsAsync(request, FinalAppUser);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*PL Discuss*", "blocking PL Discuss must remain intact — FA-DS-01 regression");
    }
}
