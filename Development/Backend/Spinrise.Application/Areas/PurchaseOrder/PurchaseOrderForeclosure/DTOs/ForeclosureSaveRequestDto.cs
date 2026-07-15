using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;

// Save payload — wire contract ForeclosureSaveRequest { lines[] } (poForeclosureTypes.ts).
// Each key carries the full PO line identity. poDate + group were added to the frozen
// contract by STEP 7 so the SP can match DIVCODE+POGRP+PORDNO+PORDDT+PORDSNO+ITEMCODE
// (a poNo-only server lookup risks matching the wrong PORDDT/POGRP across FYs).
public record ForeclosureSaveRequestDto(
    [Required][MinLength(1)] List<ForeclosureLineKeyDto> Lines
);

public record ForeclosureLineKeyDto(
    [Required] decimal PoNo,
    [Required] string  PoDate,
               string? Group,
    [Required] int     SNo,
    [Required] string  ItemCode,
               string? PrNo,
               string? PrDate
);
