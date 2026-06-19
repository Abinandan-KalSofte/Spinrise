using Microsoft.Data.SqlClient;

namespace SpinRise.QuestPDF.Common.Data;

/// <summary>
/// Factory for opening a SQL Server connection. The standalone runner uses
/// <see cref="SqlConnectionFactory"/>; host applications (e.g. the SpinRise API)
/// supply an adapter that resolves the per-request database from the JWT claim.
/// </summary>
public interface IDbConnectionFactory
{
    SqlConnection Create();
}
