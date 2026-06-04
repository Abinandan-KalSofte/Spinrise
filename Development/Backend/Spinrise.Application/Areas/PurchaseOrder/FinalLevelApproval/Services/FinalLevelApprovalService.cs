using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;
using Spinrise.Shared.Models;

namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Services;

public class FinalLevelApprovalService : IFinalLevelApprovalService
{
    private readonly IFinalLevelApprovalRepository _repo;
    private readonly ILogger<FinalLevelApprovalService> _logger;

    public FinalLevelApprovalService(IFinalLevelApprovalRepository repo, ILogger<FinalLevelApprovalService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public async Task<FinalApprovalGetResponse> GetPendingAsync(FinalApprovalGetQuery query)
    {
        // imode=2 when divcode='0' (Company=ALL or Division=ALL); imode=3 for specific division
        var imode = query.DivCode == "0" ? 2 : 3;
        var items = (await _repo.GetPendingAsync(imode, query.DivCode, query.Bypass)).ToList();
        var totalCost = items.Sum(i => i.QtyRequired * i.LpoRate);
        return new FinalApprovalGetResponse(items, items.Count, Math.Round(totalCost, 2));
    }

    public async Task<FinalApprovalSaveResponse> SaveApprovalsAsync(
        FinalApprovalSaveRequest request, string finalAppUser)
    {
        if (request.Items.Count == 0)
            throw new InvalidOperationException("No records are selected to approve.");

        var plDiscuss = request.Items.Where(i => i.Disposition == 1).ToList();
        if (plDiscuss.Count > 0)
            throw new InvalidOperationException("PL Discuss rows cannot be saved — remove them from the selection.");

        var bypass = request.BypassAll ? 1 : 0;
        var conflicts = new List<(decimal PrNo, decimal PrSno)>();
        var saved = 0;

        foreach (var item in request.Items)
        {
            var result = await _repo.SaveItemAsync(item, finalAppUser, bypass);
            switch (result)
            {
                case 0:
                    saved++;
                    break;
                case 3:
                    conflicts.Add((item.PrNo, item.PrSno));
                    break;
                case 2:
                    throw new InvalidOperationException(
                        $"PR-{(long)item.PrNo:D5} line {item.PrSno} cannot be approved — PR may be cancelled.");
                case 4:
                    throw new InvalidOperationException(
                        $"PR-{(long)item.PrNo:D5} line {item.PrSno} not found.");
            }
        }

        if (conflicts.Count > 0)
            throw new ConcurrencyConflictException(conflicts);

        _logger.LogInformation("FinalApproval Save | User: {User} | Saved: {Saved} | Total: {Total}",
            finalAppUser, saved, request.Items.Count);
        return new FinalApprovalSaveResponse(saved, "Purchase Requisition Approval Completed.");
    }

    public Task<IEnumerable<CompanyDto>>     GetCompaniesAsync()
        => _repo.GetCompaniesAsync();

    public Task<IEnumerable<DivisionDto>>    GetDivisionsAsync(string dbName)
        => _repo.GetDivisionsAsync(dbName);

    public Task<IEnumerable<ItemHistoryDto>> GetItemHistoryAsync(string itemCode, string divCode)
        => _repo.GetItemHistoryAsync(itemCode, divCode);
}
