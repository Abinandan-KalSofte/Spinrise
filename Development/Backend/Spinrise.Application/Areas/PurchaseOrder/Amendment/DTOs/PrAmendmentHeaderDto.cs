namespace Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;

public record PrAmendmentHeaderDto(
    string  DivCode,
    decimal PrNo,
    string  PrDate,
    int     AmendNo,
    string  AmendDate,
    string  AmendmentReason,
    string  RefNo,
    string  CreatedBy,
    string  CreatedDt,
    string  RowVersion,
    string  DepCode,
    string  DepName,
    string  ReqName,
    string  ReqEmpName,
    string  Section,
    string  IType,
    string  IDesc,
    string  AppFlg,
    string  CancelFlag,
    IReadOnlyList<PrAmendmentLineDto> Lines
);
