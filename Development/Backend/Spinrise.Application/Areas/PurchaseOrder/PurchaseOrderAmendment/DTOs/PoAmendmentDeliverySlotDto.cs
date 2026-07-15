namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// One delivery-schedule slot for an amendment line (PO_ORDL_DETL, FN §2 group 11).
// Third result set of ksp_PO_GetPOForAmend. Mirrors PoEntry.DeliverySlotDto; the
// line-linkage keys (SNo/ItemCode) let the client attach slots to their parent
// line without a nested SP result. Class with named init props (Dapper by name).
public class PoAmendmentDeliverySlotDto
{
    public int     SNo      { get; init; }   // parent PORDSNO
    public string  ItemCode { get; init; } = "";
    public int     SlotNo   { get; init; }
    public string  ShDate   { get; init; } = "";   // SHDATE
    public decimal Qty      { get; init; }          // QUANTITY (3dp)
}
