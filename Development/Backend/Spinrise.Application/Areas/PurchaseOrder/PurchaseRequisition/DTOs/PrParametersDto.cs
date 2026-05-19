namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public class PrParametersDto
{
    public string ManualIndNo     { get; set; } = "";
    public string BudgetQty       { get; set; } = "";
    public string PendingOrderPara{ get; set; } = "";
    public string Penpodetails    { get; set; } = "";
    public string InditemGrp      { get; set; } = "";
    public int    PurTypeFlg      { get; set; }
    public string EmpMasterComm   { get; set; } = "";
    public string PdfExportFlag   { get; set; } = "";
    public string PrSmsSendFlg    { get; set; } = "";
    public string PrSmsStatusFlg  { get; set; } = "";
    public string PrILevel        { get; set; } = "";
    public string PrFLevel        { get; set; } = "";
    public int?   DefaultPrType   { get; set; }
    public string MultiSelectLookup { get; set; } = "N";
}
