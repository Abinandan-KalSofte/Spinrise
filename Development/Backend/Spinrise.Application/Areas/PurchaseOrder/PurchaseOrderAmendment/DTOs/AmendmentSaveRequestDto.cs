using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// Save payload for ksp_PO_AmendOrder (FN §4). Identity fields locate the live PO;
// header amendable fields + lines[] carry the new values. The SP recomputes taxes,
// values and landed cost server-side (FN §4.B — "do not trust client-sent
// amounts") and allocates the Amendment No. in-transaction — the client neither
// sends nor is trusted for AMDORDNO. DataAnnotations enforce the static half of
// FN §3 (Carrier, Order Type, ≥1 line, per-line Rate>0/Qty>0); the changed-line
// AmendReason rule (§3.6) is enforced server-side per changed line (defence in
// depth behind the React validation).
// 13-Jul ruling (Mariyaiya, FN author + Seenivasan, IST): FN §1's "locked identity"
// restriction applies to the LINE GRID only — the HEADER follows VB6, where
// ENABLCONTLS unlocks every field. So Supplier, GSTIN and GST state are amendable,
// along with the rest of the header. PO No / PO Date stay locked: they are the record
// key. (VB6 "permits" editing them only because its save reuses them as the WHERE key,
// which silently retargets a different PO — a latent bug, not behaviour to reproduce.)
public record AmendmentSaveRequestDto(
    // Identity (locate the live PO — NOT amendable)
    [Required] decimal PoNo,
    [Required] string  PoDate,
    [Required][MaxLength(5)]  string PoGroup,     // §3.3 Order Type mandatory
    // Header — amendable
    [Required][MaxLength(10)] string Carrier,     // §3.2 Carrier mandatory
    [Required][MaxLength(20)] string Supplier,    // SLCODE — unlocked by the 13-Jul ruling
                string?  Gstin,                   // cust_gstinno
                string?  GstState,                // cust_gststcode (UI sends "33 - Tamil Nadu"; SP keeps the code)
                string?  Inspect,
                string?  FormType,
                string?  Currency,
                decimal  CurrRate,
                string?  Remarks,
                string?  RefNo,
                string?  RefDate,
                string?  FileNo,
                string?  PaymentTerms,
                int      CreditDays,
                string?  BankCode,
                string?  PayMode,
                string?  DirectInstr,
                decimal  AdvPer,
                decimal  AdvAmt,
                string?  ChequeNo,
                string?  ChequeDate,
                string?  DeliveryInstr1,
                string?  DeliveryInstr2,
                string?  SpecialInstr,
                string?  DueDate,
                decimal  RoundOff,
                // Header charge basis + applicability flags
                decimal  DiscPer,
                decimal  PackPer,
                decimal  InsurPer,
                decimal  FreightAmt,
                decimal  PackingAmt,
                decimal  InsuranceAmt,
                decimal  AddTaxPer,
                string?  FreightType,
                string?  DiscApp,
                string?  PackApp,
                string?  FreightPosition,
                string?  InsurancePosition,
    [Required][MinLength(1)] List<AmendmentLineSaveDto> Lines   // §3.1 ≥1 line
);

public record AmendmentLineSaveDto(
    // Full line key (FN §4 line key: DIVCODE+POGRP+PORDNO+PORDDT+PORDSNO+ITEMCODE;
    // DivCode/PoNo/PoDate/PoGroup come from the header, so the line carries the rest)
    [Required] int     SNo,           // PORDSNO
    [Required] string  ItemCode,
    // PR link (for the CD-NEW-01 backflush key — server re-reads from PO_ORDL too)
               decimal PrNo,
               string? PrDate,
               decimal PrSno,
    // Editable values (SP recomputes derived amounts)
    [Range(0.0001, double.MaxValue)] decimal Rate,   // §3.4 Rate > 0
    [Range(0.0001, double.MaxValue)] decimal Qty,    // §3.4 Order Quantity required
               decimal Weight,
               decimal DiscPer,
               decimal PackingPer,
               decimal FreightPer,
               decimal InsurancePer,
               decimal OtherCharges,
               string? DiscApp,
               string? PackApp,
               string? FreightPos,
               string? InsuranceDuty,
               string? TaxCode,
               string? HsnCode,
               string? CgstCode,
               string? SgstCode,
               string? IgstCode,
               decimal TcsPer,
               string? AddTaxCode,
               decimal AddTaxPer,
               string? Remarks,
               string? ItemMemo,
    // §3.6 — mandatory on any changed line (React validates; SP re-checks)
               string? AmendReason,
               List<AmendmentDeliverySlotSaveDto>? Slots
);

public record AmendmentDeliverySlotSaveDto(
    int      SlotNo,
    string?  ShDate,
    decimal  Qty
);
