using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
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

    // ── Print ──────────────────────────────────────────────────────────────────

    [HttpGet("{prNo}/{prDate}/{amendNo:int}/print")]
    public async Task<IActionResult> Print(
        decimal  prNo,
        DateOnly prDate,
        int      amendNo,
        [FromQuery] string divCode)
    {
        var userId = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var data   = await _service.GetPrintDataAsync(divCode, prNo, prDate, amendNo, userId);
        if (data is null) return NotFoundResponse("No records to print.");

        var pdfBytes = PrAmendmentPrintDocument.Generate(data);
        return File(pdfBytes, "application/pdf", $"PRA-{(long)prNo:D5}-{amendNo}.pdf");
    }
}
