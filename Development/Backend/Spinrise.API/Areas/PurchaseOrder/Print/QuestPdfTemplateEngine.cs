using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Spinrise.API.Areas.PurchaseOrder.Print;

public static class QuestPdfTemplateEngine
{
    // ── Company Header ────────────────────────────────────────────────────────────
    public static void RenderHeader(IContainer c, HeaderConfig cfg)
    {
        c.PaddingHorizontal(cfg.InsetMm, Unit.Millimetre)
         .PaddingBottom(cfg.PadBottomMm, Unit.Millimetre)
         .Border(cfg.BorderPt).BorderColor(cfg.BorderColor)
         .Row(row =>
         {
             row.ConstantItem(cfg.Logo.WidthMm, Unit.Millimetre)
                .Padding(2).AlignMiddle().AlignCenter()
                .Element(slot =>
                {
                    if (cfg.Logo.Data is { Length: > 0 })
                        slot.MaxWidth(cfg.Logo.WidthMm, Unit.Millimetre)
                            .MaxHeight(cfg.Logo.MaxHeightMm, Unit.Millimetre)
                            .Image(cfg.Logo.Data).FitArea();
                    else
                        slot.AlignCenter()
                            .Text("LOGO").Bold().FontSize(cfg.CompanyFont.Size).FontColor(cfg.CompanyFont.Color);
                });

             row.ConstantItem(cfg.Logo.GapMm, Unit.Millimetre);

             row.RelativeItem().AlignMiddle().PaddingVertical(3).Column(col =>
             {
                 col.Spacing(2);
                 col.Item().Text(t =>
                 {
                     t.AlignCenter();
                     t.Span(cfg.CompanyName).Bold().FontSize(cfg.CompanyFont.Size).FontColor(cfg.CompanyFont.Color);
                 });
                 col.Item().Text(t =>
                 {
                     t.AlignCenter();
                     t.Span(cfg.UnitName).Bold().FontSize(cfg.UnitFont.Size).FontColor(cfg.UnitFont.Color);
                 });
                 foreach (var line in cfg.AddressLines.Where(l => !string.IsNullOrWhiteSpace(l)))
                     col.Item().Text(t => { t.AlignCenter(); t.Span(line).FontSize(cfg.AddressFont.Size); });
             });
         });
    }

    // ── Info Section ──────────────────────────────────────────────────────────────
    public static void RenderInfoSection(IContainer c, InfoSectionConfig cfg)
    {
        c.PaddingHorizontal(cfg.InsetMm, Unit.Millimetre)
         .Border(cfg.BorderPt).BorderColor(cfg.BorderColor)
         .Column(col =>
         {
             col.Spacing(0);
             col.Item().PaddingVertical(cfg.TitlePadVMm, Unit.Millimetre).Text(t =>
             {
                 t.AlignCenter();
                 t.Span(cfg.Title).Bold().FontSize(cfg.TitleFont.Size).FontColor(cfg.TitleFont.Color);
             });
             col.Item().LineHorizontal(cfg.BorderPt).LineColor(cfg.BorderColor);
             col.Item().Row(row =>
             {
                 RenderPanel(row.ConstantItem(cfg.LeftPanel.WidthMm, Unit.Millimetre), cfg.LeftPanel, cfg.LabelFont, cfg.ValueFont);
                 row.ConstantItem(cfg.DividerMm, Unit.Millimetre).Background(cfg.BorderColor);
                 RenderPanel(row.RelativeItem(), cfg.RightPanel, cfg.LabelFont, cfg.ValueFont);
             });
         });
    }

    private static void RenderPanel(IContainer c, InfoPanelConfig p, StyleFont lbl, StyleFont val)
    {
        c.PaddingLeft(p.IndentMm, Unit.Millimetre)
         .PaddingVertical(p.PadVMm, Unit.Millimetre)
         .Column(col =>
         {
             col.Spacing(p.RowSpacingMm);
             foreach (var r in p.Rows)
                 col.Item().Row(row =>
                 {
                     row.ConstantItem(r.LabelMm, Unit.Millimetre).AlignMiddle()
                        .Text(t =>
                        {
                            t.AlignLeft();
                            var sp = t.Span(r.Label).FontSize(lbl.Size).FontColor(lbl.Color);
                            if (lbl.Bold) sp.Bold();
                        });
                     row.ConstantItem(r.SepMm, Unit.Millimetre).AlignMiddle()
                        .Text(t => { t.AlignCenter(); t.Span(":").FontSize(lbl.Size); });
                     row.RelativeItem().AlignMiddle()
                        .Text(t =>
                        {
                            t.AlignLeft();
                            var sp = t.Span(r.Value).FontSize(val.Size).FontColor(val.Color);
                            if (val.Bold) sp.Bold();
                        });
                 });
         });
    }

    // ── Item Table ────────────────────────────────────────────────────────────────
    public static void RenderTable(IContainer c, TableConfig cfg)
    {
        c.PaddingHorizontal(cfg.InsetMm, Unit.Millimetre)
         .Table(table =>
         {
             table.ColumnsDefinition(cols =>
             {
                 foreach (var col in cfg.Columns)
                     cols.ConstantColumn(col.WidthMm, Unit.Millimetre);
             });

             table.Header(h =>
             {
                 foreach (var th in cfg.Header.Cells)
                     RenderTh(h, th, cfg.Header.Font);
             });

             foreach (var dr in cfg.Rows)
             {
                 foreach (var dc in dr.Cells)
                     RenderDc(table, dc);

                 foreach (var cr in dr.ChildRows)
                     RenderChildRow(table, cr, cfg.EmptyMachCell, cfg.Columns.Count);
             }

             if (cfg.TotalsRow is not null)
                 RenderTotalsRow(table, cfg.TotalsRow);
         });
    }

    private static void RenderTotalsRow(TableDescriptor table, TotalsRowConfig cfg)
    {
        foreach (var cell in cfg.Cells)
        {
            table.Cell()
                 .ColumnSpan(cell.ColumnSpan)
                 .BorderLeft(cfg.BdSidePt).BorderRight(cfg.BdSidePt)
                 .BorderTop(cfg.BdSidePt).BorderBottom(cfg.BdSidePt)
                 .BorderColor(cfg.BdColor)
                 .Background(cfg.BgColor)
                 .MinHeight(cfg.MinHeightMm, Unit.Millimetre)
                 .PaddingVertical(cell.PadV).PaddingLeft(cell.PadH).PaddingRight(cell.PadR)
                 .Text(t =>
                 {
                     switch (cell.Align)
                     {
                         case DA.Center: t.AlignCenter(); break;
                         case DA.Right:  t.AlignRight();  break;
                         default:        t.AlignLeft();   break;
                     }
                     var sp = t.Span(cell.Text).FontSize(cfg.FontSizePt);
                     if (cell.Bold) sp.Bold();
                     if (cell.Color is not null) sp.FontColor(cell.Color);
                 });
        }
    }

    // RowSpan/ColumnSpan MUST be called before any border/padding.
    private static void RenderTh(TableCellDescriptor h, ThCellConfig cfg, StyleFont font)
    {
        IContainer c = h.Cell().RowSpan(cfg.RowSpan).ColumnSpan(cfg.ColSpan);

        if (cfg.BdTop.HasValue)    c = c.BorderTop(cfg.BdTop.Value);
        if (cfg.BdRight.HasValue)  c = c.BorderRight(cfg.BdRight.Value);
        if (cfg.BdBottom.HasValue) c = c.BorderBottom(cfg.BdBottom.Value);
        if (cfg.BdLeft.HasValue)   c = c.BorderLeft(cfg.BdLeft.Value);

        c.BorderColor(cfg.BdColor)
         .Background("#F2F2F2")
         .PaddingVertical(cfg.PadV).PaddingHorizontal(cfg.PadH)
         .DefaultTextStyle(x => x.Bold().FontSize(font.Size).FontColor(font.Color))
         .Text(t => { t.AlignCenter(); t.Span(cfg.Text); });
    }

    private static void RenderDc(TableDescriptor table, DcCellConfig cfg)
    {
        table.Cell()
            .BorderLeft(cfg.BdSidePt).BorderRight(cfg.BdSidePt)
            .BorderColor(cfg.BdColor)
            .Background("#FFFFFF")
            .MinHeight(cfg.MinHeightMm, Unit.Millimetre)
            .PaddingVertical(cfg.PadV).PaddingLeft(cfg.PadH).PaddingRight(cfg.PadR)
            .Text(t =>
            {
                switch (cfg.Align)
                {
                    case DA.Center: t.AlignCenter(); break;
                    case DA.Right:  t.AlignRight();  break;
                    default:        t.AlignLeft();   break;
                }
                var sp = t.Span(cfg.Text).FontSize(cfg.FontSizePt);
                if (cfg.FontFamily is not null) sp.FontFamily(cfg.FontFamily);
            });
    }

    private static void RenderMach(TableDescriptor table, MachCellConfig cfg)
    {
        table.Cell()
             .BorderLeft(cfg.BdSidePt).BorderRight(cfg.BdSidePt)
             .BorderColor(cfg.BdColor)
             .Background("#FFFFFF")
             .MinHeight(cfg.MinHeightMm, Unit.Millimetre)
             .PaddingVertical(cfg.PadV).PaddingHorizontal(cfg.PadH);
    }

    // Col 0,1 → empty  |  Col 2 → label text  |  Col 3..N → empty
    private static void RenderChildRow(TableDescriptor table, ChildRowConfig cfg, MachCellConfig mach, int totalCols)
    {
        RenderMach(table, mach);   // col 0
        RenderMach(table, mach);   // col 1

        table.Cell()
             .BorderLeft(mach.BdSidePt).BorderRight(mach.BdSidePt)
             .BorderColor(mach.BdColor)
             .Background("#FFFFFF")
             .MinHeight(mach.MinHeightMm, Unit.Millimetre)
             .PaddingVertical(mach.PadV).PaddingHorizontal(mach.PadH)
             .Text(t => { t.AlignLeft(); t.Span(cfg.LabelText).FontSize(cfg.FontSizePt); });

        for (int i = 3; i < totalCols; i++)
            RenderMach(table, mach);
    }

    // ── Signature ─────────────────────────────────────────────────────────────────
    public static void RenderSignature(IContainer c, SignatureConfig cfg)
    {
        c.PaddingHorizontal(cfg.InsetMm, Unit.Millimetre)
         .Border(cfg.BorderPt).BorderColor(cfg.BorderColor)
         .MinHeight(cfg.MinHeightMm, Unit.Millimetre)
         .Row(row =>
         {
             foreach (var blk in cfg.Blocks)
             {
                 IContainer cell = row.RelativeItem();
                 if (blk.RightBorder)
                     cell = cell.BorderRight(cfg.BorderPt).BorderColor(cfg.BorderColor);

                 cell.PaddingTop(blk.PadV).PaddingBottom(4f).PaddingHorizontal(blk.PadH)
                     .Column(col =>
                     {
                         col.Spacing(2);
                         col.Item().Text(t =>
                         {
                             t.AlignCenter();
                             t.Span(blk.Title).Bold().FontSize(cfg.Font.Size);
                         });
                         col.Item().Height(blk.NamePadTop);
                         if (!string.IsNullOrEmpty(blk.Name))
                             col.Item().Text(t =>
                             {
                                 t.AlignCenter();
                                 t.Span(blk.Name).FontSize(cfg.Font.Size);
                             });
                         if (!string.IsNullOrEmpty(blk.Date))
                             col.Item().Text(t =>
                             {
                                 t.AlignCenter();
                                 t.Span(blk.Date).FontSize(cfg.Font.Size);
                             });
                     });
             }
         });
    }
}
