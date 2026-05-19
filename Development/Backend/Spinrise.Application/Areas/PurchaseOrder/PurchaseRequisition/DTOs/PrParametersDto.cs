namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrParametersDto(
    string ManualIndNo,
    string BudgetQty,
    string PendingOrderPara,
    string Penpodetails,
    string InditemGrp,
    int    PurTypeFlg,
    string EmpMasterComm,
    string PdfExportFlag,
    string PrSmsSendFlg,
    string PrSmsStatusFlg,
    string PrILevel,
    string PrFLevel,
    string? DefaultPrType,
    string MultiSelectLookup
);
