using Microsoft.Data.SqlClient;

namespace SpinRise.Reports.Common.Data;

/// <summary>
/// Hands out SQL Server connections. Reports depend on this abstraction, never on a
/// hard-coded server, so the host (the console runner today, your ASP.NET API later)
/// decides where the data comes from by supplying the connection string.
/// </summary>
public interface IDbConnectionFactory
{
    SqlConnection Create();
}
