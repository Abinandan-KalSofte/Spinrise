using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Interfaces;
using Spinrise.Shared.Constants;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

// PO Foreclosure (FrmPOForeclousre.frm, FN-PO-Foreclosure v1.4). Routes mirror the
// frozen frontend BASE 'po-foreclosure' (poForeclosureApi.ts).
[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/po-foreclosure")]
public class PoForeclosureController : BaseApiController
{
    private readonly IPoForeclosureService _service;

    public PoForeclosureController(IPoForeclosureService service) => _service = service;

    [HttpGet("lines")]
    public async Task<IActionResult> GetLines()
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetOpenLinesAsync(divCode);
        return OkResponse(result);
    }

    [HttpPost("foreclose")]
    public async Task<IActionResult> Foreclose([FromBody] ForeclosureSaveRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)  ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        var transDate = PoCancellationController.ResolvePostingDate(HttpContext);

        var count = await _service.ForecloseLinesAsync(request, divCode, transDate, userId, hostName, ipAddress);
        return OkResponse(new { Count = count },
            $"{count} line{(count != 1 ? "s" : "")} force-closed. Audit written to LogDet_PO.");
    }
}
