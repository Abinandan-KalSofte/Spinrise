using System.Data;
using System.Text.Json;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderForeclosure.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseOrderForeclosure;

public class PoForeclosureRepository : IPoForeclosureRepository
{
    private readonly IUnitOfWork _uow;

    public PoForeclosureRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<PoForeclosureLineDto>> GetOpenLinesAsync(string divCode)
    {
        // Frontend loads every open line up front and filters by PO No. client-side,
        // so the prefix param is left NULL here.
        return await _uow.Connection.QueryAsync<PoForeclosureLineDto>(
            StoredProcedures.Po.Foreclosure.GetOpenLines,
            new { divCode, poNoPrefix = (string?)null },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> ForecloseLinesAsync(
        ForeclosureSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        // Explicit camelCase keys so the JSON matches the OPENJSON paths in the SP.
        var linesJson = JsonSerializer.Serialize(
            request.Lines.Select(l => new
            {
                poNo     = l.PoNo,
                poDate   = l.PoDate,
                group    = l.Group ?? string.Empty,
                sNo      = l.SNo,
                itemCode = l.ItemCode,
                prNo     = l.PrNo,
                prDate   = l.PrDate
            }));

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.Foreclosure.ForecloseLines,
            new
            {
                divCode,
                transDate,
                userId,
                hostName  = hostName  ?? string.Empty,
                ipAddress = ipAddress ?? string.Empty,
                linesJson
            },
            commandType: CommandType.StoredProcedure);

        return request.Lines.Count;
    }
}
