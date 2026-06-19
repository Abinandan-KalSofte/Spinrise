using Dapper;
using SpinRise.QuestPDF.Common.Data;

namespace SpinRise.QuestPDF.DepartmentWise;

/// <summary>
/// Data access for the Department-Wise PR report. Replicates the <c>ksp_Pr_DepWise</c> stored
/// procedure as an inline query (no SP-deployment dependency), using the same base tables.
/// <para>
/// Joins mirror the SP: PO_PRH INNER PO_PRL, LEFT IN_DEP, INNER PP_DIVMAS, INNER IN_ITEM.
/// The SP exposes a department <b>range</b> (@FrmDep–@ToDep); the (missing) record selection is
/// applied here as the report intends: division + PR-date window + department range.
/// <c>ISNULL</c> is applied on every quantity so the renderer never sees a null.
/// </para>
/// </summary>
public sealed class DepartmentWiseRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public DepartmentWiseRepository(IDbConnectionFactory connectionFactory)
        => _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<DepartmentWiseRow>> GetRowsAsync(
        DepartmentWiseParameters p, CancellationToken ct = default)
    {
        using var connection = _connectionFactory.Create();

        const string sql = @"
            SELECT
                h.divcode                AS DivCode,
                h.depcode                AS DepCode,
                ISNULL(dep.depname, '')  AS DepName,
                l.prno                   AS PrNo,
                l.prdate                 AS PrDate,
                l.itemcode               AS ItemCode,
                ISNULL(itm.itemname,'')  AS ItemName,
                ISNULL(itm.uom, '')      AS Uom,
                ISNULL(l.qtyreqd, 0)     AS QtyReqd,
                ISNULL(l.qtyord,  0)     AS QtyOrdered,
                ISNULL(l.qtyrec,  0)     AS QtyReceived,
                l.prstatus               AS PrStatusCode,
                l.secondapp              AS SecondApp,
                div.div_printname        AS DivPrintName,
                div.div_unitname         AS DivUnitName
            FROM dbo.PO_PRH h
            INNER JOIN dbo.PO_PRL l
                ON h.divcode = l.divcode
               AND h.prno    = l.prno
               AND h.prdate  = l.prdate
            LEFT  JOIN dbo.IN_DEP dep
                ON h.depcode = dep.depcode
               AND h.divcode = dep.divcode
            INNER JOIN dbo.PP_DIVMAS div
                ON h.divcode = div.divcode
            INNER JOIN dbo.IN_ITEM itm
                ON l.itemcode = itm.itemcode
            WHERE h.divcode = @DivCode
              AND h.prdate BETWEEN @FromDate AND @ToDate
              AND (@FromDep IS NULL OR h.depcode >= @FromDep)
              AND (@ToDep   IS NULL OR h.depcode <= @ToDep)
            ORDER BY dep.depname, l.prno, l.prdate, l.itemcode, itm.itemname, itm.uom;";

        var rows = (await connection.QueryAsync<DepartmentWiseRow>(
            new CommandDefinition(sql,
                new
                {
                    p.DivCode,
                    p.FromDate,
                    p.ToDate,
                    FromDep = string.IsNullOrWhiteSpace(p.FromDep) ? null : p.FromDep,
                    ToDep   = string.IsNullOrWhiteSpace(p.ToDep)   ? null : p.ToDep,
                },
                cancellationToken: ct))).ToList();

        // Decode the raw status code into the SPINRISE label once, up-front.
        foreach (var row in rows)
            row.PrStatus = PrStatusDescribe.Describe(row.PrStatusCode, row.SecondApp);

        return rows;
    }
}
