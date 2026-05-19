using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

namespace Spinrise.API.Areas.PurchaseOrder.Print;

public static class PrPrintDocument
{
    public static byte[] Generate(PrHeaderDto pr)
    {
        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4.Landscape());
                page.Margin(18, Unit.Point);
                page.DefaultTextStyle(t => t.FontSize(8).FontFamily("Arial"));

                page.Header().Element(ComposeHeader(pr));
                page.Content().Element(ComposeContent(pr));
                page.Footer().AlignRight().Text(t =>
                {
                    t.Span("Page ").FontSize(7).FontColor(Colors.Grey.Medium);
                    t.CurrentPageNumber().FontSize(7).FontColor(Colors.Grey.Medium);
                    t.Span(" of ").FontSize(7).FontColor(Colors.Grey.Medium);
                    t.TotalPages().FontSize(7).FontColor(Colors.Grey.Medium);
                });
            });
        }).GeneratePdf();
    }

    private static Action<IContainer> ComposeHeader(PrHeaderDto pr) => (container) =>
    {
        container.Column(col =>
        {
            // Company + document title row
            col.Item().Row(row =>
            {
                row.RelativeItem().Column(c =>
                {
                    c.Item().Text("SPINRISE ERP").FontSize(14).Bold().FontColor("#1a2236");
                    c.Item().Text("Purchase Requisition").FontSize(10).FontColor(Colors.Grey.Darken2);
                });
                row.ConstantItem(200).AlignRight().Column(c =>
                {
                    c.Item().Text($"PR No: {(long)pr.PrNo:D5}").FontSize(11).Bold();
                    c.Item().Text($"Date: {pr.PrDate:dd-MMM-yyyy}").FontSize(9);
                    c.Item().Text($"Status: {pr.PrStatus}").FontSize(8).FontColor(Colors.Grey.Darken2);
                });
            });

            col.Item().PaddingTop(4).BorderBottom(1).BorderColor(Colors.Grey.Lighten1).Element(_ => { });

            // Info row
            col.Item().PaddingTop(6).Row(row =>
            {
                void InfoCell(RowDescriptor r, string label, string value)
                {
                    r.RelativeItem().Column(c =>
                    {
                        c.Item().Text(label).FontSize(7).FontColor(Colors.Grey.Medium).Bold();
                        c.Item().Text(string.IsNullOrWhiteSpace(value) ? "—" : value).FontSize(8.5f);
                    });
                }

                InfoCell(row, "Division",    pr.DivCode);
                InfoCell(row, "Department",  $"{pr.DepCode} — {pr.DepName}");
                InfoCell(row, "Requested By",!string.IsNullOrWhiteSpace(pr.ReqEmpName) ? pr.ReqEmpName : pr.ReqName);
                InfoCell(row, "Section",     pr.Section);
                InfoCell(row, "Ref. No.",    pr.RefNo);
                InfoCell(row, "Type",        !string.IsNullOrWhiteSpace(pr.IDesc) ? pr.IDesc : pr.IType);
                InfoCell(row, "PO Group",    pr.PoGrp);
            });

            col.Item().PaddingTop(6).BorderBottom(1).BorderColor(Colors.Grey.Lighten1).Element(_ => { });
        });
    };

    private static Action<IContainer> ComposeContent(PrHeaderDto pr) => (container) =>
    {
        container.PaddingTop(8).Table(table =>
        {
            table.ColumnsDefinition(cols =>
            {
                cols.ConstantColumn(18);   // #
                cols.ConstantColumn(62);   // Item Code
                cols.RelativeColumn(3);    // Description
                cols.ConstantColumn(30);   // UOM
                cols.ConstantColumn(64);   // Machine
                cols.ConstantColumn(52);   // Req Qty
                cols.ConstantColumn(64);   // Rate
                cols.ConstantColumn(72);   // Approx Cost
                cols.ConstantColumn(58);   // Req Date
                cols.ConstantColumn(22);   // Sample
                cols.RelativeColumn(2);    // Remarks
            });

            // Header row
            static IContainer HeaderCell(IContainer c) =>
                c.Background("#1e293b").Padding(4).AlignCenter();

            static TextSpanDescriptor HeaderText(TextDescriptor t, string label) =>
                t.Span(label).FontSize(7).Bold().FontColor(Colors.White);

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "#"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Item Code"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Description"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "UOM"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Machine No"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Req. Qty"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Rate"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Approx. Cost"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Req. Date"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "S"));
                h.Cell().Element(HeaderCell).Text(t => HeaderText(t, "Remarks"));
            });

            // Data rows
            for (var i = 0; i < pr.Lines.Count; i++)
            {
                var line = pr.Lines[i];
                var even = i % 2 == 0;

                static IContainer DataCell(IContainer c, bool isEven) =>
                    c.Background(isEven ? Colors.White : "#f8fafc")
                     .BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten2)
                     .Padding(3);

                table.Cell().Element(c => DataCell(c, even)).AlignCenter()
                    .Text((i + 1).ToString()).FontSize(7).FontColor(Colors.Grey.Medium);

                table.Cell().Element(c => DataCell(c, even))
                    .Text(line.ItemCode).FontSize(7.5f).FontFamily("Courier New").Bold();

                table.Cell().Element(c => DataCell(c, even))
                    .Text(line.ItemName).FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignCenter()
                    .Text(line.Uom).FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignCenter()
                    .Text(line.MacNo ?? "—").FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignRight()
                    .Text(line.QtyInd.ToString("N3")).FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignRight()
                    .Text(line.Rate > 0 ? line.Rate.ToString("N4") : "—").FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignRight()
                    .Text(line.AppCost > 0 ? $"₹ {line.AppCost:N2}" : "—").FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignCenter()
                    .Text(line.ReqdDate.HasValue ? line.ReqdDate.Value.ToString("dd-MMM-yy") : "—").FontSize(7.5f);

                table.Cell().Element(c => DataCell(c, even)).AlignCenter()
                    .Text(line.Sample == "Y" ? "✓" : "").FontSize(8f);

                table.Cell().Element(c => DataCell(c, even))
                    .Text(line.Remarks ?? "").FontSize(7f).FontColor(Colors.Grey.Darken2);
            }
        });
    };
}
