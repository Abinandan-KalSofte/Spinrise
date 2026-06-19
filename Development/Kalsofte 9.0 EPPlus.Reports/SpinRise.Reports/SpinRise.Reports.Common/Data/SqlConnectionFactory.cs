using Microsoft.Data.SqlClient;

namespace SpinRise.Reports.Common.Data;

/// <summary>
/// Default <see cref="IDbConnectionFactory"/> backed by a single connection string.
/// The original Crystal report pointed at SQL Server (catalog "scmmills" / "JATNEW");
/// that target is now pure configuration — nothing here is environment-specific.
/// </summary>
public sealed class SqlConnectionFactory : IDbConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(string connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new ArgumentException("A connection string is required.", nameof(connectionString));

        _connectionString = connectionString;
    }

    public SqlConnection Create() => new(_connectionString);
}
