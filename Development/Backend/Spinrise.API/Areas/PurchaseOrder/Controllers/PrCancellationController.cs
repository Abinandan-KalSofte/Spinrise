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
[Route("api/v1/pr-cancellation")]
public class PrCancellationController : BaseApiController
{
    private readonly IPrCancellationService _service;

    public PrCancellationController(IPrCancellationService service) => _service = service;

    [HttpGet("cancellable")]
    public async Task<IActionResult> GetCancellable(
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetCancellablePRsAsync(divCode, yfDate, ylDate);
        return OkResponse(result);
    }

    [HttpGet("detail")]
    public async Task<IActionResult> GetDetail(
        [FromQuery] decimal prNo,
        [FromQuery] string  prDate,
        [FromQuery] string  depCode)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetPRForCancellationAsync(prNo, prDate, depCode, divCode);
        if (result is null) return NotFoundResponse("PR not found.");
        return OkResponse(result);
    }

    [HttpPost("cancel")]
    public async Task<IActionResult> CancelPR([FromBody] PrCancelRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode)   ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)    ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.CancelPRAsync(request, divCode, userId, hostName, ipAddress);
        return OkResponse($"PR-{(long)request.PrNo:D5} cancelled. Audit written to LogDet_PO.");
    }

    [HttpGet("cancelled-for-undo")]
    public async Task<IActionResult> GetCancelledForUndo(
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var divCode = User.FindFirstValue(SpinriseClaims.DivCode) ?? string.Empty;
        var result  = await _service.GetCancelledPRsForUndoAsync(divCode, yfDate, ylDate);
        return OkResponse(result);
    }

    [HttpPost("undo")]
    public async Task<IActionResult> UndoCancellation([FromBody] PrUndoRequestDto request)
    {
        var divCode   = User.FindFirstValue(SpinriseClaims.DivCode)   ?? string.Empty;
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)    ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.UndoCancellationAsync(request, divCode, userId, hostName, ipAddress);
        return OkResponse($"PR-{(long)request.PrNo:D5} restored. Audit written to LogDet_PO.");
    }
}
