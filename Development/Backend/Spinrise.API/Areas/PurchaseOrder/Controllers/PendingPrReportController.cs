using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Reports.Areas.PurchaseOrder.Reports;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/pending-pr/report")]
public class PendingPrReportController : BaseApiController
{
    private readonly PendingPrDateWisePdfReport  _datewise;
    private readonly PendingPrDeptWisePdfReport  _deptwise;
    private readonly PendingPrItemWisePdfReport  _itemwise;

    public PendingPrReportController(
        PendingPrDateWisePdfReport datewise,
        PendingPrDeptWisePdfReport deptwise,
        PendingPrItemWisePdfReport itemwise)
    {
        _datewise = datewise;
        _deptwise = deptwise;
        _itemwise = itemwise;
    }

    [HttpGet("download")]
    public async Task<IActionResult> Download(
        [FromQuery] string    divCode,
        [FromQuery] string    reportType,
        [FromQuery] DateTime  fromDate,
        [FromQuery] DateTime  toDate,
        [FromQuery] string?   depCode   = null,
        [FromQuery] bool      allItems  = true,
        [FromQuery] string[]? itemCodes = null,
        [FromQuery] string    format    = "pdf",
        CancellationToken ct = default)
    {
        var request = new PrReportRequest
        {
            DivCode    = divCode,
            ReportType = reportType,
            FromDate   = fromDate,
            ToDate     = toDate,
            DepCode    = depCode,
            AllItems   = allItems,
            ItemCodes  = itemCodes ?? [],
        };

        var rpt = reportType.Trim().ToLowerInvariant();
        var fmt = format.Trim().ToLowerInvariant();

        return (rpt, fmt) switch
        {
            ("datewise",       "pdf") => File(await _datewise.GenerateAsync(request, ct), "application/pdf",
                                              $"PendingPRDatewise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            ("departmentwise", "pdf") => File(await _deptwise.GenerateAsync(request, ct), "application/pdf",
                                              $"PendingPRDeptWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            ("itemwise",       "pdf") => File(await _itemwise.GenerateAsync(request, ct), "application/pdf",
                                              $"PendingPRItemWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf"),

            _ => BadRequest(Spinrise.Shared.Models.ApiResponse.Fail(
                     $"Unknown reportType '{reportType}' or format '{format}'."))
        };
    }
}
