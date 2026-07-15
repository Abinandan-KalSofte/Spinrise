using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Interfaces;
using Spinrise.Shared.Constants;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

// PO Amendment (amdmnt.frm, FN-PO-Amendment v1.2). Routes mirror the frontend
// BASE 'po-amendment' (poAmendmentApi.ts). Claims + X-Processing-Date posting-date
// pattern copied from PoCancellationController.
[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/po-amendment")]
public class PoAmendmentController : BaseApiController
{
    private readonly IPoAmendmentService _service;

    public PoAmendmentController(IPoAmendmentService service) => _service = service;

    // FN §1 Add — lookup of amendable POs (AmdAfterGRN predicate is server-side).
    [HttpGet("amendable-po-list")]
    public async Task<IActionResult> GetAmendablePOList(
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetAmendablePOListAsync(divCode, yfDate, ylDate);
        return OkResponse(result);
    }

    // Load one PO (header + lines + delivery schedule) for amendment.
    [HttpGet("po")]
    public async Task<IActionResult> GetPOForAmend(
        [FromQuery] decimal poNo,
        [FromQuery] string  poDate,
        [FromQuery] string  group)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetPOForAmendAsync(divCode, poNo, poDate, group);
        if (result is null) return NotFoundResponse("Purchase Order not found or not amendable.");
        return OkResponse(result);
    }

    // FN §1 Find — saved amendments for the year (view-only).
    [HttpGet("amendment-list")]
    public async Task<IActionResult> GetAmendmentList(
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetAmendmentListAsync(divCode, yfDate, ylDate);
        return OkResponse(result);
    }

    // FN §4 — save the amendment (allocate Amd No, snapshot, update live, backflush).
    [HttpPost("amend")]
    public async Task<IActionResult> Amend([FromBody] AmendmentSaveRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)  ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        var transDate = ResolvePostingDate(HttpContext);

        var result = await _service.SaveAmendmentAsync(request, divCode, transDate, userId, hostName, ipAddress);
        return OkResponse(result);
    }

    // FN §4 Deletion — whole-PO cascade.
    [HttpPost("delete-order")]
    public async Task<IActionResult> DeleteOrder([FromBody] DeleteOrderRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)  ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        var transDate = ResolvePostingDate(HttpContext);

        await _service.DeleteOrderAsync(request, divCode, transDate, userId, hostName, ipAddress);
        return OkResponse($"PO-{(long)request.PoNo:D6} deleted.");
    }

    // FN §4 Deletion — line-level.
    [HttpPost("delete-lines")]
    public async Task<IActionResult> DeleteLines([FromBody] DeleteLinesRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)  ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        var transDate = ResolvePostingDate(HttpContext);

        await _service.DeleteLinesAsync(request, divCode, transDate, userId, hostName, ipAddress);
        return OkResponse($"PO-{(long)request.PoNo:D6} — {request.Lines.Count} line(s) deleted.");
    }

    // Posting date = X-Processing-Date header ('yyyy-MM-dd', set by the axios
    // interceptor from the auth store). AMDORDDT records this business date;
    // falls back to today only if the header is absent/unparseable. (Same rule as
    // PoCancellationController.ResolvePostingDate.)
    internal static DateTime ResolvePostingDate(HttpContext ctx)
    {
        var raw = ctx.Request.Headers["X-Processing-Date"].FirstOrDefault();
        return DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            ? d.Date
            : DateTime.Today;
    }
}
