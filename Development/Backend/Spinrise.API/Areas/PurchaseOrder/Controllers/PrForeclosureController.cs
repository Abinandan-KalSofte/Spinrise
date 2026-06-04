using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Shared.Constants;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/pr-foreclosure")]
public class PrForeclosureController : BaseApiController
{
    private readonly IPrForeclosureService _service;

    public PrForeclosureController(IPrForeclosureService service) => _service = service;

    [HttpGet("open-lines")]
    public async Task<IActionResult> GetOpenLines(
        [FromQuery] string fDate,
        [FromQuery] string lDate,
        [FromQuery] string? prNoFilter)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var fDateParsed = DateOnly.Parse(fDate);
        var lDateParsed = DateOnly.Parse(lDate);
        var result  = await _service.GetOpenLinesAsync(divCode, fDateParsed, lDateParsed, prNoFilter);
        return OkResponse(result);
    }

    [HttpPost("save")]
    public async Task<IActionResult> SaveForeclosure([FromBody] PrForeclosureSaveRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode)   ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)    ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        var count = await _service.SaveForeclosureAsync(request, divCode, userId, hostName, ipAddress);
        return OkResponse(new { Count = count },
            $"{count} line{(count != 1 ? "s" : "")} force-closed. Audit written to LogDet_PO.");
    }
}
