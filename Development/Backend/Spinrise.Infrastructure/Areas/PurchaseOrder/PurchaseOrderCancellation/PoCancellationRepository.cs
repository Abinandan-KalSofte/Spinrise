using System.Data;
using System.Text.Json;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseOrderCancellation;

public class PoCancellationRepository : IPoCancellationRepository
{
    private readonly IUnitOfWork _uow;

    public PoCancellationRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<CancellationReasonDto>> GetReasonsAsync()
    {
        return await _uow.Connection.QueryAsync<CancellationReasonDto>(
            StoredProcedures.Po.Cancellation.GetReasons,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PoOpenSummaryDto>> GetOpenPOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<PoOpenSummaryDto>(
            StoredProcedures.Po.Cancellation.GetOpenList,
            new { DivCode = divCode, YFDate = yfDate, YLDate = ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PoCancellationLineDto>> GetOpenLinesAsync(
        string divCode, decimal poNo, string poDate)
    {
        return await _uow.Connection.QueryAsync<PoCancellationLineDto>(
            StoredProcedures.Po.Cancellation.GetLines,
            new { divCode, poNo, poDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task CancelLinesAsync(
        CancelSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        // Explicit camelCase keys so the JSON matches the OPENJSON paths in the SP
        // regardless of serializer settings (same pattern as PoEntryRepository).
        var linesJson = JsonSerializer.Serialize(
            request.Lines.Select(l => new
            {
                sNo        = l.SNo,
                itemCode   = l.ItemCode,
                reasonCode = l.ReasonCode,
                cancelQty  = l.CancelQty
            }));

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.Cancellation.CancelLines,
            new
            {
                divCode,
                poNo      = request.PoNo,
                poDate    = request.PoDate,
                transDate,
                userId,
                hostName  = hostName  ?? string.Empty,
                ipAddress = ipAddress ?? string.Empty,
                linesJson
            },
            commandType: CommandType.StoredProcedure);
    }
}
