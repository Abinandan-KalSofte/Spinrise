using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Reports.Areas.PurchaseOrder.Reports;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/po/report")]
public class PoReportController : BaseApiController
{
    private readonly PoDateWisePdfReport     _datewise;
    private readonly PoDeptWisePdfReport     _deptwise;
    private readonly PoItemWisePdfReport     _itemwise;
    private readonly PoSupplierWisePdfReport _supplierwise;

    public PoReportController(
        PoDateWisePdfReport datewise,
        PoDeptWisePdfReport deptwise,
        PoItemWisePdfReport itemwise,
        PoSupplierWisePdfReport supplierwise)
    {
        _datewise     = datewise;
        _deptwise     = deptwise;
        _itemwise     = itemwise;
        _supplierwise = supplierwise;
    }

    [HttpGet("download")]
    public async Task<IActionResult> Download(
        [FromQuery] string    divCode,
        [FromQuery] string    reportType,
        [FromQuery] DateTime  fromDate,
        [FromQuery] DateTime  toDate,
        [FromQuery] string?   depCode       = null,
        [FromQuery] bool      allSuppliers  = true,
        [FromQuery] string[]? supplierCodes = null,
        [FromQuery] bool      allItems      = true,
        [FromQuery] string[]? itemCodes     = null,
        [FromQuery] string    confirmStatus = "A",
        [FromQuery] string    format        = "pdf",
        CancellationToken ct = default)
    {
        var request = new PoReportRequest
        {
            DivCode       = divCode,
            ReportType    = reportType,
            FromDate      = fromDate,
            ToDate        = toDate,
            DepCode       = depCode,
            AllSuppliers  = allSuppliers,
            SupplierCodes = supplierCodes ?? [],
            AllItems      = allItems,
            ItemCodes     = itemCodes ?? [],
            ConfirmStatus = confirmStatus,
        };

        var rpt = reportType.Trim().ToLowerInvariant();
        var fmt = format.Trim().ToLowerInvariant();

        return (rpt, fmt) switch
        {
            ("datewise",       "pdf") => File(await _datewise.GenerateAsync(request, ct), "application/pdf",
                                              $"PODatewise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            ("departmentwise", "pdf") => File(await _deptwise.GenerateAsync(request, ct), "application/pdf",
                                              $"PODeptWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            ("itemwise",       "pdf") => File(await _itemwise.GenerateAsync(request, ct), "application/pdf",
                                              $"POItemWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            ("supplierwise",   "pdf") => File(await _supplierwise.GenerateAsync(request, ct), "application/pdf",
                                              $"POSupplierWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            _ => BadRequest(Spinrise.Shared.Models.ApiResponse.Fail(
                     $"Unknown reportType '{reportType}' or format '{format}'."))
        };
    }
}
