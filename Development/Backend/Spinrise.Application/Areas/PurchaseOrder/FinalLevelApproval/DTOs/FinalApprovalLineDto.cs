namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public record FinalApprovalLineDto(
    string  DivCode,
    decimal PrNo,
    string  PrDate,          // DD/MM/YYYY
    decimal PrSno,
    string  DbName,
    string  Department,
    string  ItemCode,
    string  ItemName,
    string  Uom,
    decimal CurrentStock,    // 3dp
    decimal QtyRequired,     // 3dp
    decimal QtyApproved,     // 3dp
    int     Disposition,     // 1-5
    decimal Rate,            // 4dp — PR line rate (PO_PRL.RATE)
    decimal LpoRate,         // 4dp
    string? LpoDate,         // DD/MM/YYYY or null
    decimal? ApproxCost,     // 2dp or null
    string  ApprovalStatus,  // "first" | "second" | "final"
    string  RowVersion       // hex string from row_version timestamp
);
