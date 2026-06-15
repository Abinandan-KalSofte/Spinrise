namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class PoParametersDto
{
    public string PoFirstLevelApp  { get; set; } = "";
    public string PoPrintApp       { get; set; } = "";
    public string PoConf           { get; set; } = "";
    public string BudGrp           { get; set; } = "";
    public string BudgetQty        { get; set; } = "";
    public string BudgetControl    { get; set; } = "";
    public string CurrCode         { get; set; } = "";
    public string BackDate         { get; set; } = "";
    public string PdfExportFlag    { get; set; } = "";
}
