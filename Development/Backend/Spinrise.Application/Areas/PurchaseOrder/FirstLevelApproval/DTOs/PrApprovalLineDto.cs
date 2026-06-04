namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record PrApprovalLineDto(
    decimal   PrSno,
    string    ItemCode,
    string    ItemName,
    string    Uom,
    string?   Machine,
    decimal   CurStock,
    decimal   QtyInd,
    decimal   QtyReqd,
    decimal   FirstAppQty,
    decimal   SecondAppQty,
    decimal   ThirdAppQty,
    decimal   QtyOrd,
    decimal   QtyRec,
    decimal   Rate,
    decimal   Value,
    DateTime? ReqdDate,
    string?   FirstApp,
    string?   PrStatus,
    string?   Place,
    decimal   AppCost,
    string?   Remarks,
    string?   BgrpCode,
    string?   MacNo
);
