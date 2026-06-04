namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrForCancellationDetailDto(
    PrForCancellationHeaderDto          Header,
    IEnumerable<PrForCancellationLineDto> Lines
);
