namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

/// <summary>
/// Flat Dapper row for the legacy <c>KSP_PR_PO_gst</c> print SP. The SP returns a single
/// result set with header columns repeated on every line row; the repository groups by
/// PO and lifts the header from the first row. Property names match the SP's column
/// aliases (Dapper maps case-insensitively; unmapped SP columns are ignored).
/// Only the columns the report actually renders are declared here.
/// </summary>
public class PoPrintGstRow
{
    // ── PO header (repeated per row) ──────────────────────────────────────────
    public string    DIVCODE   { get; set; } = "";
    public decimal   PORDNO    { get; set; }
    public DateTime  PORDDT    { get; set; }
    public string    CurrCode  { get; set; } = "";
    public string    refno     { get; set; } = "";
    public DateTime? RefDate   { get; set; }
    public decimal   roff      { get; set; }
    public string    NOTE      { get; set; } = "";   // purpose
    public string    PAYTERMS  { get; set; } = "";   // computed (DIRECT_INS when PAYMENT='D')
    public DateTime? duedate   { get; set; }          // delivery date
    public string    CARNAME   { get; set; } = "";   // transport
    public string    hremarks  { get; set; } = "";   // header remarks
    public string    createdby { get; set; } = "";
    public DateTime? createddt { get; set; }

    // ── Approval (PO_ParaPOApproval) — final/authorised signatory ──────────────
    // FinalAppSign already has the SP's level + SELVA rule applied; holds binary image data.
    public string  FinalAppName { get; set; } = "";
    public byte[]? FinalAppSign { get; set; }

    // ── Division letterhead ───────────────────────────────────────────────────
    public string  DIV_PRINTNAME { get; set; } = "";
    public string  DIV_UNITNAME  { get; set; } = "";
    public byte[]? DIV_LOGO      { get; set; }
    public string  DADD1         { get; set; } = "";
    public string  DADD2         { get; set; } = "";
    public string  DADD3         { get; set; } = "";
    public string  DCITY         { get; set; } = "";
    public string  DPINCODE      { get; set; } = "";
    public string  DSTATENAME    { get; set; } = "";
    public string  DPHONE1       { get; set; } = "";
    public string  DEMAIL        { get; set; } = "";
    public string  div_gstinno   { get; set; } = "";
    public string  DPAN          { get; set; } = "";
    public string  DWEBADDR      { get; set; } = "";
    public string  div_GSTstateCode { get; set; } = "";

    // ── Supplier ("To") ───────────────────────────────────────────────────────
    public string slname  { get; set; } = "";
    public string add1    { get; set; } = "";
    public string add2    { get; set; } = "";
    public string add3    { get; set; } = "";
    public string city    { get; set; } = "";
    public string pin     { get; set; } = "";
    public string state   { get; set; } = "";
    public string country { get; set; } = "";
    public string sup_gstinno      { get; set; } = "";
    public string sup_gststatecode { get; set; } = "";
    public string sup_phone1       { get; set; } = "";
    public string sup_email        { get; set; } = "";

    // ── Header GST + discount totals ──────────────────────────────────────────
    public decimal header_cgstamt { get; set; }
    public decimal header_sgstamt { get; set; }
    public decimal header_igstamt { get; set; }
    public decimal Head_discountAmt { get; set; }

    // ── Line ──────────────────────────────────────────────────────────────────
    public string  ITEMCODE  { get; set; } = "";
    public string  ITEMNAME  { get; set; } = "";
    public string  ITEMSPEC1 { get; set; } = "";
    public string  ITEMSPEC2 { get; set; } = "";
    public string  ITEMSPEC3 { get; set; } = "";
    public string  UOM       { get; set; } = "";
    public string  itemHsn   { get; set; } = "";
    public decimal ORDQTY    { get; set; }
    public decimal RATE      { get; set; }
    public decimal LORDVAL   { get; set; }   // line value
    public decimal DISPER    { get; set; }   // line disc %
    public decimal disamt    { get; set; }   // line disc amt
    public decimal cgstper   { get; set; }
    public decimal sgstper   { get; set; }
    public decimal igstper   { get; set; }
    public decimal cgstamt   { get; set; }
    public decimal sgstamt   { get; set; }
    public decimal igstamt   { get; set; }
    public decimal tcs_per   { get; set; }
    public decimal tcs_amt   { get; set; }
    public decimal FREIGHT   { get; set; }   // PO_ORDL.FRGT1AMT
    public decimal INS_AMT   { get; set; }
    public decimal PACKAMT   { get; set; }
    public decimal OTHCHGS   { get; set; }
}
