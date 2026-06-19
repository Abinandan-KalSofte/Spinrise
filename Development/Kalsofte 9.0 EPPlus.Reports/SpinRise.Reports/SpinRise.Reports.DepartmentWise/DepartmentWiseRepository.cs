using Dapper;
using SpinRise.Reports.Common.Data;
using SpinRise.Reports.Common.Models;

namespace SpinRise.Reports.DepartmentWise;

/// <summary>
/// Data access for the Department-Wise PR report.
///
/// The table set and JOIN keys below are taken DIRECTLY from the .rpt link section:
///     PO_PRH --(divcode, prno, prdate)--> PO_PRL
///     PO_PRH --(depcode, divcode)-------> IN_DEP
///     PO_PRL --(itemcode)---------------> IN_ITEM
///     PO_PRH --(divcode)----------------> PP_DIVMAS
///
/// The SELECT column list and WHERE clause are INFERRED and will be tuned to the sample.
/// Two-part names (dbo.X) are used so the catalog is whatever the connection string targets
/// (scmmills / JATNEW); the report's design-time qualifier is not baked in.
/// </summary>
public sealed class DepartmentWiseRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public DepartmentWiseRepository(IDbConnectionFactory connectionFactory)
        => _connectionFactory = connectionFactory;

    private const string RowsSql = @"
SELECT
    h.depcode                AS DepCode,
    d.DEPNAME                AS DepName,
    h.divcode                AS DivCode,
    h.prno                   AS PrNo,
    h.prdate                 AS PrDate,
    l.prsno                  AS PrSno,
    l.reqddate               AS ReqdDate,
    l.itemcode               AS ItemCode,
    i.ITEMNAME               AS ItemName,
    i.ITEMSPEC1              AS ItemSpec,
    i.UOM                    AS Uom,
    ISNULL(l.qtyind,  0)     AS QtyIndented,
    ISNULL(l.qtyreqd, 0)     AS QtyReqd,
    ISNULL(l.qtyord,  0)     AS QtyOrdered,
    ISNULL(l.qtyrec,  0)     AS QtyReceived,
    l.prstatus               AS PrStatusCode,
    l.secondapp              AS SecondApp,
    l.remarks                AS Remarks,
    ISNULL(l.RATE,  0)       AS Rate,
    ISNULL(l.VALUE, 0)       AS Value
FROM dbo.PO_PRH AS h
    INNER JOIN dbo.PO_PRL  AS l ON l.divcode = h.divcode
                               AND l.prno    = h.prno
                               AND l.prdate  = h.prdate
    LEFT  JOIN dbo.IN_DEP  AS d ON d.DEPCODE = h.depcode
                               AND d.divcode = h.divcode
    LEFT  JOIN dbo.IN_ITEM AS i ON i.ITEMCODE = l.itemcode
WHERE h.divcode = @DivCode
    AND h.prdate BETWEEN @FromDate AND @ToDate
    AND (@DepCode IS NULL OR h.depcode = @DepCode)
ORDER BY d.DEPNAME, h.prdate, h.prno, l.prsno;";

    private const string CompanySql = @"
SELECT TOP 1
    DIVCODE  AS DivCode,
    DIVNAME  AS DivName,
    ADD1     AS Address1,
    ADD2     AS Address2,
    ADD3     AS Address3,
    CITY     AS City,
    PINCODE  AS Pincode
FROM dbo.PP_DIVMAS
WHERE DIVCODE = @DivCode;";

    /// <summary>Fetches the PR lines and decodes each line's status.</summary>
    public async Task<IReadOnlyList<DepartmentWiseRow>> GetRowsAsync(
        DepartmentWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        using var connection = _connectionFactory.Create();

        var command = new CommandDefinition(
            RowsSql,
            new { parameters.DivCode, parameters.FromDate, parameters.ToDate, parameters.DepCode },
            cancellationToken: cancellationToken);

        var rows = (await connection.QueryAsync<DepartmentWiseRow>(command)).ToList();

        foreach (var row in rows)
            row.PrStatus = PrStatus.Describe(row.PrStatusCode, row.SecondApp);

        return rows;
    }

    /// <summary>Fetches the division/company banner for the report header.</summary>
    public async Task<CompanyHeader?> GetCompanyAsync(
        string divCode, CancellationToken cancellationToken = default)
    {
        using var connection = _connectionFactory.Create();

        var command = new CommandDefinition(
            CompanySql, new { DivCode = divCode }, cancellationToken: cancellationToken);

        return await connection.QueryFirstOrDefaultAsync<CompanyHeader>(command);
    }
}
