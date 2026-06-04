using System.Data;
using Dapper;
using Spinrise.Application.Areas.Security.Company.DTOs;
using Spinrise.Application.Areas.Security.Company.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.Security.Company;

public class CompanyRepository : ICompanyRepository
{
    private readonly IUnitOfWork _uow;
    private readonly IDbConnectionFactory _factory;

    public CompanyRepository(IUnitOfWork uow, IDbConnectionFactory factory)
    {
        _uow = uow;
        _factory = factory;
    }

    public async Task<IEnumerable<ActiveCompanyDto>> GetActiveCompaniesAsync()
    {
        return await _uow.Connection.QueryAsync<ActiveCompanyDto>(
            StoredProcedures.Auth.GetActiveCompanies,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<ActiveCompanyDto>> GetActiveCompaniesAsync(string dbName)
    {
        using var conn = _factory.CreateConnection(dbName);
        conn.Open();
        return await conn.QueryAsync<ActiveCompanyDto>(
            StoredProcedures.Auth.GetActiveCompanies,
            commandType: CommandType.StoredProcedure);
    }
}
