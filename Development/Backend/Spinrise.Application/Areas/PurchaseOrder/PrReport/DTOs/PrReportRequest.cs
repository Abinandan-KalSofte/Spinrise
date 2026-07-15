namespace Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

public class PrReportRequest
{
    public string   DivCode    { get; set; } = "";
    public DateTime FromDate   { get; set; }
    public DateTime ToDate     { get; set; }
    public string   ReportType { get; set; } = "";
    public string?  DepCode    { get; set; }
    // Itemwise filter
    public bool     AllItems   { get; set; } = true;
    public string[] ItemCodes  { get; set; } = [];  // empty = all items
}
