namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

// Prior-level approval provenance (who/when) — Second Level shows firstLevel only,
// Final Level shows both firstLevel and secondLevel. Sourced from LogDet_PO.
public record PoApprovalProvenanceDto(string By, string On);
