namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;

// One open PO line eligible for foreclosure — wire contract POForeclosureLineDto
// (poForeclosureTypes.ts). Sourced from ksp_PO_GetOpenLinesForForeclose.
// prNo/prDate are hidden in the UI but participate in the PO_PRL backflush key.
public record PoForeclosureLineDto(
    string  Group,
    decimal PoNo,
    string  PoDate,
    string  SlCode,
    string  SupplierName,
    int     SNo,
    string  ItemCode,
    string  ItemName,
    decimal BalanceQty,
    string  PrNo,
    string  PrDate
);
