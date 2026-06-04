namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public record ItemHistoryDto(
    string  PoNo,
    string  PoDate,   // DD/MM/YYYY
    decimal Qty,      // 3dp
    decimal Rate,     // 4dp
    decimal Amount    // 2dp
);
