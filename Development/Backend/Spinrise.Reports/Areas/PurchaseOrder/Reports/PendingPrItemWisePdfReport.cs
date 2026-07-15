using QuestPDF.Fluent;
using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.Reports.Core.Interfaces;

namespace Spinrise.Reports.Areas.PurchaseOrder.Reports;

public sealed class PendingPrItemWisePdfReport : IPdfReport<PrReportRequest>
{
    private readonly IPendingPrReportService _service;

    public PendingPrItemWisePdfReport(IPendingPrReportService service) => _service = service;

    public async Task<byte[]> GenerateAsync(PrReportRequest request, CancellationToken ct = default)
    {
        var rows = await _service.GetItemWiseAsync(request, ct);
        return new PendingPrItemWiseDocument(rows, request).GeneratePdf();
    }
}
