using System.Data;
using Dapper;
using Spinrise.Application.Areas.Security.Division.DTOs;
using Spinrise.Application.Areas.Security.Division.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.Security.Division;

public class DivisionRepository : IDivisionRepository
{
    private readonly IUnitOfWork _uow;
    private readonly IDbConnectionFactory _factory;

    public DivisionRepository(IUnitOfWork uow, IDbConnectionFactory factory)
    {
        _uow = uow;
        _factory = factory;
    }

    public async Task<IEnumerable<ActiveDivisionDto>> GetActiveDivisionsAsync()
    {
        return await _uow.Connection.QueryAsync<ActiveDivisionDto>(
            StoredProcedures.Auth.GetActiveDivisions,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<ActiveDivisionDto>> GetActiveDivisionsAsync(string dbName)
    {
        using var conn = _factory.CreateConnection(dbName);
        conn.Open();
        return await conn.QueryAsync<ActiveDivisionDto>(
            StoredProcedures.Auth.GetActiveDivisions,
            commandType: CommandType.StoredProcedure);
    }
}
