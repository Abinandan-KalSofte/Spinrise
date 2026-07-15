using QuestPDF.Fluent;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.Reports.Core.Interfaces;

namespace Spinrise.Reports.Areas.PurchaseOrder.Reports;

public sealed class PoDateWisePdfReport : IPdfReport<PoReportRequest>
{
    private readonly IPoReportService _service;

    public PoDateWisePdfReport(IPoReportService service) => _service = service;

    public async Task<byte[]> GenerateAsync(PoReportRequest request, CancellationToken ct = default)
    {
        var rows = await _service.GetDateWiseAsync(request, ct);
        return new PoDateWiseDocument(rows, request).GeneratePdf();
    }
}
