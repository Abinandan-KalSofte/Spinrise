namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

// PO_ORDH shape — one row per PO in the approval grid. Field names match
// Development/spinrise-web/src/features/po/api/createPoApprovalApi.ts's LineDto
// exactly (PascalCase here serializes camelCase on the wire).
public record PoApprovalLineDto(
    string  DivCode,
    string  DivName,       // 10-Jul-2026: pp_divmas.DIVNAME, all 3 levels
    decimal PoNo,
    string  PoDate,        // yyyy-MM-dd, matches SP's CONVERT(...,120) output verbatim
    string  OrderType,
    string  SupplierCode,
    string  SupplierName,
    string  SupplierPlace,
    string  Currency,
    string  PaymentTerm,
    decimal NetTotal,
    int     AmendNo,
    string  FirstLevelApp,
    string  SecondLevelApp,
    string  Conflg,
    IReadOnlyList<PoApprovalLineItemDto>? Lines,       // First/Second only
    int?     LineCount,                                 // all 3 levels now (10-Jul-2026: First/Second computed from Lines.Count in the repository, Final from the SP's own aggregate — BR-06)
    decimal? PoValue,                                   // Final only (BR-06)
    PoApprovalProvenanceDto? FirstLevel,                // Second/Final only
    PoApprovalProvenanceDto? SecondLevel);              // Final only
