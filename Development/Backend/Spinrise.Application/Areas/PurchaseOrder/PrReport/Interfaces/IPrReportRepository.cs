using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;

public interface IPrReportRepository
{
    Task<IReadOnlyList<PrDateWiseRowDto>>  GetDateWiseRowsAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PrDeptWiseRowDto>>  GetDeptWiseRowsAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PrItemWiseRowDto>>  GetItemWiseRowsAsync (PrReportRequest request, CancellationToken ct = default);
}
