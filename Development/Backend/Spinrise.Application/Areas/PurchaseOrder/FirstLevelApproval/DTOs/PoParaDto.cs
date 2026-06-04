namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record PoParaDto(
    string   DivCode,
    string?  AppUserLevel1,
    string?  AppUserLevel2,
    string?  AppUserLevel3,
    string   AppUserLabel1,
    string   AppUserLabel2,
    string   AppUserLabel3,
    DateTime YFDate,
    DateTime YLDate
);
