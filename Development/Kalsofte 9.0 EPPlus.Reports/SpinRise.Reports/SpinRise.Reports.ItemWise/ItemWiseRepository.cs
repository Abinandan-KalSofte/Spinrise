using System.Data;
using Dapper;
using SpinRise.Reports.Common.Data;

namespace SpinRise.Reports.ItemWise;

/// <summary>
/// Data access for the Item-Wise PR report: a single call to dbo.KSP_PR_ITEMWISE.
/// The SP owns the joins, the item filter ("A" = all, else a CSV of codes via dbo.split) and the
/// status decode, so this layer only supplies parameters and maps the result.
/// </summary>
public sealed class ItemWiseRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public ItemWiseRepository(IDbConnectionFactory connectionFactory)
        => _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<ItemWiseRow>> GetRowsAsync(
        ItemWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        using var connection = _connectionFactory.Create();

        var command = new CommandDefinition(
            "dbo.KSP_PR_ITEMWISE",
            new
            {
                // @FPRDT/@TPRDT are varchar in the SP and compared with BETWEEN; yyyy-MM-dd is
                // unambiguous for SQL Server's datetime conversion on this server.
                DIVCODE = parameters.DivCode,
                FPRDT   = parameters.FromDate.ToString("yyyy-MM-dd"),
                TPRDT   = parameters.ToDate.ToString("yyyy-MM-dd"),
                FITEM   = string.IsNullOrWhiteSpace(parameters.ItemFilter) ? "A" : parameters.ItemFilter,
                TITEM   = "A", // ignored by the SP
            },
            commandType: CommandType.StoredProcedure,
            cancellationToken: cancellationToken);

        var rows = await connection.QueryAsync<ItemWiseRow>(command);
        return rows.ToList();
    }
}
