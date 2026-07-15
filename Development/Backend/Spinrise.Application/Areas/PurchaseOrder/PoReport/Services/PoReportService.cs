using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PoReport.Services;

public class PoReportService : IPoReportService
{
    private readonly IPoReportRepository _repository;

    public PoReportService(IPoReportRepository repository)
        => _repository = repository;

    public Task<IReadOnlyList<PoDateWiseRowDto>> GetDateWiseAsync(PoReportRequest request, CancellationToken ct = default)
        => _repository.GetDateWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PoDeptWiseRowDto>> GetDeptWiseAsync(PoReportRequest request, CancellationToken ct = default)
        => _repository.GetDeptWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PoItemWiseRowDto>> GetItemWiseAsync(PoReportRequest request, CancellationToken ct = default)
        => _repository.GetItemWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PoSupplierWiseRowDto>> GetSupplierWiseAsync(PoReportRequest request, CancellationToken ct = default)
        => _repository.GetSupplierWiseRowsAsync(request, ct);
}
