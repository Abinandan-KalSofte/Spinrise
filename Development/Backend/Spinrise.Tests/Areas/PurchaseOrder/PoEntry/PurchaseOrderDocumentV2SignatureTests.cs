using FluentAssertions;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Xunit;

namespace Spinrise.Tests.Areas.PurchaseOrder.PoEntry;

/// <summary>
/// Locks in the two IST print corrections to the JAT PO print signature block
/// (PurchaseOrderDocumentV2.ComposeSignature):
///   IST-PRINT-01 — "Prepared by" renders as a BLANK box: no creator name, no created date.
///   IST-PRINT-02 — the "Checked by" column renders NO signature image (name/desig/date stay).
///
/// These render the real document to a PDF rather than asserting on intermediate state, so a
/// regression in the signature block is caught even if the surrounding layout is refactored.
/// </summary>
public class PurchaseOrderDocumentV2SignatureTests
{
    static PurchaseOrderDocumentV2SignatureTests()
        => QuestPDF.Settings.License = LicenseType.Community;

    // Smallest valid 1x1 PNG. ExtractImageBytes accepts a raw PNG at offset 0.
    private static byte[] Png() => Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=");

    // NOTE: an earlier version of these tests scanned the raw PDF for "/Image". That is a false
    // positive — QuestPDF emits that token even when no image is drawn, which made the control
    // test pass vacuously. Output SIZE is the reliable discriminator: embedding a signature
    // bitmap grows the PDF, so "same size as the no-signature render" == "image not embedded".
    // The RenderedSignature_ChangesOutputSize test below pins that assumption down.

    private static PoPrintDto Dto(
        IReadOnlyList<PoApprovalDto> approvals,
        string createdBy = "ALICE CREATOR",
        string createdDt = "01/07/2026") => new(
            DivLogo: null,                       // keep null: makes ContainsImage() unambiguous
            DivName: "JAT", DivPrintName: "JAT TECHNO", DivUnitName: "UNIT-1",
            DivAddress1: "A1", DivAddress2: "A2", DivAddress3: "A3", DivPinCode: "600001",
            DivPhone: "0", DivEmail: "e@x.com", DivGstin: "G", DivPan: "P", DivWeb: "w",
            DivCode: "01", PoNo: 1234m, PoDate: new DateOnly(2026, 7, 1),
            SlCode: "S1", SlName: "SUPPLIER", SlAddress: "ADDR", SlGstin: "SG",
            SlPhone: "1", SlEmail: "s@x.com",
            OrderType: "CA", Carrier: "CAR", Currency: "INR", CurrRate: 1m, CreditDays: 30,
            PayMode: "Direct", Remarks: "",
            CgstPer: 9m, SgstPer: 9m, IgstPer: 0m, TcsPer: 0m, DiscPer: 0m,
            FreightAmt: 0m, RoundOff: 0m, OrderValue: 1000m,
            FirstLevelApp: "Y", Conflg: "Y",
            CreatedBy: createdBy, CreatedDt: createdDt,
            RefNo: "R1", RefDate: "01/07/2026", DeliveryDate: "10/07/2026",
            Purpose: "P", PayTerms: "T", InsAmt: 0m, PackAmt: 0m,
            DivStateCode: "33", SlStateCode: "33",
            Lines: new List<PoPrintLineDto>
            {
                new(LineNo: 1, ItemCode: "I1", ItemName: "ITEM ONE", Uom: "NOS", HsnCode: "1001",
                    PrNo: 1m, PrSno: 1m, Qty: 1m, Rate: 1000m, Value: 1000m,
                    TaxCode: "T", TaxPer: 18m, TaxAmt: 180m,
                    CgstPer: 9m, CgstAmt: 90m, SgstPer: 9m, SgstAmt: 90m,
                    IgstPer: 0m, IgstAmt: 0m, TcsPer: 0m, TcsAmt: 0m,
                    LineDis: 0m, LineDisAmt: 0m)
            },
            Approvals: approvals,
            PrintConfig: new PoPrintConfig());   // JAT path: approval block ON

    private static PoApprovalDto Checked(byte[]? sign) =>
        new("Checked by", "BOB CHECKER", "MANAGER", sign, "05/07/2026");

    private static PoApprovalDto Authorised(byte[]? sign) =>
        new("Authorised Signatory", "CAROL BOSS", "GM", sign, "06/07/2026");

    // ── IST-PRINT-02 ────────────────────────────────────────────────────────────────────

    [Fact]
    public void RenderedSignature_ChangesOutputSize()
    {
        // CONTROL — this is what makes every "same size" assertion below meaningful. A signature
        // that IS rendered must visibly grow the PDF; if this ever fails, size has stopped being
        // a valid discriminator and the suppression tests are no longer proving anything.
        var withSign = PurchaseOrderDocumentV2.Generate(Dto(new[] { Authorised(Png()) }));
        var noSign   = PurchaseOrderDocumentV2.Generate(Dto(new[] { Authorised(null) }));

        withSign.Length.Should().NotBe(noSign.Length,
            "a rendered signature image must embed bitmap data in the PDF");
    }

    [Fact]
    public void CheckedBy_SignatureImage_IsNotRendered()
    {
        // Supplying a Checked-by signature vs not supplying one must produce the SAME output —
        // i.e. the image is dropped entirely, not merely shrunk or repositioned.
        var withSign = PurchaseOrderDocumentV2.Generate(Dto(new[] { Checked(Png()) }));
        var noSign   = PurchaseOrderDocumentV2.Generate(Dto(new[] { Checked(null) }));

        withSign.Length.Should().Be(noSign.Length,
            "IST-PRINT-02: the 'Checked by' signature image must not be rendered");
    }

    [Fact]
    public void OtherApprovalLevels_StillRenderTheirSignatureImage()
    {
        // Only "Checked by" is suppressed: an Authorised Signatory signature must still embed,
        // so its render must differ from the Checked-by (suppressed) render of the same image.
        var authorised = PurchaseOrderDocumentV2.Generate(Dto(new[] { Authorised(Png()) }));
        var checkedBy  = PurchaseOrderDocumentV2.Generate(Dto(new[] { Checked(Png()) }));

        authorised.Length.Should().BeGreaterThan(checkedBy.Length,
            "only 'Checked by' is suppressed — other approval levels keep their signature");
    }

    [Fact]
    public void CheckedBy_IsSuppressed_EvenWhenAnotherLevelHasASignature()
    {
        var both = PurchaseOrderDocumentV2.Generate(Dto(new[] { Checked(Png()), Authorised(Png()) }));
        var only = PurchaseOrderDocumentV2.Generate(Dto(new[] { Checked(null), Authorised(Png()) }));

        both.Length.Should().Be(only.Length,
            "the Checked-by image is dropped regardless of the other columns");
    }

    // ── IST-PRINT-01 ────────────────────────────────────────────────────────────────────

    [Fact]
    public void PreparedBy_DoesNotRenderCreatorNameOrDate()
    {
        // If the creator name/date were still drawn, changing them would change the page
        // content and therefore the output size. Identical output => neither is rendered.
        var populated = PurchaseOrderDocumentV2.Generate(
            Dto(new[] { Checked(null) }, createdBy: "ALICE CREATOR", createdDt: "01/07/2026"));
        var blank = PurchaseOrderDocumentV2.Generate(
            Dto(new[] { Checked(null) }, createdBy: "", createdDt: ""));

        populated.Length.Should().Be(blank.Length,
            "IST-PRINT-01: 'Prepared by' is a blank box — creator name and date are not printed");
    }

    [Fact]
    public void PreparedBy_LongCreatorName_StillRendersNothing()
    {
        // A long name would reflow/wrap the column if it were being drawn.
        var longName = PurchaseOrderDocumentV2.Generate(
            Dto(new[] { Checked(null) },
                createdBy: new string('X', 200), createdDt: "31/12/2026"));
        var blank = PurchaseOrderDocumentV2.Generate(
            Dto(new[] { Checked(null) }, createdBy: "", createdDt: ""));

        longName.Length.Should().Be(blank.Length,
            "no length of creator name may leak onto the print");
    }
}
