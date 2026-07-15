using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;

public interface IPrReportService
{
    Task<IReadOnlyList<PrDateWiseRowDto>>  GetDateWiseAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PrDeptWiseRowDto>>  GetDeptWiseAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PrItemWiseRowDto>>  GetItemWiseAsync (PrReportRequest request, CancellationToken ct = default);
}
