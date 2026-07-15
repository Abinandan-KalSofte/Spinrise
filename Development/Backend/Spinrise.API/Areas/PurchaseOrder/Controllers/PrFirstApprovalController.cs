using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Interfaces;
using Spinrise.Shared.Constants;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/pr-first-approval")]
public class PrFirstApprovalController : BaseApiController
{
    private readonly IPrFirstApprovalService _service;

    public PrFirstApprovalController(IPrFirstApprovalService service) => _service = service;

    // ── Screen init ────────────────────────────────────────────────────────────

    [HttpGet("po-para")]
    public async Task<IActionResult> GetPoPara([FromQuery] string divCode)
    {
        var result = await _service.GetPoParaAsync(divCode);
        if (result is null)
            return NotFoundResponse("Set User Level In Parameter Form");
        return OkResponse(result);
    }

    // ── Lookups ────────────────────────────────────────────────────────────────

    [HttpGet("departments")]
    public async Task<IActionResult> GetDepartments([FromQuery] string divCode)
    {
        var userId = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var result = await _service.GetDeptForUserAsync(divCode, userId);
        return OkResponse(result);
    }

    [HttpGet("pending")]
    public async Task<IActionResult> GetPendingList(
        [FromQuery] string   divCode,
        [FromQuery] string   dep,
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var result = await _service.GetPendingListAsync(divCode, dep, yfDate, ylDate);
        return OkResponse(result);
    }

    [HttpGet("approved")]
    public async Task<IActionResult> GetApprovedList(
        [FromQuery] string   divCode,
        [FromQuery] DateTime yfDate,
        [FromQuery] DateTime ylDate)
    {
        var result = await _service.GetApprovedListAsync(divCode, yfDate, ylDate);
        return OkResponse(result);
    }

    // ── PR detail ──────────────────────────────────────────────────────────────

    [HttpGet("detail")]
    public async Task<IActionResult> GetDetail(
        [FromQuery] string   divCode,
        [FromQuery] decimal  prNo,
        [FromQuery] DateTime prDate)
    {
        var result = await _service.GetDetailAsync(divCode, prNo, prDate);
        if (result is null) return NotFoundResponse("PR not found.");
        return OkResponse(result);
    }

    // ── Save (First Level Approval) ────────────────────────────────────────────

    [HttpPost("approve")]
    public async Task<IActionResult> Approve([FromQuery] string divCode, [FromBody] SaveFirstApprovalRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)  ?? string.Empty;
        var userName  = User.FindFirstValue(SpinriseClaims.UserName) ?? userId;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.SaveAsync(divCode, request, userId, userName, ipAddress, hostName, moduleNo: 1);
        return OkResponse($"PR-{(long)request.PrNo:D5} — First Level Approval saved. PRSTATUS → F.");
    }

    // ── Delete Approval ────────────────────────────────────────────────────────

    [HttpPost("delete-approval")]
    public async Task<IActionResult> DeleteApproval([FromQuery] string divCode, [FromBody] DeleteFirstApprovalRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId)   ?? string.Empty;
        var userName  = User.FindFirstValue(SpinriseClaims.UserName) ?? userId;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.DeleteAsync(divCode, request, userId, userName, ipAddress, hostName, moduleNo: 1);
        return OkResponse($"PR-{(long)request.PrNo:D5} — First Level Approval deleted. PRSTATUS → Requested.");
    }

    // ── Print (separate endpoint — CEO Directive CD-05) ────────────────────────

    [HttpGet("{prNo}/print")]
    public async Task<IActionResult> Print(
        decimal  prNo,
        [FromQuery] string   divCode,
        [FromQuery] DateTime prDate)
    {
        var reportData = await _service.GetReportDataAsync(divCode, prNo, prDate);
        if (reportData is null) return NotFoundResponse("No records to print.");
        var pdfBytes = PrFirstApprovalPrintDocument.Generate(reportData);
        return File(pdfBytes, "application/pdf", $"PR-APPROVAL-{(long)prNo:D5}.pdf");
    }
}
