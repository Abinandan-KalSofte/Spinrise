using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.PoForeclosure;

// Service-layer guard for PO Foreclosure (FN §3: ≥1 line). Balance recompute,
// floor guard, clamp-WARN and stale-line RAISERROR are enforced inside
// ksp_PO_ForeCloseLines (server never trusts the client balance) — covered by the
// live LT-01 verification gate. The repo-throw test models how those SP errors
// surface through the service unchanged.
public class PoForeclosureServiceTests
{
    private readonly Mock<IPoForeclosureRepository> _repo = new();
    private readonly PoForeclosureService _sut;

    private const string DivCode = "01";
    private const string UserId  = "testuser";
    private static readonly DateTime TransDate = new(2026, 7, 11);

    public PoForeclosureServiceTests() => _sut = new PoForeclosureService(_repo.Object);

    private static ForeclosureLineKeyDto Line(decimal poNo = 1234m, int sNo = 1) =>
        new(poNo, "2026-07-01", "", sNo, "ITEM001", "555", "2026-06-01");

    private static ForeclosureSaveRequestDto Request(params ForeclosureLineKeyDto[] lines) =>
        new(lines.ToList());

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetOpenLinesForForeclose")]
    public async Task GetOpenLinesAsync_DelegatesToRepo()
    {
        var expected = new List<PoForeclosureLineDto>();
        _repo.Setup(r => r.GetOpenLinesAsync(DivCode)).ReturnsAsync(expected);

        (await _sut.GetOpenLinesAsync(DivCode)).Should().BeSameAs(expected);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "ForecloseLines")]
    [Trait("Type", "HappyPath")]
    public async Task ForecloseLinesAsync_ValidRequest_ReturnsCountFromRepo()
    {
        var request = Request(Line(), Line(sNo: 2));
        _repo.Setup(r => r.ForecloseLinesAsync(request, DivCode, TransDate, UserId, null, null))
             .ReturnsAsync(2);

        (await _sut.ForecloseLinesAsync(request, DivCode, TransDate, UserId, null, null)).Should().Be(2);
        _repo.Verify(r => r.ForecloseLinesAsync(request, DivCode, TransDate, UserId, null, null), Times.Once);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "ForecloseLines")]
    [Trait("Type", "NegativeCase")]
    public async Task ForecloseLinesAsync_NullLines_Throws()
    {
        var act = () => _sut.ForecloseLinesAsync(new ForeclosureSaveRequestDto(null!), DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*at least one item*");
        _repo.Verify(r => r.ForecloseLinesAsync(It.IsAny<ForeclosureSaveRequestDto>(), It.IsAny<string>(),
            It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "ForecloseLines")]
    [Trait("Type", "NegativeCase")]
    public async Task ForecloseLinesAsync_EmptyLines_Throws()
    {
        var act = () => _sut.ForecloseLinesAsync(Request(), DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*at least one item*");
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "ForecloseLines")]
    [Trait("Type", "ExceptionCase")]
    public async Task ForecloseLinesAsync_RepoThrowsStaleLine_Propagates()
    {
        var request = Request(Line());
        _repo.Setup(r => r.ForecloseLinesAsync(request, DivCode, TransDate, UserId, null, null))
             .ThrowsAsync(new InvalidOperationException("A selected line is already closed, cancelled or fully received."));

        var act = () => _sut.ForecloseLinesAsync(request, DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("*already closed*");
    }
}
