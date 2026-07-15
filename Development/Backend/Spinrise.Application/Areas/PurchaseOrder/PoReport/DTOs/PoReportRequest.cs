namespace Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

public class PoReportRequest
{
    public string   DivCode      { get; set; } = "";
    public DateTime FromDate     { get; set; }
    public DateTime ToDate       { get; set; }
    public string   ReportType   { get; set; } = "";
    public string?  DepCode      { get; set; }
    public bool     AllSuppliers { get; set; } = true;
    public string[] SupplierCodes { get; set; } = [];
    public bool     AllItems     { get; set; } = true;
    public string[] ItemCodes    { get; set; } = [];
    // Item-Wise only: VB6's @Opt confirm-status filter — 'A'=all, 'Y'=confirmed, 'N'=not confirmed.
    public string   ConfirmStatus { get; set; } = "A";
}
