using QuestPDF.Fluent;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;
using Spinrise.Reports.Core.Interfaces;

namespace Spinrise.Reports.Areas.PurchaseOrder.Reports;

public sealed class PoDeptWisePdfReport : IPdfReport<PoReportRequest>
{
    private readonly IPoReportService _service;

    public PoDeptWisePdfReport(IPoReportService service) => _service = service;

    public async Task<byte[]> GenerateAsync(PoReportRequest request, CancellationToken ct = default)
    {
        var rows = await _service.GetDeptWiseAsync(request, ct);
        return new PoDeptWiseDocument(rows, request).GeneratePdf();
    }
}
