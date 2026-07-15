using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Services;

namespace Spinrise.Tests.Areas.PurchaseOrder.PurchaseOrderAmendment;

// FN-PO-Amendment v1.2 §3 — the static half of the validation rules (the checks
// that need no server recompute). Budget (§3.9), tax-code activity (§3.5) and the
// RCVDQTY+CANQTY floor (§3.4 dynamic) are the SP's and are deliberately NOT tested
// here — they are not implemented in C# by design (FN §4.B).
public class PoAmendmentServiceTests
{
    private readonly Mock<IPoAmendmentRepository> _repo = new();
    private readonly PoAmendmentService _sut;

    private const string   DivCode = "01";
    private const string   UserId  = "testuser";
    private const decimal  PoNo    = 1285m;
    private const string   PoDate  = "2026-07-11";
    private const string   PoGroup = "CR";
    private const string   Carrier = "CAR01";
    private static readonly DateTime TransDate = new(2026, 7, 13);

    public PoAmendmentServiceTests()
    {
        _sut = new PoAmendmentService(_repo.Object);
    }

    private static AmendmentLineSaveDto Line(string? amendReason = "Rate revised") =>
        new(
            SNo: 1, ItemCode: "1334001",
            PrNo: 900m, PrDate: "2026-07-01", PrSno: 1m,
            Rate: 250.50m, Qty: 10m, Weight: 0m,
            DiscPer: 0m, PackingPer: 0m, FreightPer: 0m, InsurancePer: 0m, OtherCharges: 0m,
            DiscApp: "BEFORE", PackApp: "BEFORE", FreightPos: "BEFORE", InsuranceDuty: "BEFORE",
            TaxCode: "GST18", HsnCode: "2710", CgstCode: "C9", SgstCode: "S9", IgstCode: "",
            TcsPer: 0m, AddTaxCode: "", AddTaxPer: 0m,
            Remarks: "", ItemMemo: "", AmendReason: amendReason, Slots: null);

    private const string Supplier = "SUP001";

    private static AmendmentSaveRequestDto Request(
        string carrier  = Carrier,
        string poGroup  = PoGroup,
        string supplier = Supplier,
        List<AmendmentLineSaveDto>? lines = null) =>
        new(
            PoNo: PoNo, PoDate: PoDate, PoGroup: poGroup, Carrier: carrier,
            Supplier: supplier,
            Gstin: null, GstState: null, Inspect: null, FormType: null,
            Currency: null, CurrRate: 0m, Remarks: null, RefNo: null, RefDate: null,
            FileNo: null, PaymentTerms: null, CreditDays: 0, BankCode: null,
            PayMode: null, DirectInstr: null, AdvPer: 0m, AdvAmt: 0m,
            ChequeNo: null, ChequeDate: null,
            DeliveryInstr1: null, DeliveryInstr2: null, SpecialInstr: null,
            DueDate: null, RoundOff: 0m,
            DiscPer: 0m, PackPer: 0m, InsurPer: 0m, FreightAmt: 0m,
            PackingAmt: 0m, InsuranceAmt: 0m, AddTaxPer: 0m,
            FreightType: null, DiscApp: null, PackApp: null,
            FreightPosition: null, InsurancePosition: null,
            Lines: lines ?? [Line()]);

    // ── Reads — delegate straight through ────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetAmendablePOList")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetAmendablePOListAsync_DelegatesToRepo()
    {
        var expected = new List<AmendablePoSummaryDto>();
        _repo.Setup(r => r.GetAmendablePOListAsync(DivCode, It.IsAny<DateTime>(), It.IsAny<DateTime>()))
             .ReturnsAsync(expected);

        var result = await _sut.GetAmendablePOListAsync(DivCode, DateTime.Today, DateTime.Today);

        result.Should().BeSameAs(expected);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetPOForAmend")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetPOForAmendAsync_DelegatesToRepo()
    {
        var expected = new PoAmendmentHeaderDto { PoNo = PoNo };
        _repo.Setup(r => r.GetPOForAmendAsync(DivCode, PoNo, PoDate, PoGroup))
             .ReturnsAsync(expected);

        var result = await _sut.GetPOForAmendAsync(DivCode, PoNo, PoDate, PoGroup);

        result.Should().BeSameAs(expected);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "GetAmendmentList")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task GetAmendmentListAsync_DelegatesToRepo()
    {
        var expected = new List<AmendmentSummaryDto>();
        _repo.Setup(r => r.GetAmendmentListAsync(DivCode, It.IsAny<DateTime>(), It.IsAny<DateTime>()))
             .ReturnsAsync(expected);

        var result = await _sut.GetAmendmentListAsync(DivCode, DateTime.Today, DateTime.Today);

        result.Should().BeSameAs(expected);
    }

    // ── SaveAmendmentAsync — happy path ──────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "AmendOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task SaveAmendmentAsync_ValidRequest_ReturnsAllocatedAmendNo()
    {
        _repo.Setup(r => r.SaveAmendmentAsync(
                It.IsAny<AmendmentSaveRequestDto>(), DivCode, TransDate, UserId, null, null))
             .ReturnsAsync(7);

        var result = await _sut.SaveAmendmentAsync(Request(), DivCode, TransDate, UserId, null, null);

        result.AmendNo.Should().Be(7);
        result.Message.Should().Contain("Amendment No: 7");
        _repo.Verify(r => r.SaveAmendmentAsync(
            It.IsAny<AmendmentSaveRequestDto>(), DivCode, TransDate, UserId, null, null), Times.Once);
    }

    // ── SaveAmendmentAsync — FN §3 rejections (repo must never be called) ─────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "AmendOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Validation")]
    public async Task SaveAmendmentAsync_NoLines_Throws_AndDoesNotHitRepo()
    {
        var act = async () => await _sut.SaveAmendmentAsync(
            Request(lines: []), DivCode, TransDate, UserId, null, null);

        // §3.1 — VB6 saved zero-change amendments; SPINRISE blocks them.
        await act.Should().ThrowAsync<InvalidOperationException>()
                 .WithMessage("*at least one item*");

        _repo.Verify(r => r.SaveAmendmentAsync(
            It.IsAny<AmendmentSaveRequestDto>(), It.IsAny<string>(), It.IsAny<DateTime>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [Trait("Module", "M01")]
    [Trait("Operation", "AmendOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Validation")]
    public async Task SaveAmendmentAsync_BlankCarrier_Throws(string carrier)
    {
        var act = async () => await _sut.SaveAmendmentAsync(
            Request(carrier: carrier), DivCode, TransDate, UserId, null, null);

        // §3.2
        await act.Should().ThrowAsync<InvalidOperationException>()
                 .WithMessage("Carrier cannot be empty.");

        _repo.Verify(r => r.SaveAmendmentAsync(
            It.IsAny<AmendmentSaveRequestDto>(), It.IsAny<string>(), It.IsAny<DateTime>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [Trait("Module", "M01")]
    [Trait("Operation", "AmendOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Validation")]
    public async Task SaveAmendmentAsync_BlankOrderType_Throws(string poGroup)
    {
        var act = async () => await _sut.SaveAmendmentAsync(
            Request(poGroup: poGroup), DivCode, TransDate, UserId, null, null);

        // §3.3
        await act.Should().ThrowAsync<InvalidOperationException>()
                 .WithMessage("Order Type cannot be empty.");

        _repo.Verify(r => r.SaveAmendmentAsync(
            It.IsAny<AmendmentSaveRequestDto>(), It.IsAny<string>(), It.IsAny<DateTime>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [Trait("Module", "M01")]
    [Trait("Operation", "AmendOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Validation")]
    public async Task SaveAmendmentAsync_BlankSupplier_Throws(string supplier)
    {
        // Supplier became amendable on the 13-Jul ruling, so it is now a mandatory
        // field (existence against FA_SLMAS is re-checked in the SP).
        var act = async () => await _sut.SaveAmendmentAsync(
            Request(supplier: supplier), DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
                 .WithMessage("Supplier cannot be empty.");

        _repo.Verify(r => r.SaveAmendmentAsync(
            It.IsAny<AmendmentSaveRequestDto>(), It.IsAny<string>(), It.IsAny<DateTime>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    // ── Deletion ─────────────────────────────────────────────────────────────

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "DeleteOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task DeleteOrderAsync_ValidRequest_DelegatesToRepo()
    {
        var request = new DeleteOrderRequestDto(PoNo, PoDate, PoGroup);

        await _sut.DeleteOrderAsync(request, DivCode, TransDate, UserId, null, null);

        _repo.Verify(r => r.DeleteOrderAsync(request, DivCode, TransDate, UserId, null, null), Times.Once);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "DeleteOrder")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Validation")]
    public async Task DeleteOrderAsync_BlankOrderType_Throws()
    {
        var request = new DeleteOrderRequestDto(PoNo, PoDate, "  ");

        var act = async () => await _sut.DeleteOrderAsync(request, DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
                 .WithMessage("Order Type cannot be empty.");

        _repo.Verify(r => r.DeleteOrderAsync(
            It.IsAny<DeleteOrderRequestDto>(), It.IsAny<string>(), It.IsAny<DateTime>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "DeleteLines")]
    [Trait("Layer", "Service")]
    [Trait("Type", "HappyPath")]
    public async Task DeleteLinesAsync_ValidRequest_DelegatesToRepo()
    {
        var request = new DeleteLinesRequestDto(PoNo, PoDate, PoGroup,
            [new DeleteLineKeyDto(1, "1334001")]);

        await _sut.DeleteLinesAsync(request, DivCode, TransDate, UserId, null, null);

        _repo.Verify(r => r.DeleteLinesAsync(request, DivCode, TransDate, UserId, null, null), Times.Once);
    }

    [Fact]
    [Trait("Module", "M01")]
    [Trait("Operation", "DeleteLines")]
    [Trait("Layer", "Service")]
    [Trait("Type", "Validation")]
    public async Task DeleteLinesAsync_NoLines_Throws()
    {
        var request = new DeleteLinesRequestDto(PoNo, PoDate, PoGroup, []);

        var act = async () => await _sut.DeleteLinesAsync(request, DivCode, TransDate, UserId, null, null);

        await act.Should().ThrowAsync<InvalidOperationException>()
                 .WithMessage("*at least one line*");

        _repo.Verify(r => r.DeleteLinesAsync(
            It.IsAny<DeleteLinesRequestDto>(), It.IsAny<string>(), It.IsAny<DateTime>(),
            It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
    }
}
