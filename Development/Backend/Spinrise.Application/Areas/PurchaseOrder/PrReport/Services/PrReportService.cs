using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;

namespace Spinrise.Application.Areas.PurchaseOrder.PrReport.Services;

public class PrReportService : IPrReportService
{
    private readonly IPrReportRepository _repository;

    public PrReportService(IPrReportRepository repository)
        => _repository = repository;

    public Task<IReadOnlyList<PrDateWiseRowDto>> GetDateWiseAsync(PrReportRequest request, CancellationToken ct = default)
        => _repository.GetDateWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PrDeptWiseRowDto>> GetDeptWiseAsync(PrReportRequest request, CancellationToken ct = default)
        => _repository.GetDeptWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PrItemWiseRowDto>> GetItemWiseAsync(PrReportRequest request, CancellationToken ct = default)
        => _repository.GetItemWiseRowsAsync(request, ct);
}
