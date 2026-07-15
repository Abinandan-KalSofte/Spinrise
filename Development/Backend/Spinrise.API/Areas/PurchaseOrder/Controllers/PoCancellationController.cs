using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Interfaces;
using Spinrise.Shared.Constants;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

// PO Cancellation (Pocancel.frm, FN-PO-Cancellation v1.4). Routes mirror the
// frozen frontend BASE 'po-cancellation' (poCancellationApi.ts).
[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/po-cancellation")]
public class PoCancellationController : BaseApiController
{
    private readonly IPoCancellationService _service;

    public PoCancellationController(IPoCancellationService service) => _service = service;

    [HttpGet("reasons")]
    public async Task<IActionResult> GetReasons()
    {
        var result = await _service.GetReasonsAsync();
        return OkResponse(result);
    }

    [HttpGet("open-po-list")]
    public async Task<IActionResult> GetOpenPOList(
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetOpenPOListAsync(divCode, yfDate, ylDate);
        return OkResponse(result);
    }

    [HttpGet("lines")]
    public async Task<IActionResult> GetLines(
        [FromQuery] decimal poNo,
        [FromQuery] string  poDate)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetOpenLinesAsync(divCode, poNo, poDate);
        return OkResponse(result);
    }

    [HttpPost("cancel")]
    public async Task<IActionResult> Cancel([FromBody] CancelSaveRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)  ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        var transDate = ResolvePostingDate(HttpContext);

        await _service.CancelLinesAsync(request, divCode, transDate, userId, hostName, ipAddress);
        return OkResponse($"PO-{(long)request.PoNo:D6} cancellation saved. Audit written to LogDet_PO.");
    }

    // Posting date = X-Processing-Date header ('yyyy-MM-dd', set by the axios
    // interceptor from the auth store). LCANDT/FCLOSEDDT record this business date;
    // falls back to today only if the header is absent/unparseable.
    internal static DateTime ResolvePostingDate(HttpContext ctx)
    {
        var raw = ctx.Request.Headers["X-Processing-Date"].FirstOrDefault();
        return DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            ? d.Date
            : DateTime.Today;
    }
}
