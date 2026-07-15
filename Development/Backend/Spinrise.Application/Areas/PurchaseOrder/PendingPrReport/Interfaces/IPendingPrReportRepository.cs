using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.Interfaces;

public interface IPendingPrReportRepository
{
    Task<IReadOnlyList<PendingPrDateWiseRowDto>>  GetDateWiseRowsAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PendingPrDeptWiseRowDto>>  GetDeptWiseRowsAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PendingPrItemWiseRowDto>>  GetItemWiseRowsAsync (PrReportRequest request, CancellationToken ct = default);
}
