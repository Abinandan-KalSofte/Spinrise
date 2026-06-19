using Dapper;
using SpinRise.QuestPDF.Common.Data;

namespace SpinRise.QuestPDF.DateWise;

/// <summary>
/// Data access for the Date-Wise PR report. Replicates the <c>KSP_PR_DateWise</c> stored
/// procedure as an inline query (no SP-deployment dependency), using the same base tables.
/// <para>
/// Joins mirror the SP: PO_PRH INNER PO_PRL, LEFT IN_DEP, INNER PP_DIVMAS, INNER IN_ITEM.
/// The SP declares @Divcode/@FromDate/@ToDate/@FrmDep/@ToDep but its body applies no WHERE —
/// the record selection lived in the Crystal report. It is applied here as the report
/// intends: division + PR-date window + department range.
/// <c>ISNULL</c> is applied on every quantity so the renderer never sees a null.
/// </para>
/// </summary>
public sealed class DateWiseRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public DateWiseRepository(IDbConnectionFactory connectionFactory)
        => _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<DateWiseRow>> GetRowsAsync(
        DateWiseParameters p, CancellationToken ct = default)
    {
        using var connection = _connectionFactory.Create();

        const string sql = @"
            SELECT
                h.prdate                 AS PrDate,
                l.prno                   AS PrNo,
                l.itemcode               AS ItemCode,
                ISNULL(itm.itemname,'')  AS ItemName,
                ISNULL(itm.uom, '')      AS Uom,
                ISNULL(dep.depname, '')  AS DepName,
                ISNULL(l.qtyind,  0)     AS QtyIndent,
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
            ORDER BY h.prdate, l.prno, l.itemcode;";

        var rows = (await connection.QueryAsync<DateWiseRow>(
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
