using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrForeclosureLineKeyDto(
    [Required] decimal PrNo,
    [Required] string  PRDate,
    [Required] int     PrSno,
    [Required] string  ItemCode,
    [Required] string  DepCode,
               decimal Balance
);
