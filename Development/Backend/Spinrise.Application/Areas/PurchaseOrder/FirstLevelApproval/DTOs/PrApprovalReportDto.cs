namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record PrApprovalReportDto(
    // Division letterhead
    byte[]?  DivLogo,
    string   DivName,
    string   DivPrintName,
    string   DivUnitName,
    string   DivAddress1,
    string   DivAddress2,
    string   DivAddress3,
    string   DivPinCode,
    string   DivState,
    string   DivPhone,
    string   DivEmail,
    // PR header
    string    DivCode,
    decimal   PrNo,
    DateTime  PrDate,
    string    DepCode,
    string    DepName,
    string?   RefNo,
    string?   Section,
    DateTime? App1Date,
    string?   ReqName,
    string?   ApproverName,
    string    ApproverLabel,
    string    CreatedBy,
    string    CreatedDt,
    // Lines
    IReadOnlyList<PrApprovalReportLineDto> Lines
);

public record PrApprovalReportLineDto(
    decimal   PrSno,
    string    ItemCode,
    string    ItemName,
    string    Uom,
    decimal   QtyInd,
    decimal   FirstAppQty,
    decimal   Rate,
    string?   Remarks
);
