using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace SpinRise.QuestPDF.ItemWise;

/// <summary>
/// QuestPDF document for the Item-Wise PR report — a faithful 1:1 reproduction of the original
/// Crystal Reports <c>ItemWise.rpt</c> layout (verified against the customer's PDF export).
///
/// Implementation note: the body is a single 9-column <c>Table</c> with NO column spans. QuestPDF
/// keeps column widths exact only when every row has one cell per column; partial <c>ColumnSpan</c>
/// cells make its width solver redistribute space and break alignment. The Crystal "stacked" look
/// (Item Code above PR No above Dept Code, etc.) is produced by emitting three table rows per
/// record and using per-cell left padding for the indents.
///
/// Layout (Crystal-exact):
///  • Tahoma; title 11pt, unit 9pt, body 8pt.
///  • Centred title block: DIV_PRINTNAME, then "(Unit - DIV_UNITNAME)".
///  • Sub-header: "Purchase Requisition List From .. To .." (maroon) | "Option : Item wise"
///    (teal) | date · time · "Page X of Y" (black).
///  • Three-line stacked detail record:
///       line 1 — Item Code · Item Description                            (item fields green)
///       line 2 — PR. No. · PR. Date · Ref. No.
///       line 3 — Dept.Code · Department Name · Unit · Required · Ordered · Received
///                · Required Date · Remarks · Status
///  • Purple column headers, green item code/name, black detail text (NO status colour-coding).
///  • One Grand Total (Required / Ordered / Received) in purple — no per-item subtotals.
///  • Thin rules under sub-header, under column headers, under each record, under the total.
///  • "@Kalsofte" grey footer. Dates render dd/MM/yy.
/// </summary>
public sealed class ItemWiseDocument : IDocument
{
    // ---- Crystal palette ------------------------------------------------------------------
    private const string Navy   = "#000080";
    private const string Maroon = "#800000";
    private const string Teal   = "#008080";
    private const string Purple = "#800080";
    private const string Green  = "#008000";
    private const string Black  = "#000000";
    private const string Grey   = "#808080";
    private const string Font   = "Tahoma";
    private const string QtyFmt = "#,##0.000";

    private const float Indent = 30f;  // PR No / Dept Code indent under Item Code

    // ---- Column widths (pt) — shared by the table grid and the record segments. Sum = 813.
    private const float W1 = 90;    // Item Code / PR No / Dept Code
    private const float W2 = 186;   // Item Desc / PR Date / Dept Name
    private const float W3 = 63;    // Ref No / Unit
    private const float W4 = 64;    // Required Quantity
    private const float W5 = 70;    // Ordered Quantity
    private const float W6 = 70;    // Received Quantity
    private const float W7 = 52;    // Required Date
    private const float W8 = 114;   // Remarks
    private const float W9 = 104;   // Status

    private readonly IReadOnlyList<ItemWiseRow> _rows;
    private readonly ItemWiseParameters _parameters;
    private readonly string _printName;
    private readonly string _unitName;

    public ItemWiseDocument(IReadOnlyList<ItemWiseRow> rows, ItemWiseParameters parameters)
    {
        _rows = rows;
        _parameters = parameters;
        _printName = rows.Select(r => r.DivPrintName)
                         .Concat(rows.Select(r => r.DivName))
                         .FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => new()
    {
        Title  = "Purchase Requisition Report - Item Wise",
        Author = "SpinRise",
    };

    public void Compose(IDocumentContainer container)
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.MarginTop(10);
            page.MarginBottom(8);
            page.MarginLeft(17);
            page.MarginRight(11);
            page.DefaultTextStyle(t => t.FontFamily(Font).FontSize(8).FontColor(Black));

            page.Header().Element(ComposeTitle);
            page.Content().Element(ComposeContent);
            page.Footer().Element(ComposeFooter);
        });
    }

    // -------------------------------------------------------------------------- Title ------
    private void ComposeTitle(IContainer container)
    {
        container.Column(col =>
        {
            col.Item().Text(t => { t.AlignCenter(); t.Span(_printName).FontFamily(Font).FontSize(11).Bold().FontColor(Navy); });
            if (!string.IsNullOrWhiteSpace(_unitName))
                col.Item().Text(t => { t.AlignCenter(); t.Span(FormatUnit(_unitName)).FontFamily(Font).FontSize(9).Bold().FontColor(Navy); });

            // Period (left) + printed date/time/page (right) on the base row; "Option : Item wise"
            // is overlaid on a centred layer so it sits at the true page centre regardless of the
            // flanking text widths. Text-level alignment keeps the right block from overflowing.
            col.Item().PaddingTop(4).Layers(layers =>
            {
                layers.PrimaryLayer().Row(r =>
                {
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignLeft();
                        t.Span($"Purchase Requisition List  From {_parameters.FromDate:dd/MM/yy} To {_parameters.ToDate:dd/MM/yy}")
                         .FontSize(10).Bold().FontColor(Maroon);
                    });
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignRight();
                        t.DefaultTextStyle(x => x.FontSize(8).FontColor(Black));
                        var now = DateTime.Now;
                        t.Span($"{now:dd/MM/yy}     {now:h:mm:ss tt}     Page ");
                        t.CurrentPageNumber();
                        t.Span(" of ");
                        t.TotalPages();
                    });
                });
                layers.Layer().AlignMiddle().Text(t =>
                {
                    t.AlignCenter();
                    t.Span("Option : Item wise").FontSize(8).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(3).LineHorizontal(0.75f).LineColor(Black);
        });
    }

    // -------------------------------------------------------------------------- Content ----
    private void ComposeContent(IContainer container)
    {
        if (_rows.Count == 0)
        {
            container.PaddingVertical(20).AlignCenter()
                .Text("No purchase requisitions found for the selected criteria.")
                .Bold().FontColor(Navy);
            return;
        }

        var ordered = _rows
            .OrderBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => ParsePrNo(r.IndentNo))
            .ThenBy(r => r.IndentDt)
            .ToList();

        decimal totReqd = ordered.Sum(r => r.QtyReqd ?? 0m);
        decimal totOrd  = ordered.Sum(r => r.QtyOrd  ?? 0m);
        decimal totRec  = ordered.Sum(r => r.QtyRec  ?? 0m);

        container.Table(table =>
        {
            // 9 columns — hard widths (ConstantColumn) so a long value never grows a column and
            // shifts the grid. Header and total rows use these columns; each detail record is a
            // single full-span cell whose nested segments use the SAME widths, which (a) keeps
            // the x-grid identical and (b) makes the record atomic — its two lines can never be
            // separated by a page break (the defect QA observed as lines "merging" into totals).
            table.ColumnsDefinition(c =>
            {
                c.ConstantColumn(W1);
                c.ConstantColumn(W2);
                c.ConstantColumn(W3);
                c.ConstantColumn(W4);
                c.ConstantColumn(W5);
                c.ConstantColumn(W6);
                c.ConstantColumn(W7);
                c.ConstantColumn(W8);
                c.ConstantColumn(W9);
            });

            // ---- Repeating column header (3 stacked lines, purple) -----------------------
            // Full column names — QA directive 7 June (no abbreviations). The quantity labels
            // wrap to two lines inside their columns; data alignment is unaffected.
            table.Header(h =>
            {
                // line 1
                HCell(h, "Item Code");
                HCell(h, "Item Description");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                // line 2
                HCell(h, "PR. No.", padL: Indent);
                HCell(h, "PR. Date");
                HCell(h, "Ref. No.");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "");
                HCell(h, "Remarks");
                HCell(h, "Status", Align.Center);
                // line 3
                HCell(h, "Dept.Code", padL: Indent);
                HCell(h, "Department Name");
                HCell(h, "Unit", Align.Right);
                HCell(h, "Required Quantity", Align.Right);
                HCell(h, "Ordered Quantity", Align.Right);
                HCell(h, "Received Quantity", Align.Right, padR: 8);
                HCell(h, "Required Date", Align.Center);
                HCell(h, "");
                HCell(h, "");

                // One continuous rule under the whole header block — a single full line, not
                // per-column segments (whose differing cell heights read as a broken line).
                h.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
            });

            // ---- Item groups: green header (once) · PR lines · purple Item Total ----------
            // Grouping key is trimmed + case-insensitive so a code stored with different casing
            // or padding can never split into two groups. The header line is rendered INSIDE the
            // first record's atomic cell, so it can never be orphaned at a page bottom.
            foreach (var g in ordered.GroupBy(r => (r.ItemCode ?? "").Trim().ToUpperInvariant()))
            {
                decimal iReqd = 0, iOrd = 0, iRec = 0;
                bool firstRecord = true;
                int recordCount = 0;
                foreach (var r in g)
                {
                    RecordCell(table, r, withItemHeader: firstRecord);
                    firstRecord = false;
                    recordCount++;

                    iReqd += r.QtyReqd ?? 0m;
                    iOrd  += r.QtyOrd  ?? 0m;
                    iRec  += r.QtyRec  ?? 0m;
                }

                // Item Total — only when the item has 2+ records (single-record items already
                // show the qty on the detail line, so a subtotal would just duplicate it).
                if (recordCount >= 2)
                {
                    table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
                    TotalRow(table, "Item Total", iReqd, iOrd, iRec);
                }
            }

            // ---- Grand Total (overall sum across all items) ------------------------------
            table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
            TotalRow(table, "Grand Total", totReqd, totOrd, totRec);

            // Closing line at the end of the report.
            table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
        });
    }

    // ---- Cell helpers ----------------------------------------------------------------------
    private enum Align { Left, Center, Right }

    private static void HCell(TableCellDescriptor h, string text, Align align = Align.Left,
                              float padL = 2, float padR = 2)
    {
        h.Cell().PaddingLeft(padL).PaddingRight(padR).PaddingVertical(1)
         .Text(t => { ApplyAlign(t, align); t.Span(text).FontFamily(Font).FontSize(8).Bold().FontColor(Purple); });
    }

    /// <summary>
    /// One PR record as a single full-span, atomic cell (ShowEntire): the optional green item
    /// header line, then line A (PR No · PR Date · Ref No), then line B
    /// (Dept Code · Dept Name · Unit · quantities · Required Date · Remarks · Status).
    /// </summary>
    private static void RecordCell(TableDescriptor table, ItemWiseRow r, bool withItemHeader)
    {
        table.Cell().ColumnSpan(9).ShowEntire().PaddingBottom(3).Column(col =>
        {
            if (withItemHeader)
            {
                col.Item().PaddingTop(3).Row(row =>
                {
                    Seg(row, W1, (r.ItemCode ?? "").Trim(), GreenStyle);
                    Seg(row, W2 + W3 + W4 + W5 + W6 + W7 + W8 + W9, r.ItemName, GreenStyle);
                });
            }

            col.Item().PaddingTop(1).Row(row =>
            {
                Seg(row, W1, r.IndentNo, BodyStyle, Align.Left, padL: Indent);
                Seg(row, W2, r.IndentDt?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "", BodyStyle);
                Seg(row, W3, r.RefNo ?? "", BodyStyle);
                Seg(row, W4 + W5 + W6 + W7 + W8 + W9, "", BodyStyle);
            });

            col.Item().PaddingTop(1).Row(row =>
            {
                Seg(row, W1, r.DepCode ?? "", BodyStyle, Align.Left, padL: Indent);
                Seg(row, W2, r.DepName ?? "", BodyStyle);
                Seg(row, W3, r.Unit ?? "", BodyStyle, Align.Right);
                Seg(row, W4, (r.QtyReqd ?? 0m).ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                Seg(row, W5, (r.QtyOrd  ?? 0m).ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                Seg(row, W6, (r.QtyRec  ?? 0m).ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right, padR: 8);
                Seg(row, W7, r.ReqdDate?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "", BodyStyle, Align.Left, padL: 6);
                Seg(row, W8, r.Remarks ?? "", BodyStyle);
                Seg(row, W9, r.PrStatus, BodyStyle);
            });
        });
    }

    /// <summary>A fixed-width segment inside a record line. Text-level alignment only.</summary>
    private static void Seg(RowDescriptor row, float width, string text,
                            Action<TextSpanDescriptor> style, Align align = Align.Left,
                            float padL = 2, float padR = 2)
    {
        row.ConstantItem(width).PaddingLeft(padL).PaddingRight(padR)
           .Text(t => { ApplyAlign(t, align); var s = t.Span(text); style(s); });
    }

    /// <summary>A purple subtotal/total band: label in c2, the three sums under the qty columns.
    /// Borderless — the surrounding code emits a single full-width rule above/below so the line
    /// is continuous instead of being assembled from per-cell border segments (which read as
    /// "dotted" wherever cell padding leaves gaps).</summary>
    private static void TotalRow(TableDescriptor table, string label, decimal req, decimal ord, decimal rec)
    {
        PCell(table, "", Align.Left);                                                       // c1
        PCell(table, label, Align.Right);                                                   // c2
        PCell(table, "", Align.Left);                                                       // c3
        PCell(table, req.ToString(QtyFmt, CultureInfo.InvariantCulture), Align.Right);      // c4
        PCell(table, ord.ToString(QtyFmt, CultureInfo.InvariantCulture), Align.Right);      // c5
        PCell(table, rec.ToString(QtyFmt, CultureInfo.InvariantCulture), Align.Right, 8);   // c6
        PCell(table, "", Align.Left);                                                       // c7
        PCell(table, "", Align.Left);                                                       // c8
        PCell(table, "", Align.Left);                                                       // c9
    }

    private static void PCell(TableDescriptor table, string text, Align align, float padR = 2)
    {
        table.Cell().PaddingLeft(2).PaddingRight(padR).PaddingVertical(2)
             .Text(t => { ApplyAlign(t, align); t.Span(text).FontFamily(Font).FontSize(8).Bold().FontColor(Purple); });
    }

    private static void ApplyAlign(TextDescriptor t, Align a)
    {
        if (a == Align.Right) t.AlignRight();
        else if (a == Align.Center) t.AlignCenter();
        else t.AlignLeft();
    }

    private static void GreenStyle(TextSpanDescriptor s) => s.FontFamily(Font).FontSize(8).Bold().FontColor(Green);
    private static void BodyStyle(TextSpanDescriptor s)  => s.FontFamily(Font).FontSize(8).FontColor(Black);

    private static int ParsePrNo(string? prNo) =>
        int.TryParse(prNo, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;

    private static string FormatUnit(string unit)
    {
        var u = unit.Trim();
        return u.StartsWith("(Unit", StringComparison.OrdinalIgnoreCase) ? u : $"(Unit - {u})";
    }

    // -------------------------------------------------------------------------- Footer -----
    private static void ComposeFooter(IContainer container)
    {
        container.Text(t => t.Span("@Kalsofte").FontFamily(Font).FontSize(8).Bold().FontColor(Grey));
    }
}
