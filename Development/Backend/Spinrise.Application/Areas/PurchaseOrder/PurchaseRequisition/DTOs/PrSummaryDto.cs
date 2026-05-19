namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrSummaryDto(
    string   DivCode,
    decimal  PrNo,
    DateOnly PrDate,
    string   DepCode,
    string   DepName,
    string   ReqName,
    string   ReqEmpName,
    string   IType,
    string   IDesc,
    string   PoGrp,
    string   AppFlg,
    string   PrStatus,
    int      TotalLines
);
