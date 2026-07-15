using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.Services;

public class PendingPrReportService : IPendingPrReportService
{
    private readonly IPendingPrReportRepository _repository;

    public PendingPrReportService(IPendingPrReportRepository repository)
        => _repository = repository;

    public Task<IReadOnlyList<PendingPrDateWiseRowDto>> GetDateWiseAsync(PrReportRequest request, CancellationToken ct = default)
        => _repository.GetDateWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PendingPrDeptWiseRowDto>> GetDeptWiseAsync(PrReportRequest request, CancellationToken ct = default)
        => _repository.GetDeptWiseRowsAsync(request, ct);

    public Task<IReadOnlyList<PendingPrItemWiseRowDto>> GetItemWiseAsync(PrReportRequest request, CancellationToken ct = default)
        => _repository.GetItemWiseRowsAsync(request, ct);
}
