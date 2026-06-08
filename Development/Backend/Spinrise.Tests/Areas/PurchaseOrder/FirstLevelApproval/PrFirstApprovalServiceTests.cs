using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.FirstLevelApproval;

public class PrFirstApprovalServiceTests
{
    private readonly Mock<IPrFirstApprovalRepository>       _repo   = new();
    private readonly Mock<ILogger<PrFirstApprovalService>>  _logger = new();
    private readonly PrFirstApprovalService _sut;

    private const string DivCode  = "01";
    private const string UserId   = "testuser";
    private const string UserName = "Test User";
    private const int    ModuleNo = 5;

    private static SaveFirstApprovalLineRequest MakeLine(
        decimal prSno      = 1m,
        decimal qtyReqd    = 10m,
        decimal firstAppQty = 5m) =>
        new(prSno, "ITEM001", "ENG", qtyReqd, firstAppQty, 100m, null, null, null);

    public PrFirstApprovalServiceTests()
    {
        _sut = new PrFirstApprovalService(_repo.Object, _logger.Object);
    }

    // ── SaveAsync — authorisation guard ───────────────────────────────────────

    [Fact]
    public async Task SaveAsync_UserNotFirstLevel_ThrowsUnauthorizedAccessException()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L2", false));

        var request = new SaveFirstApprovalRequest(1m, DateTime.Today, DateTime.Today, [MakeLine()]);
        var act = () => _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("*not authorised*");
        _repo.Verify(r => r.SaveAsync(
            It.IsAny<string>(), It.IsAny<SaveFirstApprovalRequest>(),
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<int>()), Times.Never);
    }

    // ── SaveAsync — input validation ──────────────────────────────────────────

    [Fact]
    public async Task SaveAsync_EmptyLines_ThrowsInvalidOperationException()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));

        var request = new SaveFirstApprovalRequest(1m, DateTime.Today, DateTime.Today, []);
        var act = () => _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*at least one line*");
    }

    [Fact]
    public async Task SaveAsync_FutureAppDate_ThrowsInvalidOperationException()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));

        var futureDate = DateTime.Today.AddDays(1);
        var request    = new SaveFirstApprovalRequest(1m, DateTime.Today, futureDate, [MakeLine()]);
        var act        = () => _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*future*");
    }

    [Fact]
    public async Task SaveAsync_ZeroFirstAppQty_ThrowsInvalidOperationException()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));

        var request = new SaveFirstApprovalRequest(1m, DateTime.Today, DateTime.Today,
            [MakeLine(firstAppQty: 0m)]);
        var act = () => _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*greater than zero*");
    }

    [Fact]
    public async Task SaveAsync_FirstAppQtyExceedsQtyReqd_ThrowsInvalidOperationException()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));

        var request = new SaveFirstApprovalRequest(1m, DateTime.Today, DateTime.Today,
            [MakeLine(qtyReqd: 5m, firstAppQty: 10m)]);
        var act = () => _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*exceeds*");
    }

    // ── SaveAsync — happy path ────────────────────────────────────────────────

    [Fact]
    public async Task SaveAsync_ValidRequest_CallsRepoSave()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));
        _repo.Setup(r => r.SaveAsync(DivCode, It.IsAny<SaveFirstApprovalRequest>(),
            UserId, UserName, null, null, ModuleNo))
             .Returns(Task.CompletedTask);

        var request = new SaveFirstApprovalRequest(1m, DateTime.Today, DateTime.Today, [MakeLine()]);
        await _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        _repo.Verify(r => r.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo), Times.Once);
    }

    // ── DeleteAsync — authorisation guard ────────────────────────────────────

    [Fact]
    public async Task DeleteAsync_UserNotFirstLevel_ThrowsUnauthorizedAccessException()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L2", false));

        var request = new DeleteFirstApprovalRequest(1m, DateTime.Today);
        var act = () => _sut.DeleteAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("*not authorised*");
        _repo.Verify(r => r.DeleteAsync(
            It.IsAny<string>(), It.IsAny<DeleteFirstApprovalRequest>(),
            It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<int>()), Times.Never);
    }

    // ── DeleteAsync — happy path ──────────────────────────────────────────────

    [Fact]
    public async Task DeleteAsync_ValidRequest_CallsRepoDelete()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));
        _repo.Setup(r => r.DeleteAsync(DivCode, It.IsAny<DeleteFirstApprovalRequest>(),
            UserId, UserName, null, null, ModuleNo))
             .Returns(Task.CompletedTask);

        var request = new DeleteFirstApprovalRequest(1m, DateTime.Today);
        await _sut.DeleteAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        _repo.Verify(r => r.DeleteAsync(DivCode, request, UserId, UserName, null, null, ModuleNo), Times.Once);
    }

    // ── Regression: DEF-FA-03 (partial approval must not set full PRSTATUS='F') ──
    // The fix lives in ksp_PR_SaveFirstApproval.sql (NOT EXISTS subquery at line ~100).
    // This test verifies the service does not block or short-circuit partial-approval saves —
    // the service must always delegate to the repo so the SP can apply the correct guard.
    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "SaveFirstApproval")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Regression")]
    [Trait("DefectRef", "DEF-FA-03")]
    public async Task SaveAsync_PartialApprovalQty_ServiceDelegatesToRepoWithoutGuard()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));
        _repo.Setup(r => r.SaveAsync(DivCode, It.IsAny<SaveFirstApprovalRequest>(),
            UserId, UserName, null, null, ModuleNo))
             .Returns(Task.CompletedTask);

        // Partial approval: firstAppQty (3) < qtyReqd (10) — service must NOT block this
        var request = new SaveFirstApprovalRequest(1m, DateTime.Today, DateTime.Today,
            [MakeLine(qtyReqd: 10m, firstAppQty: 3m)]);

        var act = () => _sut.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        await act.Should().NotThrowAsync(
            "partial approvals are valid; the SP decides PRSTATUS — service must not interfere");
        _repo.Verify(r => r.SaveAsync(DivCode, request, UserId, UserName, null, null, ModuleNo), Times.Once);
    }

    // ── Regression: DEF-FA-08 (QTYREQD must revert when approval is deleted) ──
    // The fix is in the SP (ksp_PR_SaveFirstApproval delete path).
    // Service-layer test: delete call must always reach the repo without being blocked.
    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "DeleteFirstApproval")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Regression")]
    [Trait("DefectRef", "DEF-FA-08")]
    public async Task DeleteAsync_ApprovedPr_ReachesRepoSoSpCanRevertQtyReqd()
    {
        _repo.Setup(r => r.CheckUserApprovalLevelAsync(DivCode, UserId))
             .ReturnsAsync(("L1", true));
        _repo.Setup(r => r.DeleteAsync(DivCode, It.IsAny<DeleteFirstApprovalRequest>(),
            UserId, UserName, null, null, ModuleNo))
             .Returns(Task.CompletedTask);

        var request = new DeleteFirstApprovalRequest(1m, DateTime.Today);

        await _sut.DeleteAsync(DivCode, request, UserId, UserName, null, null, ModuleNo);

        _repo.Verify(r => r.DeleteAsync(DivCode, request, UserId, UserName, null, null, ModuleNo), Times.Once,
            "repo delete must be called so the SP can revert QTYREQD — DEF-FA-08");
    }
}
