using Microsoft.Data.SqlClient;

namespace SpinRise.QuestPDF.Common.Data;

/// <summary>
/// Standalone implementation — opens a connection from a fixed connection string supplied
/// by the runner's appsettings.json.
/// </summary>
public sealed class SqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;
    public SqlConnectionFactory(string connectionString) => _connectionString = connectionString;
    public SqlConnection Create() => new(_connectionString);
}
