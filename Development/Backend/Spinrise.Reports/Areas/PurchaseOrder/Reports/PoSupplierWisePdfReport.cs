using QuestPDF.Fluent;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.Reports.Core.Interfaces;

namespace Spinrise.Reports.Areas.PurchaseOrder.Reports;

public sealed class PoSupplierWisePdfReport : IPdfReport<PoReportRequest>
{
    private readonly IPoReportService _service;

    public PoSupplierWisePdfReport(IPoReportService service) => _service = service;

    public async Task<byte[]> GenerateAsync(PoReportRequest request, CancellationToken ct = default)
    {
        var rows = await _service.GetSupplierWiseAsync(request, ct);
        return new PoSupplierWiseDocument(rows, request).GeneratePdf();
    }
}
