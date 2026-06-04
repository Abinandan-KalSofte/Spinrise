using System.Data;
using Dapper;
using Spinrise.Application.Areas.Security.Database.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.Security.Database;

public class DatabaseRepository : IDatabaseRepository
{
    private readonly IDbConnectionFactory _factory;

    public DatabaseRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<IEnumerable<string>> GetDatabasesAsync()
    {
        using var conn = _factory.CreateConnection("master");
        conn.Open();
        return await conn.QueryAsync<string>(
            StoredProcedures.System.GetDatabases,
            commandType: CommandType.StoredProcedure);
    }
}
