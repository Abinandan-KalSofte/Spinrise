namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrForeclosureLineDto(
    decimal PrNo,
    string  PRDate,
    string  Department,
    string  DepCode,
    int     PrSno,
    string  ItemCode,
    string  ItemName,
    string  UOM,
    decimal PrQty,
    decimal OrdQty,
    decimal Balance,
    string  SccCode,
    string  SccName,
    string  PrevStatus
);
