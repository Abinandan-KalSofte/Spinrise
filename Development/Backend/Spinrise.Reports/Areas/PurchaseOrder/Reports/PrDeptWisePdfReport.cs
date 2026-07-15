using QuestPDF.Fluent;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.Reports.Core.Interfaces;

namespace Spinrise.Reports.Areas.PurchaseOrder.Reports;

public sealed class PrDeptWisePdfReport : IPdfReport<PrReportRequest>
{
    private readonly IPrReportService _service;

    public PrDeptWisePdfReport(IPrReportService service) => _service = service;

    public async Task<byte[]> GenerateAsync(PrReportRequest request, CancellationToken ct = default)
    {
        var rows = await _service.GetDeptWiseAsync(request, ct);
        return new PrDeptWiseDocument(rows, request).GeneratePdf();
    }
}
