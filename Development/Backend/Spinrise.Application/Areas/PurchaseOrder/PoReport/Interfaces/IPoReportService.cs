using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;

public interface IPoReportService
{
    Task<IReadOnlyList<PoDateWiseRowDto>> GetDateWiseAsync(PoReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PoDeptWiseRowDto>> GetDeptWiseAsync(PoReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PoItemWiseRowDto>> GetItemWiseAsync(PoReportRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PoSupplierWiseRowDto>> GetSupplierWiseAsync(PoReportRequest request, CancellationToken ct = default);
}
