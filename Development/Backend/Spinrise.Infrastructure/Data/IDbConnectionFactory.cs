using System.Data;

namespace Spinrise.Infrastructure.Data;

public interface IDbConnectionFactory
{
    IDbConnection CreateConnection(string dbName);
}
