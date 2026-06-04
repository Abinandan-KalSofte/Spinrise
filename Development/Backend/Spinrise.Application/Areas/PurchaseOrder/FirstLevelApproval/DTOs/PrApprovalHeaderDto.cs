namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record PrApprovalHeaderDto(
    string    DivCode,
    decimal   PrNo,
    DateTime  PrDate,
    string    DepCode,
    string    DepName,
    string?   RefNo,
    string?   Section,
    string?   SubCost,
    string?   SccName,
    string?   App1,
    string?   App2,
    string?   App3,
    string?   AppFlg,
    DateTime? App1Date,
    string?   ReqName
);
