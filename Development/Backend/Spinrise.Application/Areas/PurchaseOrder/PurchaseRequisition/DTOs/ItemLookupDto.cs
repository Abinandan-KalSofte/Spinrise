namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record ItemLookupDto(
    string   ItemCode,
    string   ItemName,
    string   Uom,
    decimal  MinLevel,
    decimal  MaxLevel,
    byte[]?  ItemImage,
    decimal? LpoRate,
    DateOnly? LpoDate
);
