using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.Interfaces;

public interface IPendingPrReportService
{
    Task<IReadOnlyList<PendingPrDateWiseRowDto>>  GetDateWiseAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PendingPrDeptWiseRowDto>>  GetDeptWiseAsync (PrReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PendingPrItemWiseRowDto>>  GetItemWiseAsync (PrReportRequest request, CancellationToken ct = default);
}
