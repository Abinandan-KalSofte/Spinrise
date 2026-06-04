using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Spinrise.Infrastructure.Data;

public class DbConnectionFactory : IDbConnectionFactory
{
    private readonly string _serverConnection;

    public DbConnectionFactory(IConfiguration config)
    {
        _serverConnection = config.GetConnectionString("ServerConnection")
            ?? throw new InvalidOperationException("ServerConnection not configured in appsettings.");
    }

    public IDbConnection CreateConnection(string dbName)
    {
        var builder = new SqlConnectionStringBuilder(_serverConnection)
        {
            InitialCatalog = dbName
        };
        return new SqlConnection(builder.ConnectionString);
    }
}
