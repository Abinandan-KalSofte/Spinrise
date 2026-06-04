namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;

public record PrAmendmentSummaryDto(
    string  DivCode,
    decimal PrNo,
    string  PrDate,
    int     AmendNo,
    string  AmendDate,
    string  AmendmentReason,
    string  RefNo,
    string  DepCode,
    string  DepName,
    string  ReqName,
    string  CreatedBy,
    int     TotalLines
);
