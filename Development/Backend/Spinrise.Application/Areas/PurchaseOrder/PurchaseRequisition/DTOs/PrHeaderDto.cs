namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrHeaderDto(
    string   DivCode,
    decimal  PrNo,
    DateOnly PrDate,
    string   DepCode,
    string   DepName,
    string   ReqName,
    string   ReqEmpName,
    string   Section,
    string   IType,
    string   IDesc,
    string   RefNo,
    string   PoGrp,
    string   AppFlg,
    string?  CancelFlag,
    string?  CancelReason,
    decimal  AmendNo,
    string   PrStatus,
    string   CreatedBy,
    string   CreatedDt,
    string   UserId,
    IReadOnlyList<PrLineDto> Lines
);
