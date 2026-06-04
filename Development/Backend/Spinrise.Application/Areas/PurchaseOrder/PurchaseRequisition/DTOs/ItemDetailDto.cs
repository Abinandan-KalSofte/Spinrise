namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record ItemDetailDto(
    string    ItemCode,
    string    ItemName,
    string    Uom,
    decimal   MinLevel,
    decimal   MaxLevel,
    byte[]?   ItemImage,
    string?   ImagePath,
    decimal   CurrentStock,
    decimal?  LpoRate,
    DateOnly? LpoDate,
    decimal?  AvgRate
);
