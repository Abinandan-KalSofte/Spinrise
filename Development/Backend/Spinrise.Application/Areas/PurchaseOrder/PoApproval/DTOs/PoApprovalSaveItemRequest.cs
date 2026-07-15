using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

// Wire shape matches the frontend's SaveItem exactly — divCode, poNo, poDate,
// disposition, remarks, postponeDate. divCode is per-item (not request-level):
// when the grid filter is "ALL Divisions" (divCode='0'), rows can span multiple
// real divisions — sending one divCode for the whole batch silently mismatches
// every row's actual DIVCODE (10-Jul-2026 bug fix). No line identifier (save is
// always PO-level, see CR-PO-APPROVAL-01 Open Question 1), no rowVersion (CD-08
// gap, same CR).
public record PoApprovalSaveItemRequest(
    [Required] string  DivCode,    // the row's actual division, never the '0' ALL-divisions filter sentinel
    [Required] decimal PoNo,
    [Required] string  PoDate,     // yyyy-MM-dd
    [Range(1, 5)] int  Disposition,
    string? Remarks,
    string? PostponeDate);         // yyyy-MM-dd — required when Disposition=5 (BR-05, legacy parity)
