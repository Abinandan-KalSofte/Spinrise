namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// One PO line loaded for amendment (ksp_PO_GetPOForAmend, second result set).
// Mirrors PoEntry.PoLineDto field-for-field so Mariyaiya's SP aliases the same
// PO_ORDL columns the Transfer/Entry SPs already expose. Class with named init
// props → Dapper maps by column name (resilient to SELECT order), deliberately
// NOT a positional record (the ~40-col width is exactly where positional binding
// silently mis-maps — see T-0156 Foreclosure type mismatch).
//
// FN §2 groups: identity (1, locked) · quotation (2) · PR link + PRSNO (3) ·
// rate/qty/value (4) · disc/packing/freight/insurance/others %+amt+pos (5) ·
// HSN+CGST/SGST/IGST+TCS (6) · landing cost/cenvat (7) · rcvd/can qty (8) ·
// amendment reason (9) · remarks/memo/requester (10). Delivery schedule (11) is a
// separate child result set (PoAmendmentDeliverySlotDto).
public class PoAmendmentLineDto
{
    // 1 — identity (locked in UI)
    public int     SNo         { get; init; }   // PORDSNO
    public string  ItemCode    { get; init; } = "";
    public string  ItemName    { get; init; } = "";
    public string  Uom         { get; init; } = "";
    // 2 — quotation (read-only)
    public string  QuotNo      { get; init; } = "";
    public string  QuotDate    { get; init; } = "";
    // 3 — PR link (read-only; PrSno is the CD-NEW-01 backflush key)
    public decimal PrNo        { get; init; }
    public string  PrDate      { get; init; } = "";
    public decimal PrSno       { get; init; }
    // 4 — rate / qty / value (editable)
    public decimal Rate        { get; init; }
    public decimal Qty         { get; init; }   // ORDQTY
    public decimal Weight      { get; init; }   // Weight/Piece
    public decimal Value       { get; init; }   // ORDVAL (line)
    public decimal FRate       { get; init; }   // foreign-currency rate
    public decimal FValue      { get; init; }
    // 5 — discount / packing / freight / insurance / others (%+amt+position)
    public decimal DiscPer     { get; init; }
    public decimal DiscAmt     { get; init; }
    public decimal PackingPer  { get; init; }
    public decimal PackingAmt  { get; init; }
    public decimal FreightPer  { get; init; }   // FRGT1PER
    public decimal FreightAmt  { get; init; }   // FRGT1AMT
    public decimal InsurancePer { get; init; }
    public decimal InsuranceAmt { get; init; }
    public decimal OtherCharges { get; init; }  // OTHCHGS
    public decimal FcaFob      { get; init; }   // FCACharg
    public string  DiscApp     { get; init; } = "BEFORE";
    public string  PackApp     { get; init; } = "BEFORE";
    public string  FreightPos  { get; init; } = "BEFORE";
    public string  InsuranceDuty { get; init; } = "BEFORE";
    // 6 — HSN + GST + TCS
    public string  HsnCode     { get; init; } = "";
    public string  TaxCode     { get; init; } = "";
    public decimal TaxPer      { get; init; }
    public decimal TaxAmt      { get; init; }
    public string  CgstCode    { get; init; } = "";
    public decimal CgstPer     { get; init; }
    public decimal CgstAmt     { get; init; }
    public string  SgstCode    { get; init; } = "";
    public decimal SgstPer     { get; init; }
    public decimal SgstAmt     { get; init; }
    public string  IgstCode    { get; init; } = "";
    public decimal IgstPer     { get; init; }
    public decimal IgstAmt     { get; init; }
    public decimal TcsPer      { get; init; }
    public decimal TcsAmt      { get; init; }
    public string  AddTaxCode  { get; init; } = "";
    public decimal AddTaxPer   { get; init; }
    public decimal AddTaxAmt   { get; init; }
    // 7 — landing cost / cenvat (computed)
    public decimal LandingCost { get; init; }   // LANDCOST
    public decimal Cenvat      { get; init; }   // MODVAT
    // 8 — received / cancelled qty (read-only; feed the server floor guard)
    public decimal ReceivedQty { get; init; }   // RCVDQTY
    public decimal CancelQty   { get; init; }   // CANQTY
    // PR remaining balance (qtyreqd - qtyord). Feeds the client amend ceiling
    // (Gap #5): max new qty = Qty + PrBalance. Large sentinel when no PR link.
    public decimal PrBalance   { get; init; }
    // 9 — amendment reason (mandatory per changed line, FN §3.6)
    public string  AmendReason { get; init; } = "";
    // 10 — remarks / memo / requester
    public string  Remarks     { get; init; } = "";
    public string  ItemMemo    { get; init; } = "";
    public string  RequesterId { get; init; } = "";
    public string  RequesterName { get; init; } = "";
    public string  DepCode     { get; init; } = "";
}
