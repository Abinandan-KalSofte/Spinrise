using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.Interfaces;
using Spinrise.Shared.Constants;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

// PO Approval — First/Second/Final Level. One controller, {level} route segment,
// matching Development/spinrise-web/src/features/po/api/createPoApprovalApi.ts's
// factory shape exactly (po-approval/{level}/divisions|pending|save).
[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/po-approval/{level}")]
public class PoApprovalController : BaseApiController
{
    private readonly IPoApprovalService _service;

    public PoApprovalController(IPoApprovalService service) => _service = service;

    [HttpGet("divisions")]
    public async Task<IActionResult> GetDivisions(string level)
    {
        var result = await _service.GetDivisionsAsync(level);
        return OkResponse(result);
    }

    [HttpGet("pending")]
    public async Task<IActionResult> GetPending(
        string level,
        [FromQuery] string   divCode,
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate,
        [FromQuery] string?  search)
    {
        var result = await _service.GetPendingAsync(level, divCode, yfDate, ylDate, search);
        return OkResponse(result);
    }

    [HttpPost("save")]
    public async Task<IActionResult> Save(string level, [FromBody] PoApprovalSaveRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)   ?? string.Empty;
        var userName  = User.FindFirstValue(SpinriseClaims.UserName) ?? userId;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        var result = await _service.SaveAsync(level, request, userId, userName, ipAddress, hostName);
        return OkResponse(result);
    }
}
