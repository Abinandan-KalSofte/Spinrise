using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Spinrise.API.Areas.PurchaseOrder.Print;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Shared.Constants;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/pr")]
public class PurchaseRequisitionController : BaseApiController
{
    private readonly IPrService    _service;
    private readonly string        _itemImagesPath;

    public PurchaseRequisitionController(IPrService service, IConfiguration config)
    {
        _service        = service;
        _itemImagesPath = config["ItemImagesPath"] ?? string.Empty;
    }

    // ── Permissions ───────────────────────────────────────────────────────────

    [HttpGet("permissions")]
    public async Task<IActionResult> GetUserPermissions([FromQuery] string divCode)
    {
        var userId = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var result = await _service.GetUserPermissionsAsync(userId, divCode);
        return OkResponse(result);
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
    public async Task<IActionResult> PreAddChecks([FromQuery] string divCode)
    {
        var result = await _service.RunPreAddChecksAsync(divCode);
        return OkResponse(result);
    }

    // ── Lookups ────────────────────────────────────────────────────────────────

    [HttpGet("departments")]
    public async Task<IActionResult> GetDepartments([FromQuery] string divCode, [FromQuery] string? search)
    {
        var result = await _service.GetDepartmentsAsync(divCode, search);
        return OkResponse(result);
    }

    [HttpGet("employees")]
    public async Task<IActionResult> GetEmployees(
        [FromQuery] string divCode,
        [FromQuery] string empCommon = "N",
        [FromQuery] string? search = null)
    {
        var result = await _service.GetEmployeesAsync(divCode, empCommon, search);
        return OkResponse(result);
    }

    [HttpGet("pr-types")]
    public async Task<IActionResult> GetPrTypes([FromQuery] bool activeOnly = true)
    {
        var result = await _service.GetPrTypesAsync(activeOnly);
        return OkResponse(result);
    }

    [HttpGet("items")]
    public async Task<IActionResult> GetItems(
        [FromQuery] string divCode,
        [FromQuery] string? search,
        [FromQuery] string? itemGrpCode,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var result = await _service.GetItemsAsync(divCode, search, itemGrpCode, page, pageSize);
        return OkResponse(result);
    }

    [HttpGet("items/{itemCode}/detail")]
    public async Task<IActionResult> GetItemDetail(
        string itemCode,
        [FromQuery] string divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromQuery] DateOnly pDate)
    {
        var result = await _service.GetItemDetailAsync(divCode, itemCode, fDate, lDate, pDate);
        if (result is null)
            return NotFoundResponse("Item not found or inactive.");
        return OkResponse(result);
    }

    [HttpGet("machine-lookup")]
    public async Task<IActionResult> GetMachineLookup(
        [FromQuery] string divCode,
        [FromQuery] string depCode,
        [FromQuery] string? search = null)
    {
        var result = await _service.GetMachineLookupAsync(divCode, depCode, search);
        return OkResponse(result);
    }

    [HttpGet("cost-centre-lookup")]
    public async Task<IActionResult> GetCostCentreLookup(
        [FromQuery] string divCode,
        [FromQuery] string? search = null)
    {
        var result = await _service.GetCostCentreLookupAsync(divCode, search);
        return OkResponse(result);
    }

    [HttpGet("items/{itemCode}/pending-order")]
    public async Task<IActionResult> CheckPendingOrder(
        string itemCode,
        [FromQuery] string divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromQuery] string depCode)
    {
        var result = await _service.CheckPendingOrderAsync(divCode, fDate, lDate, depCode, itemCode);
        return OkResponse(result);
    }

    // ── PR data ────────────────────────────────────────────────────────────────

    [HttpGet("last")]
    public async Task<IActionResult> GetLastRecord(
        [FromQuery] string divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate)
    {
        var result = await _service.GetLastRecordAsync(divCode, fDate, lDate);
        return OkResponse(result);
    }

    [HttpGet("{prNo}")]
    public async Task<IActionResult> GetById(decimal prNo, [FromQuery] string divCode, [FromQuery] DateOnly prDate)
    {
        var result = await _service.GetByIdAsync(divCode, prNo, prDate);
        if (result is null)
            return NotFoundResponse("PR not found.");
        return OkResponse(result);
    }

    [HttpGet]
    public async Task<IActionResult> GetList(
        [FromQuery] string divCode,
        [FromQuery] DateOnly fDate,
        [FromQuery] DateOnly lDate,
        [FromQuery] string mode = "FIND",
        [FromQuery] string? depCode = null,
        [FromQuery] string? reqName = null,
        [FromQuery] string? poGrp  = null,
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var result = await _service.GetListAsync(divCode, fDate, lDate, mode, depCode, reqName, poGrp, search, page, pageSize);
        return OkResponse(result);
    }

    // ── CRUD ───────────────────────────────────────────────────────────────────

    [HttpPost]
    public async Task<IActionResult> Add([FromQuery] string divCode, [FromBody] SavePrRequest request,
        [FromQuery] DateOnly fDate, [FromQuery] DateOnly lDate)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        var prNo = await _service.AddAsync(divCode, request, userId, hostName, ipAddress, fDate, lDate);
        return OkResponse(new { PrNo = prNo }, $"PR No. for your transaction is {prNo}");
    }

    [HttpPut]
    public async Task<IActionResult> Modify([FromQuery] string divCode, [FromBody] SavePrRequest request,
        [FromQuery] DateOnly fDate, [FromQuery] DateOnly lDate)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        var prNo = await _service.ModifyAsync(divCode, request, userId, hostName, ipAddress, fDate, lDate);
        return OkResponse(new { PrNo = prNo }, "PR updated successfully.");
    }

    [HttpDelete]
    public async Task<IActionResult> Delete([FromQuery] string divCode, [FromBody] DeletePrRequest request)
    {
        var userId    = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;
        var hostName  = HttpContext.Request.Headers["X-Forwarded-Host"].FirstOrDefault();
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        await _service.DeleteAsync(divCode, request, userId, hostName, ipAddress);
        return OkResponse("PR deleted successfully.");
    }

    // ── Item image ────────────────────────────────────────────────────────────

    [AllowAnonymous]
    [HttpGet("items/{itemCode}/image")]
    public async Task<IActionResult> GetItemImage(string itemCode)
    {
        var imagePath = await _service.GetItemImagePathAsync(itemCode);
        if (string.IsNullOrWhiteSpace(imagePath) || string.IsNullOrWhiteSpace(_itemImagesPath))
            return NotFound();

        var fileName = Path.GetFileName(imagePath);
        if (string.IsNullOrWhiteSpace(fileName)) return NotFound();

        var fullPath = Path.Combine(_itemImagesPath, fileName);
        if (!System.IO.File.Exists(fullPath)) return NotFound();

        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        var contentType = ext switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png"            => "image/png",
            ".gif"            => "image/gif",
            ".webp"           => "image/webp",
            _                 => "application/octet-stream",
        };

        Response.Headers.CacheControl = "public, max-age=86400";
        return PhysicalFile(fullPath, contentType);
    }

    // ── Print ──────────────────────────────────────────────────────────────────

    [HttpGet("{prNo}/print")]
    public async Task<IActionResult> Print(decimal prNo, [FromQuery] string divCode, [FromQuery] DateOnly prDate)
    {
        var pr = await _service.GetPrintDataAsync(divCode, prNo, prDate);
        if (pr is null) return NotFoundResponse("No records to print.");
        var pdfBytes = PrPrintDocument.Generate(pr);
        return File(pdfBytes, "application/pdf", $"PR-{(long)prNo:D5}.pdf");
    }
}
