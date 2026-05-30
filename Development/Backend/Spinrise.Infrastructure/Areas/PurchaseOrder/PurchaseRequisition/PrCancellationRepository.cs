using System.Data;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseRequisition;

public class PrCancellationRepository : IPrCancellationRepository
{
    private readonly IUnitOfWork _uow;

    public PrCancellationRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<PrCancellablePrDto>> GetCancellablePRsAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<PrCancellablePrDto>(
            StoredProcedures.PrCancellation.GetCancellable,
            new { divcode = divCode, yfdate = yfDate, yldate = ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PrForCancellationDetailDto?> GetPRForCancellationAsync(
        decimal prNo, string prDate, string depCode, string divCode)
    {
        var p = new { divcode = divCode, prno = prNo, prdate = prDate, depcode = depCode };

        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrCancellation.GetForCancellation, p,
            commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<PrForCancellationHeaderDto>();
        if (header is null) return null;

        var lines = await multi.ReadAsync<PrForCancellationLineDto>();
        return new PrForCancellationDetailDto(header, lines);
    }

    public async Task CancelPRAsync(PrCancelRequestDto request, string divCode,
        string userId, string? hostName, string? ipAddress)
    {
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.PrCancellation.Cancel,
            new
            {
                divcode      = divCode,
                prno         = request.PrNo,
                prdate       = request.PRDate,
                depcode      = request.DepCode,
                cancelreason = request.CancelReason,
                userid       = userId,
                hostname     = hostName  ?? string.Empty,
                ipaddress    = ipAddress ?? string.Empty
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PrCancelledPrDto>> GetCancelledPRsForUndoAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<PrCancelledPrDto>(
            StoredProcedures.PrCancellation.GetCancelledForUndo,
            new { divcode = divCode, yfdate = yfDate, yldate = ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task UndoCancellationAsync(PrUndoRequestDto request, string divCode,
        string userId, string? hostName, string? ipAddress)
    {
        byte[] rowVersionBytes = Convert.FromBase64String(request.RowVersion);

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.PrCancellation.UndoCancellation,
            new
            {
                divcode    = divCode,
                prno       = request.PrNo,
                prdate     = request.PRDate,
                depcode    = request.DepCode,
                rowversion = rowVersionBytes,
                userid     = userId,
                hostname   = hostName  ?? string.Empty,
                ipaddress  = ipAddress ?? string.Empty
            },
            commandType: CommandType.StoredProcedure);
    }
}
