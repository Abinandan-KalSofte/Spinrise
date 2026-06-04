using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Areas.PurchaseOrder.Print;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;
using Spinrise.Shared.Constants;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/pr-amendment")]
public class PrAmendmentController : BaseApiController
{
    private readonly IPrAmendmentService _service;

    public PrAmendmentController(IPrAmendmentService service) => _service = service;

    // ── List ───────────────────────────────────────────────────────────────────

    [HttpGet]
    public async Task<IActionResult> GetList(
        [FromQuery] string  divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromQuery] decimal? prNo     = null,
        [FromQuery] string?  search   = null,
        [FromQuery] int      page     = 1,
        [FromQuery] int      pageSize = 50)
    {
        var result = await _service.GetListAsync(divCode, fDate, lDate, prNo, search, page, pageSize);
        return OkResponse(result);
    }

    // ── Load PR for new amendment ──────────────────────────────────────────────

    [HttpGet("for-new/{prNo}/{prDate}")]
    public async Task<IActionResult> GetForNew(
        decimal prNo,
        DateOnly prDate,
        [FromQuery] string divCode)
    {
        var result = await _service.GetForNewAsync(divCode, prNo, prDate);
        if (result is null)
            return NotFoundResponse("PR not found or not eligible for amendment.");
        return OkResponse(result);
    }

    // ── Get by ID ──────────────────────────────────────────────────────────────

    [HttpGet("{prNo}/{prDate}/{amendNo:int}")]
    public async Task<IActionResult> GetById(
        decimal  prNo,
        DateOnly prDate,
        int      amendNo,
        [FromQuery] string divCode)
    {
        var result = await _service.GetByIdAsync(divCode, prNo, prDate, amendNo);
        if (result is null)
            return NotFoundResponse("Amendment not found.");
        return OkResponse(result);
    }

    // ── Add ────────────────────────────────────────────────────────────────────

    [HttpPost]
    public async Task<IActionResult> Add(
        [FromQuery] string divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromBody]  SaveAmendmentRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        var amendNo = await _service.AddAsync(divCode, request, userId, fDate, lDate, hostName, ipAddress);
        return OkResponse(new { AmendNo = amendNo }, $"Amendment No. {amendNo} created successfully.");
    }

    // ── Modify ─────────────────────────────────────────────────────────────────

    [HttpPut("{prNo}/{prDate}/{amendNo:int}")]
    public async Task<IActionResult> Modify(
        decimal  prNo,
        DateOnly prDate,
        int      amendNo,
        [FromQuery] string divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromBody]  SaveAmendmentRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.ModifyAsync(divCode, amendNo, request, userId, fDate, lDate, hostName, ipAddress);
        return OkResponse("Amendment updated successfully.");
    }

    // ── Delete ─────────────────────────────────────────────────────────────────

    [HttpDelete("{prNo}/{prDate}/{amendNo:int}")]
    public async Task<IActionResult> Delete(
        decimal  prNo,
        DateOnly prDate,
        int      amendNo,
        [FromQuery] string divCode,
        [FromQuery] string rowVersion)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.DeleteAsync(divCode, prNo, prDate, amendNo, rowVersion, userId, hostName, ipAddress);
        return OkResponse("Amendment deleted successfully.");
    }

    // ── Delete Line (deltype=2 — single line from saved amendment) ────────────

    [HttpDelete("{prNo}/{prDate}/{amendNo:int}/lines/{prSno:int}")]
    public async Task<IActionResult> DeleteLine(
        decimal  prNo,
        DateOnly prDate,
        int      amendNo,
        int      prSno,
        [FromQuery] string  divCode,
        [FromQuery] string  rowVersion,
        [FromQuery] DateOnly pDate)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.DeleteLineAsync(divCode, prNo, prDate, amendNo, prSno,
            rowVersion, pDate, userId, hostName, ipAddress);
        return OkResponse("Amendment line deleted successfully.");
    }

    // ── Print ──────────────────────────────────────────────────────────────────

    [HttpGet("{prNo}/{prDate}/{amendNo:int}/print")]
    public async Task<IActionResult> Print(
        decimal  prNo,
        DateOnly prDate,
        int      amendNo,
        [FromQuery] string divCode)
    {
        var data = await _service.GetPrintDataAsync(divCode, prNo, prDate, amendNo);
        if (data is null) return NotFoundResponse("No records to print.");

        var pdfBytes = PrAmendmentPrintDocument.Generate(data);
        return File(pdfBytes, "application/pdf", $"PRA-{(long)prNo:D5}-{amendNo}.pdf");
    }
}
