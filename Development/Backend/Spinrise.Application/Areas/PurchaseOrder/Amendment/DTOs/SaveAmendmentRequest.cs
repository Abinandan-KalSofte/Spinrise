using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;

public class SaveAmendmentRequest
{
    [Required] public string AmendDate        { get; set; } = string.Empty;
    [Required] public string PrNo             { get; set; } = string.Empty;
    [Required] public string PrDate           { get; set; } = string.Empty;
    [Required] public string AmendmentReason  { get; set; } = string.Empty;
    public string? RefNo                      { get; set; }
    public string? IType                      { get; set; }   // editable PR Type; null = inherit from PR
    public string? RowVersion                 { get; set; }   // base64; used for PATH A line-level concurrency
    [Required] public string PDate            { get; set; } = string.Empty;   // processing date; enforces BR-AMD-01
    public List<SaveAmendmentLineRequest> Lines { get; set; } = [];
}

public class SaveAmendmentLineRequest
{
    [Required] public decimal  PrSno             { get; set; }
    [Required] public string   ItemCode          { get; set; } = string.Empty;
    public string?  MacNo                        { get; set; }
    [Required] public decimal  QtyInd            { get; set; }
    public string?  ReqdDate                     { get; set; }
    [Required] public decimal  Rate              { get; set; }
    [Required] public string   RateSource        { get; set; } = "ORIGINAL";
    public string?  RateJustification            { get; set; }
    public decimal  CurStock                     { get; set; }
    public decimal? CcCode                       { get; set; }
    public string?  CatCode                      { get; set; }
    public string?  BgrpCode                     { get; set; }
    public string?  Place                        { get; set; }
    public decimal  AppCost                      { get; set; }
    public string?  Remarks                      { get; set; }
    public string?  RowVersion                   { get; set; }   // base64; required for PATH A (existing lines)
}
