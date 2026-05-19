namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record ItemDetailDto(
    string   ItemCode,
    string   ItemName,
    string   Uom,
    decimal  MinLevel,
    byte[]?  ItemImage,
    decimal  CurrentStock,
    decimal? LpoRate,
    DateOnly? LpoDate,
    decimal? AvgRate
);
