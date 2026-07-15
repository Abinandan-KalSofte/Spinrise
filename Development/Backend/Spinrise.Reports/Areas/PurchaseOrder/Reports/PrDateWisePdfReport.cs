using QuestPDF.Fluent;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.Reports.Core.Interfaces;

namespace Spinrise.Reports.Areas.PurchaseOrder.Reports;

public sealed class PrDateWisePdfReport : IPdfReport<PrReportRequest>
{
    private readonly IPrReportService _service;

    public PrDateWisePdfReport(IPrReportService service) => _service = service;

    public async Task<byte[]> GenerateAsync(PrReportRequest request, CancellationToken ct = default)
    {
        var rows = await _service.GetDateWiseAsync(request, ct);
        return new PrDateWiseDocument(rows, request).GeneratePdf();
    }
}
