using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrForeclosureSaveRequestDto(
    [Required][MinLength(1)] List<PrForeclosureLineKeyDto> Lines
);
