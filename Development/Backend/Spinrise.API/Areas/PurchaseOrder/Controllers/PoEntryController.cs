using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Areas.PurchaseOrder.Print;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.Interfaces;
using Spinrise.Shared.Constants;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/po")]
public class PoEntryController : BaseApiController
{
    private readonly IPoEntryService _service;

    public PoEntryController(IPoEntryService service)
    {
        _service = service;
    }

    // ── Screen init ────────────────────────────────────────────────────────────

    [HttpGet("parameters")]
    public async Task<IActionResult> GetParameters([FromQuery] string divCode)
    {
        var result = await _service.GetParametersAsync(divCode);
        if (result is null)
            return NotFoundResponse("No parameters found for this division.");
        return OkResponse(result);
    }

    [HttpGet("pre-add-checks")]
    public async Task<IActionResult> GetPreAddChecks([FromQuery] string divCode)
    {
        var result = await _service.GetPreAddChecksAsync(divCode);
        return OkResponse(result);
    }

    [HttpGet("permissions")]
    public async Task<IActionResult> GetUserPermissions([FromQuery] string divCode)
    {
        var userId = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var result = await _service.GetUserPermissionsAsync(userId, divCode);
        return OkResponse(result);
    }

    // ── Lookups ────────────────────────────────────────────────────────────────

    [HttpGet("suppliers")]
    public async Task<IActionResult> GetSuppliers([FromQuery] string divCode, [FromQuery] string? search)
    {
        var result = await _service.GetSuppliersAsync(divCode, search);
        return OkResponse(result);
    }

    [HttpGet("order-types")]
    public async Task<IActionResult> GetOrderTypes([FromQuery] bool activeOnly = true)
    {
        var result = await _service.GetOrderTypesAsync(activeOnly);
        return OkResponse(result);
    }

    [HttpGet("carriers")]
    public async Task<IActionResult> GetCarriers([FromQuery] string? search)
    {
        var result = await _service.GetCarriersAsync(search);
        return OkResponse(result);
    }

    [HttpGet("banks")]
    public async Task<IActionResult> GetBanks([FromQuery] string divCode, [FromQuery] string? search)
    {
        var result = await _service.GetBanksAsync(divCode, search);
        return OkResponse(result);
    }

    [HttpGet("form-types")]
    public async Task<IActionResult> GetFormTypes()
    {
        var result = await _service.GetFormTypesAsync();
        return OkResponse(result);
    }

    [HttpGet("gst-tax-codes")]
    public async Task<IActionResult> GetGstTaxCodes([FromQuery] string? search)
    {
        var result = await _service.GetGstTaxCodesAsync(search);
        return OkResponse(result);
    }

    [HttpGet("gst-routing")]
    public async Task<IActionResult> GetGstRouting([FromQuery] string divCode, [FromQuery] string supplier)
    {
        var result = await _service.GetGstRoutingAsync(divCode, supplier);
        return OkResponse(result);
    }

    [HttpGet("addresses")]
    public async Task<IActionResult> GetAddresses(
        [FromQuery] string divCode,
        [FromQuery] string kind,
        [FromQuery] string? search)
    {
        var result = await _service.GetAddressesAsync(divCode, kind, search);
        return OkResponse(result);
    }

    // ── PR Picker ──────────────────────────────────────────────────────────────

    [HttpGet("eligible-pr-lines")]
    public async Task<IActionResult> GetEligiblePrLines(
        [FromQuery] string divCode,
        [FromQuery] string? orderType,
        [FromQuery] string? search,
        [FromQuery] int page     = 1,
        [FromQuery] int pageSize = 50)
    {
        var result = await _service.GetEligiblePrLinesAsync(divCode, orderType, search, page, pageSize);
        return OkResponse(result);
    }

    // ── Record load ────────────────────────────────────────────────────────────

    [HttpGet("{poNo}")]
    public async Task<IActionResult> GetById(decimal poNo, [FromQuery] string divCode, [FromQuery] DateOnly poDate)
    {
        var result = await _service.GetByIdAsync(divCode, poNo, poDate);
        if (result is null)
            return NotFoundResponse("Purchase Order not found.");
        return OkResponse(result);
    }

    [HttpGet("last")]
    public async Task<IActionResult> GetLastRecord(
        [FromQuery] string  divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate)
    {
        var result = await _service.GetLastRecordAsync(divCode, fDate, lDate);
        return OkResponse(result);
    }

    [HttpGet]
    public async Task<IActionResult> GetList(
        [FromQuery] string   divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromQuery] string?  search,
        [FromQuery] string?  supplier,
        [FromQuery] int      page     = 1,
        [FromQuery] int      pageSize = 50)
    {
        var result = await _service.GetListAsync(divCode, fDate, lDate, search, supplier, page, pageSize);
        return OkResponse(result);
    }

    // ── Save ───────────────────────────────────────────────────────────────────

    [HttpPost]
    public async Task<IActionResult> Add(
        [FromQuery] string   divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromBody]  AddPoRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        var result = await _service.AddAsync(divCode, request, userId, hostName, ipAddress, fDate, lDate);
        return OkResponse(result, $"Purchase Order created. Number: {(long)result.PoNo}");
    }

    // ── Print ─────────────────────────────────────────────────────────────────

    [HttpGet("{poNo}/print")]
    public async Task<IActionResult> Print(decimal poNo, [FromQuery] string divCode, [FromQuery] DateOnly poDate)
    {
        var parameters = await _service.GetParametersAsync(divCode);
        var po = await _service.GetPrintDataAsync(divCode, poNo, poDate);
        if (po is null)
            return NotFoundResponse("No records to print.");

        if (parameters?.PoPrintApp == "Y" && po.Conflg == "N")
            return FailResponse("Approval Not Complete For This PO", 403);

        var pdfBytes = PurchaseOrderDocument.Generate(po);
        await _service.UpdatePrintFlagAsync(divCode, poNo, poDate);
        return File(pdfBytes, "application/pdf", $"PO-{(long)poNo:D6}.pdf");
    }

    // ── Delete ─────────────────────────────────────────────────────────────────

    [HttpDelete]
    public async Task<IActionResult> Delete(
        [FromQuery] string divCode,
        [FromBody]  DeletePoRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        await _service.DeleteAsync(divCode, request, userId, hostName, ipAddress);
        return OkResponse("Purchase Order deleted successfully.");
    }
}
