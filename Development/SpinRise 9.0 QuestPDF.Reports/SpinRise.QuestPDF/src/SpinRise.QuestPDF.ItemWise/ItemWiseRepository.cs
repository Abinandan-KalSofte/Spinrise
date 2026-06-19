using Dapper;
using SpinRise.QuestPDF.Common.Data;

namespace SpinRise.QuestPDF.ItemWise;

/// <summary>
/// Data access for the Item-Wise PR report. Replicates the <c>KSP_PR_ITEMWISE</c> stored
/// procedure as an inline query so the report has no SP-deployment / <c>dbo.split</c>
/// dependency — it only needs the base tables (PO_PRH, PO_PRL, IN_DEP, PP_DIVMAS, IN_ITEM),
/// which is the same proven approach used by the Department-Wise report.
/// <para>
/// Joins mirror the SP exactly: PO_PRH LEFT JOIN IN_DEP, INNER JOIN PP_DIVMAS,
/// INNER JOIN PO_PRL, LEFT JOIN IN_ITEM (softened from the SP's INNER for resilience when an
/// item master row is missing). The item filter follows the SP's @FITEM convention:
/// "A" = all items, otherwise a CSV of item codes.
/// </para>
/// </summary>
public sealed class ItemWiseRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public ItemWiseRepository(IDbConnectionFactory connectionFactory)
        => _connectionFactory = connectionFactory;

    public async Task<IReadOnlyList<ItemWiseRow>> GetRowsAsync(
        ItemWiseParameters p, CancellationToken ct = default)
    {
        using var connection = _connectionFactory.Create();

        var allItems = string.IsNullOrWhiteSpace(p.ItemFilter)
                       || string.Equals(p.ItemFilter.Trim(), "A", StringComparison.OrdinalIgnoreCase);

        var itemCodes = allItems
            ? Array.Empty<string>()
            : p.ItemFilter.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        const string sql = @"
            SELECT
                l.itemcode                AS ItemCode,
                ISNULL(itm.itemname, '')  AS ItemName,
                l.prno                    AS IndentNo,
                l.prdate                  AS IndentDt,
                ISNULL(dep.depname, '')   AS DepName,
                dep.depcode               AS DepCode,
                div.divname               AS DivName,
                div.div_printname         AS DivPrintName,
                div.div_unitname          AS DivUnitName,
                ISNULL(itm.uom, '')       AS Unit,
                ISNULL(l.qtyreqd, 0)      AS QtyReqd,
                ISNULL(l.qtyord,  0)      AS QtyOrd,
                ISNULL(l.qtyrec,  0)      AS QtyRec,
                l.prstatus                AS PrStatusCode,
                l.secondapp               AS SecondApp,
                h.refno                   AS RefNo,
                l.remarks                 AS Remarks,
                l.reqddate                AS ReqdDate,
                h.placeofiss              AS PlaceOfIss
            FROM dbo.PO_PRH h
            LEFT  JOIN dbo.IN_DEP dep
                ON h.depcode = dep.depcode
               AND h.divcode = dep.divcode
            INNER JOIN dbo.PP_DIVMAS div
                ON h.divcode = div.divcode
            INNER JOIN dbo.PO_PRL l
                ON h.divcode = l.divcode
               AND h.prno    = l.prno
               AND h.prdate  = l.prdate
            LEFT  JOIN dbo.IN_ITEM itm
                ON l.itemcode = itm.itemcode
            WHERE h.divcode = @DivCode
              AND h.prdate BETWEEN @FromDate AND @ToDate
              AND (@AllItems = 1 OR l.itemcode IN @ItemCodes)
            ORDER BY itm.itemname, l.itemcode, l.prdate, l.prno;";

        var rows = (await connection.QueryAsync<ItemWiseRow>(
            new CommandDefinition(sql,
                new
                {
                    p.DivCode,
                    p.FromDate,
                    p.ToDate,
                    AllItems  = allItems ? 1 : 0,
                    ItemCodes = itemCodes.Length == 0 ? new[] { "\0" } : itemCodes,
                },
                cancellationToken: ct))).ToList();

        // Decode the raw status code to the SPINRISE label once, up-front.
        foreach (var row in rows)
            row.PrStatus = PrStatusDescribe.Describe(row.PrStatusCode);

        return rows;
    }
}
