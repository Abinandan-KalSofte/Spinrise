using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.PurchaseRequisition;

public class PrServiceTests
{
    private readonly Mock<IPrRepository> _repo = new();
    private readonly PrService _sut;

    private static readonly DateOnly FDate = new(2025, 4, 1);
    private static readonly DateOnly LDate = new(2026, 3, 31);
    private static readonly DateOnly PDate = new(2025, 5, 19);
    private const string DivCode = "01";
    private const string UserId  = "testuser";

    private static SavePrLineRequest MakeLine(
        string itemCode = "ITEM001",
        decimal qty = 5m,
        string rateSource = "LPO",
        string? rateJustification = null) => new()
    {
        ItemCode          = itemCode,
        QtyInd            = qty,
        Rate              = 100m,
        RateSource        = rateSource,
        RateJustification = rateJustification,
        Sample            = "N",
    };

    private static SavePrRequest MakeRequest(
        string depCode = "ENG",
        decimal? existingPrNo = null,
        DateOnly? existingPrDate = null,
        List<SavePrLineRequest>? lines = null) => new()
    {
        PrDate         = PDate,
        DepCode        = depCode,
        ExistingPrNo   = existingPrNo,
        ExistingPrDate = existingPrDate,
        Lines          = lines ?? [MakeLine()],
    };

    public PrServiceTests()
    {
        _sut = new PrService(_repo.Object);
    }

    // ── Passthrough delegations ────────────────────────────────────────────────

    [Fact]
    public async Task GetParametersAsync_DelegatesToRepo()
    {
        var dto = new PrParametersDto { ManualIndNo = "N", BudgetQty = "N", PendingOrderPara = "N" };
        _repo.Setup(r => r.GetParametersAsync(DivCode)).ReturnsAsync(dto);

        var result = await _sut.GetParametersAsync(DivCode);

        result.Should().BeSameAs(dto);
        _repo.Verify(r => r.GetParametersAsync(DivCode), Times.Once);
    }

    [Fact]
    public async Task RunPreAddChecksAsync_DelegatesToRepo()
    {
        var dto = new PreAddChecksDto(true, true, true, "Y", null);
        _repo.Setup(r => r.RunPreAddChecksAsync(DivCode)).ReturnsAsync(dto);

        var result = await _sut.RunPreAddChecksAsync(DivCode);

        result.Should().BeSameAs(dto);
        _repo.Verify(r => r.RunPreAddChecksAsync(DivCode), Times.Once);
    }

    [Fact]
    public async Task GetDepartmentsAsync_DelegatesToRepo()
    {
        var depts = new List<DepartmentDto> { new("ENG", "Engineering") };
        _repo.Setup(r => r.GetDepartmentsAsync(DivCode, "ENG")).ReturnsAsync(depts);

        var result = await _sut.GetDepartmentsAsync(DivCode, "ENG");

        result.Should().BeSameAs(depts);
    }

    [Fact]
    public async Task GetEmployeesAsync_DelegatesToRepo()
    {
        var emps = new List<EmployeeDto> { new("E001", "John") };
        _repo.Setup(r => r.GetEmployeesAsync(DivCode, "N", "John")).ReturnsAsync(emps);

        var result = await _sut.GetEmployeesAsync(DivCode, "N", "John");

        result.Should().BeSameAs(emps);
    }

    [Fact]
    public async Task GetItemsAsync_DelegatesToRepo()
    {
        var items = new List<ItemLookupDto>();
        _repo.Setup(r => r.GetItemsAsync(DivCode, null, null, 1, 50)).ReturnsAsync(items);

        var result = await _sut.GetItemsAsync(DivCode, null, null, 1, 50);

        result.Should().BeSameAs(items);
    }

    [Fact]
    public async Task CheckPendingOrderAsync_DelegatesToRepo()
    {
        var pending = new PendingOrderDto(10m);
        _repo.Setup(r => r.CheckPendingOrderAsync(DivCode, FDate, LDate, "ENG", "ITEM001"))
             .ReturnsAsync(pending);

        var result = await _sut.CheckPendingOrderAsync(DivCode, FDate, LDate, "ENG", "ITEM001");

        result.Should().BeSameAs(pending);
        result!.PendingQty.Should().Be(10m);
    }

    [Fact]
    public async Task DeleteAsync_DelegatesToRepo()
    {
        var req = new DeletePrRequest { PrNo = 1, PrDate = PDate, DeleteMode = "FULL" };
        _repo.Setup(r => r.DeleteAsync(DivCode, req, UserId, null, null)).Returns(Task.CompletedTask);

        await _sut.DeleteAsync(DivCode, req, UserId, null, null);

        _repo.Verify(r => r.DeleteAsync(DivCode, req, UserId, null, null), Times.Once);
    }

    // ── AddAsync — success ────────────────────────────────────────────────────

    [Fact]
    public async Task AddAsync_ValidRequest_CallsRepoSaveAndReturnsPrNo()
    {
        var request = MakeRequest();
        _repo.Setup(r => r.SaveAsync("ADD", DivCode, request, UserId, null, null, FDate, LDate))
             .ReturnsAsync(42m);

        var result = await _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        result.Should().Be(42m);
        _repo.Verify(r => r.SaveAsync("ADD", DivCode, request, UserId, null, null, FDate, LDate), Times.Once);
    }

    // ── AddAsync — validation failures ────────────────────────────────────────

    [Fact]
    public async Task AddAsync_EmptyDepCode_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(depCode: "   ");

        var act = () => _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*Department*");
    }

    [Fact]
    public async Task AddAsync_NoValidLines_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(lines: [new SavePrLineRequest { ItemCode = "   ", QtyInd = 5m, Sample = "N" }]);

        var act = () => _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*at least one Item*");
    }

    [Fact]
    public async Task AddAsync_ZeroQuantity_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(lines: [MakeLine(qty: 0m)]);

        var act = () => _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*quantity*");
    }

    [Fact]
    public async Task AddAsync_ManualRateWithoutJustification_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(lines: [MakeLine(rateSource: "MANUAL", rateJustification: null)]);

        var act = () => _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*justification*");
    }

    [Fact]
    public async Task AddAsync_ManualRateWithJustification_Succeeds()
    {
        var request = MakeRequest(lines: [MakeLine(rateSource: "MANUAL", rateJustification: "Market survey")]);
        _repo.Setup(r => r.SaveAsync("ADD", DivCode, request, UserId, null, null, FDate, LDate))
             .ReturnsAsync(7m);

        var result = await _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        result.Should().Be(7m);
    }

    [Fact]
    public async Task AddAsync_MixedBlankAndValidLines_OnlyValidatesNonBlank()
    {
        var lines   = new List<SavePrLineRequest>
        {
            new() { ItemCode = "", QtyInd = 0m, Sample = "N" },
            MakeLine(),
        };
        var request = MakeRequest(lines: lines);
        _repo.Setup(r => r.SaveAsync("ADD", DivCode, request, UserId, null, null, FDate, LDate))
             .ReturnsAsync(5m);

        var result = await _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate);

        result.Should().Be(5m);
    }

    // ── ModifyAsync — success ─────────────────────────────────────────────────

    [Fact]
    public async Task ModifyAsync_ValidRequest_CallsRepoSaveWithModifyMode()
    {
        var request = MakeRequest(existingPrNo: 10m, existingPrDate: PDate);
        _repo.Setup(r => r.SaveAsync("MODIFY", DivCode, request, UserId, null, null, FDate, LDate))
             .ReturnsAsync(10m);

        var result = await _sut.ModifyAsync(DivCode, request, UserId, null, null, FDate, LDate);

        result.Should().Be(10m);
        _repo.Verify(r => r.SaveAsync("MODIFY", DivCode, request, UserId, null, null, FDate, LDate), Times.Once);
    }

    // ── ModifyAsync — validation failures ────────────────────────────────────

    [Fact]
    public async Task ModifyAsync_MissingExistingPrNo_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(existingPrNo: null, existingPrDate: PDate);

        var act = () => _sut.ModifyAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*ExistingPrNo*");
    }

    [Fact]
    public async Task ModifyAsync_MissingExistingPrDate_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(existingPrNo: 10m, existingPrDate: null);

        var act = () => _sut.ModifyAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*ExistingPrDate*");
    }

    [Fact]
    public async Task ModifyAsync_EmptyDepCode_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(depCode: "", existingPrNo: 10m, existingPrDate: PDate);

        var act = () => _sut.ModifyAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*Department*");
    }

    [Fact]
    public async Task ModifyAsync_ZeroQuantity_ThrowsInvalidOperationException()
    {
        var request = MakeRequest(existingPrNo: 10m, existingPrDate: PDate,
            lines: [MakeLine(qty: 0m)]);

        var act = () => _sut.ModifyAsync(DivCode, request, UserId, null, null, FDate, LDate);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*quantity*");
    }

    // ── Repository not called on validation failure ───────────────────────────

    [Fact]
    public async Task AddAsync_ValidationFailure_RepoSaveNeverCalled()
    {
        var request = MakeRequest(depCode: "");

        try { await _sut.AddAsync(DivCode, request, UserId, null, null, FDate, LDate); } catch { /* expected */ }

        _repo.Verify(r => r.SaveAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<SavePrRequest>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<DateOnly>(), It.IsAny<DateOnly>()), Times.Never);
    }

    [Fact]
    public async Task ModifyAsync_ValidationFailure_RepoSaveNeverCalled()
    {
        var request = MakeRequest(existingPrNo: null, existingPrDate: null);

        try { await _sut.ModifyAsync(DivCode, request, UserId, null, null, FDate, LDate); } catch { /* expected */ }

        _repo.Verify(r => r.SaveAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<SavePrRequest>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(),
            It.IsAny<DateOnly>(), It.IsAny<DateOnly>()), Times.Never);
    }
}
