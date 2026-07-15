namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;

// One open PO line eligible for cancellation — wire contract POCancellationLineDto
// (poCancellationTypes.ts). Sourced from ksp_PO_GetPOLinesForCancel.
// Balance is computed client- and server-side as OrderQty - ReceivedQty - CANQTY;
// ReceivedQty here is the raw RCVDQTY per FN §2 column map.
public record PoCancellationLineDto(
    string  SlCode,
    string  ItemCode,
    int     SNo,
    string  ItemName,
    string  Uom,
    decimal OrderQty,
    decimal ReceivedQty,
    decimal Rate,
    decimal Value
);
