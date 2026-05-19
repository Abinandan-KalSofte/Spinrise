namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PreAddChecksDto(
    bool    ItemMasterExists,
    bool    DeptMasterExists,
    bool    DocParaExists,
    string  BackDateFlag,
    DateOnly? MaxPrDate
);
