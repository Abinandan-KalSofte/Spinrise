namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrLineDto(
    decimal  PrSno,
    string   ItemCode,
    string   ItemName,
    string   Uom,
    string?  MacNo,
    decimal  QtyInd,
    DateOnly? ReqdDate,
    decimal  Rate,
    decimal  LpoRate,
    DateOnly? LpoDate,
    string?  LpoFrom,
    string   RateSource,
    string?  RateJustification,
    decimal  CurStock,
    decimal? CcCode,
    string?  CatCode,
    string?  BgrpCode,
    decimal  AppCost,
    string?  Remarks,
    string   Sample,
    string   LineStatus
);
