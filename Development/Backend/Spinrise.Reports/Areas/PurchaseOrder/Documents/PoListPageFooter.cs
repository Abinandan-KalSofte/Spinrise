using QuestPDF.Elements;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

// Shared page footer for the PO List reports (Date-wise, Supplier-wise, …):
//   • a small top rule across the footer,
//   • "@Kalsofte" at bottom-left,
//   • "Continued..." at bottom-right on every page EXCEPT the last.
//
// Implemented as an IDynamicComponent because "Continued..." must be suppressed on the
// final page, which needs the current page number vs total page count — only available
// in a dynamic context, not in a statically-composed footer.
public sealed class PoListPageFooter : IDynamicComponent<int>
{
    private const string Grey  = "#808080";
    private const string Black = "#000000";

    public int State { get; set; }

    public DynamicComponentComposeResult Compose(DynamicContext context)
    {
        bool hasNext = context.PageNumber < context.TotalPages;

        var content = context.CreateElement(element =>
        {
            element.BorderTop(0.5f).BorderColor(Black).PaddingTop(2).Row(row =>
            {
                row.RelativeItem().Text(t => t.Span("@Kalsofte").FontSize(6.5f).Bold().FontColor(Grey));

                // PaddingRight(0) between AlignRight and Text is deliberate: chaining
                // AlignRight straight into Text inside a dynamic component silently drops
                // the content (QuestPDF quirk, confirmed via isolated repro — GH #930).
                row.RelativeItem().AlignRight().PaddingRight(0).Text(t =>
                {
                    if (hasNext)
                        t.Span("Continued...").FontSize(6.5f).FontColor(Black);
                });
            });
        });

        return new DynamicComponentComposeResult { Content = content, HasMoreContent = false };
    }
}
