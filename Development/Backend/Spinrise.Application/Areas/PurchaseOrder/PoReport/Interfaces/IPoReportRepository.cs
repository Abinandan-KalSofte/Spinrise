using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;

public interface IPoReportRepository
{
    Task<IReadOnlyList<PoDateWiseRowDto>> GetDateWiseRowsAsync(PoReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PoDeptWiseRowDto>> GetDeptWiseRowsAsync(PoReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PoItemWiseRowDto>> GetItemWiseRowsAsync(PoReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PoSupplierWiseRowDto>> GetSupplierWiseRowsAsync(PoReportRequest request, CancellationToken ct = default);
}
