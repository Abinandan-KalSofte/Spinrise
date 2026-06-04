using System.Data;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseRequisition;

public class PrForeclosureRepository : IPrForeclosureRepository
{
    private readonly IUnitOfWork _uow;

    public PrForeclosureRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<PrForeclosureLineDto>> GetOpenForForeclosureAsync(
        string divCode, DateOnly fDate, DateOnly lDate, string? prNoFilter)
    {
        return await _uow.Connection.QueryAsync<PrForeclosureLineDto>(
            StoredProcedures.PrForeclosure.GetOpenLines,
            new { divcode = divCode, fdate = fDate, ldate = lDate, prno_filter = prNoFilter },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> SaveForeclosureAsync(
        List<PrForeclosureLineKeyDto> lines, string divCode,
        string userId, string? hostName, string? ipAddress)
    {
        if (lines.Count == 0)
            throw new InvalidOperationException("Select at least one item to complete the transaction.");

        await _uow.BeginTransactionAsync();
        try
        {
            foreach (var line in lines)
            {
                await _uow.Connection.ExecuteAsync(
                    StoredProcedures.PrForeclosure.SaveLine,
                    new
                    {
                        divcode   = divCode,
                        prno      = line.PrNo,
                        prdate    = line.PRDate,
                        prsno     = line.PrSno,
                        itemcode  = line.ItemCode,
                        balance   = line.Balance,
                        userid    = userId,
                        hostname  = hostName  ?? string.Empty,
                        ipaddress = ipAddress ?? string.Empty
                    },
                    _uow.Transaction,
                    commandType: CommandType.StoredProcedure);
            }

            await _uow.CommitAsync();
            return lines.Count;
        }
        catch
        {
            await _uow.RollbackAsync();
            throw;
        }
    }
}
