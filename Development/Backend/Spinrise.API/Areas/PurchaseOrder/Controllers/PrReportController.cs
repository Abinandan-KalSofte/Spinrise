using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using QuestPDF.Fluent;
using Spinrise.API.Areas.PurchaseOrder.Reports;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/pr/report")]
public class PrReportController : BaseApiController
{
    private readonly IPrReportService _service;

    public PrReportController(IPrReportService service)
        => _service = service;

    [HttpGet("download")]
    public async Task<IActionResult> Download(
        [FromQuery] string divCode,
        [FromQuery] string reportType,
        [FromQuery] DateTime fromDate,
        [FromQuery] DateTime toDate,
        [FromQuery] string?   depCode   = null,
        [FromQuery] bool      allItems  = true,
        [FromQuery] string[]? itemCodes = null,
        CancellationToken ct = default)
    {
        var request = new PrReportRequest
        {
            DivCode   = divCode,
            ReportType = reportType,
            FromDate   = fromDate,
            ToDate     = toDate,
            DepCode    = depCode,
            AllItems   = allItems,
            ItemCodes  = itemCodes ?? [],
        };

        byte[] pdf;
        string filename;

        switch (reportType.Trim().ToLowerInvariant())
        {
            case "datewise":
            {
                var rows = await _service.GetDateWiseAsync(request, ct);
                pdf      = Document.Create(c => new PrDateWiseDocument(rows, request).Compose(c)).GeneratePdf();
                filename = $"PRDatewise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf";
                break;
            }
            case "departmentwise":
            {
                var rows = await _service.GetDeptWiseAsync(request, ct);
                pdf      = Document.Create(c => new PrDeptWiseDocument(rows, request).Compose(c)).GeneratePdf();
                filename = $"PRDeptWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf";
                break;
            }
            case "itemwise":
            {
                var rows = await _service.GetItemWiseAsync(request, ct);
                pdf      = Document.Create(c => new PrItemWiseDocument(rows, request).Compose(c)).GeneratePdf();
                filename = $"PRItemWise_{fromDate:yyyyMMdd}_{toDate:yyyyMMdd}.pdf";
                break;
            }
            default:
                return BadRequest(Spinrise.Shared.Models.ApiResponse.Fail($"Unknown reportType '{reportType}'."));
        }

        return File(pdf, "application/pdf", filename);
    }
}
