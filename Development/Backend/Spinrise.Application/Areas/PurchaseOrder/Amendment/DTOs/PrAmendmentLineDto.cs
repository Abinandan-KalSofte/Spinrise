namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;

// Class (not record) so Dapper can use parameterless constructor + property binding.
public class PrAmendmentLineDto
{
    public decimal  PrSno             { get; set; }
    public string   ItemCode          { get; set; } = string.Empty;
    public string   ItemName          { get; set; } = string.Empty;
    public string   Uom               { get; set; } = string.Empty;
    public decimal  MinLevel          { get; set; }
    public decimal  MaxLevel          { get; set; }
    public string   MacNo             { get; set; } = string.Empty;
    public string   MacDesc           { get; set; } = string.Empty;
    public decimal  QtyInd            { get; set; }
    public string?  ReqdDate          { get; set; }   // DD/MM/YYYY string from SP
    public decimal  Rate              { get; set; }
    public string   RateSource        { get; set; } = string.Empty;
    public string   RateJustification { get; set; } = string.Empty;
    public decimal  CurStock          { get; set; }
    public decimal  CcCode            { get; set; }
    public string   CcName            { get; set; } = string.Empty;
    public string   CatCode           { get; set; } = string.Empty;
    public string   BgrpCode          { get; set; } = string.Empty;
    public string   Place             { get; set; } = string.Empty;
    public decimal  AppCost           { get; set; }
    public string   Remarks           { get; set; } = string.Empty;
    public decimal  QtyApproved       { get; set; }
    public decimal  QtyOrdered        { get; set; }
    public decimal  QtyReceived       { get; set; }
    public string   LineStatus        { get; set; } = string.Empty;
    public byte[]?  RowVersion        { get; set; }   // PO_PRL row_version; serialised as base64 by System.Text.Json
}
