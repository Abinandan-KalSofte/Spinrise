using Dapper;
using Spinrise.Application.Areas.Security.Division.DTOs;
using Spinrise.Application.Areas.Security.Division.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.Security.Division;

public class DivisionRepository : IDivisionRepository
{
    private readonly IUnitOfWork _uow;

    public DivisionRepository(IUnitOfWork uow)
    {
        _uow = uow;
    }

    public async Task<IEnumerable<ActiveDivisionDto>> GetActiveDivisionsAsync()
    {
        return await _uow.Connection.QueryAsync<ActiveDivisionDto>(
            StoredProcedures.Auth.GetActiveDivisions,
            commandType: System.Data.CommandType.StoredProcedure);
    }
}
