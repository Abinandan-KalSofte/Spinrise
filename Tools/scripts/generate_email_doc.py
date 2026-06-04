"""
Generates the FSD Compliance Email Word document for M01 PR module.
Run: python generate_email_doc.py
Output: D:\SpinriseV2\Docs\SpinriseV2_M01_FSD_Compliance_Email.docx
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import datetime

OUTPUT = r"D:\SpinriseV2\Docs\SpinriseV2_M01_FSD_Compliance_Email.docx"

# ── Colour palette ────────────────────────────────────────────────────────────
DARK_NAVY   = RGBColor(0x1e, 0x29, 0x3b)
BLUE        = RGBColor(0x18, 0x5F, 0xA5)
RED         = RGBColor(0xC0, 0x39, 0x2B)
AMBER       = RGBColor(0xD9, 0x7D, 0x06)
GREEN       = RGBColor(0x06, 0x5F, 0x46)
GRAY        = RGBColor(0x64, 0x74, 0x8B)
LIGHT_BLUE  = RGBColor(0xDB, 0xEA, 0xFE)
LIGHT_RED   = RGBColor(0xFE, 0xE2, 0xE2)
LIGHT_AMBER = RGBColor(0xFE, 0xF3, 0xC7)
LIGHT_GREEN = RGBColor(0xD1, 0xFA, 0xE5)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)


# ── Helpers ───────────────────────────────────────────────────────────────────

def set_cell_bg(cell, rgb: RGBColor):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement("w:shd")
    shd.set(qn("w:val"),   "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"),  f"{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}")
    tcPr.append(shd)


def set_cell_border(cell, color="AAAAAA", size="4"):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement("w:tcBorders")
    for side in ("top", "left", "bottom", "right"):
        border = OxmlElement(f"w:{side}")
        border.set(qn("w:val"),   "single")
        border.set(qn("w:sz"),    size)
        border.set(qn("w:space"), "0")
        border.set(qn("w:color"), color)
        tcBorders.append(border)
    tcPr.append(tcBorders)


def add_para(doc, text="", bold=False, size=10, color=None,
             align=WD_ALIGN_PARAGRAPH.LEFT, space_before=0, space_after=4,
             italic=False):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(space_before)
    p.paragraph_format.space_after  = Pt(space_after)
    p.alignment = align
    if text:
        run = p.add_run(text)
        run.bold   = bold
        run.italic = italic
        run.font.size = Pt(size)
        if color:
            run.font.color.rgb = color
    return p


def add_section_heading(doc, title, color=DARK_NAVY):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after  = Pt(2)
    run = p.add_run(title)
    run.bold = True
    run.font.size = Pt(11)
    run.font.color.rgb = color
    # Bottom border
    pPr  = p._p.get_or_add_pPr()
    pBdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"),   "single")
    bottom.set(qn("w:sz"),    "6")
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), f"{color[0]:02X}{color[1]:02X}{color[2]:02X}")
    pBdr.append(bottom)
    pPr.append(pBdr)
    return p


def add_bullet(doc, text, bold_prefix=None, color=None, indent=0.3):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_before = Pt(1)
    p.paragraph_format.space_after  = Pt(1)
    p.paragraph_format.left_indent  = Inches(indent)
    if bold_prefix:
        r1 = p.add_run(bold_prefix + " ")
        r1.bold = True
        r1.font.size = Pt(9.5)
        if color:
            r1.font.color.rgb = color
    r2 = p.add_run(text)
    r2.font.size = Pt(9.5)
    return p


def make_table(doc, headers, rows, header_bg=DARK_NAVY, col_widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.LEFT

    # Header row
    hdr = table.rows[0]
    for i, h in enumerate(headers):
        cell = hdr.cells[i]
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        set_cell_bg(cell, header_bg)
        set_cell_border(cell, "1E293B")
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after  = Pt(2)
        run = p.add_run(h)
        run.bold = True
        run.font.size = Pt(8.5)
        run.font.color.rgb = WHITE

    # Data rows
    for row_data in rows:
        row = table.add_row()
        bg  = row_data.get("_bg", None)
        for i, val in enumerate(row_data.get("cells", [])):
            cell = row.cells[i]
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            if bg:
                set_cell_bg(cell, bg)
            set_cell_border(cell, "CCCCCC", "2")
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after  = Pt(2)

            if isinstance(val, dict):
                run = p.add_run(val.get("text", ""))
                run.bold = val.get("bold", False)
                run.font.size = Pt(8.5)
                if val.get("color"):
                    run.font.color.rgb = val["color"]
            else:
                run = p.add_run(str(val))
                run.font.size = Pt(8.5)

    # Column widths
    if col_widths:
        for i, width in enumerate(col_widths):
            for row in table.rows:
                row.cells[i].width = Cm(width)

    return table


# ── Document ──────────────────────────────────────────────────────────────────

doc = Document()

# Page margins
for section in doc.sections:
    section.top_margin    = Cm(2.0)
    section.bottom_margin = Cm(2.0)
    section.left_margin   = Cm(2.5)
    section.right_margin  = Cm(2.5)

# Default font
doc.styles["Normal"].font.name = "Calibri"
doc.styles["Normal"].font.size = Pt(10)


# ── Email Header Block ────────────────────────────────────────────────────────

table = doc.add_table(rows=1, cols=1)
table.style = "Table Grid"
hdr_cell = table.rows[0].cells[0]
set_cell_bg(hdr_cell, DARK_NAVY)
set_cell_border(hdr_cell, "1E293B")
p = hdr_cell.paragraphs[0]
p.alignment = WD_ALIGN_PARAGRAPH.LEFT
p.paragraph_format.space_before = Pt(6)
p.paragraph_format.space_after  = Pt(6)
run = p.add_run("SPINRISE ERP V2  —  M01 Purchase Requisition Module")
run.bold = True
run.font.size = Pt(13)
run.font.color.rgb = WHITE

doc.add_paragraph()

# Email fields
fields = [
    ("To",       "Mr. CEO, Kalsofte Pvt. Ltd.  (ceo@kalsofte.com)"),
    ("From",     "Abinandan N, Development Team  (abinandan.n@kalsofte.com)"),
    ("Date",     datetime.date.today().strftime("%d %B %Y")),
    ("Subject",  "M01 PR Module — FSD Compliance Summary, Intentional Changes & Open Decision Points"),
    ("Priority", "High"),
]

meta = doc.add_table(rows=len(fields), cols=2)
meta.style = "Table Grid"
for i, (label, value) in enumerate(fields):
    lc = meta.rows[i].cells[0]
    vc = meta.rows[i].cells[1]
    set_cell_bg(lc, RGBColor(0xF1, 0xF5, 0xF9))
    set_cell_border(lc, "CBD5E1", "2")
    set_cell_border(vc, "CBD5E1", "2")
    lc.width = Cm(3.5)
    vc.width = Cm(13.5)

    lp = lc.paragraphs[0]
    lp.paragraph_format.space_before = Pt(2)
    lp.paragraph_format.space_after  = Pt(2)
    lr = lp.add_run(label)
    lr.bold = True
    lr.font.size = Pt(9.5)
    lr.font.color.rgb = DARK_NAVY

    vp = vc.paragraphs[0]
    vp.paragraph_format.space_before = Pt(2)
    vp.paragraph_format.space_after  = Pt(2)
    vr = vp.add_run(value)
    vr.font.size = Pt(9.5)
    if label == "Subject":
        vr.bold = True
    if label == "Priority":
        vr.font.color.rgb = RED
        vr.bold = True

doc.add_paragraph()


# ── Opening ───────────────────────────────────────────────────────────────────

add_para(doc, "Dear Sir,", bold=False, size=10, space_before=2, space_after=6)

add_para(doc,
    "This document provides a comprehensive summary of the M01 Purchase Requisition (PR) module "
    "development under SPINRISE ERP V2. It covers all points where the implemented solution "
    "deviates from the approved FSD — including intentional design decisions, open gaps, "
    "defects fixed, and enhancements added beyond scope — so that this record serves as "
    "the single source of reference going forward.",
    size=10, space_after=4)

add_para(doc,
    "This communication is intended to avoid repeated clarification emails and to formally "
    "document the current state of the module for your review and sign-off.",
    size=10, space_after=8)


# ── Section 1: Decisions Required ────────────────────────────────────────────

add_section_heading(doc, "1.  DECISIONS REQUIRED FROM CEO  (High Priority)", RED)
add_para(doc,
    "The following three items carry actual data or business risk and require your decision "
    "before the approval workflow goes live.",
    size=10, space_before=4, space_after=4)

decisions = [
    {
        "cells": [
            {"text": "#",       "bold": True, "color": WHITE},
            {"text": "Issue",   "bold": True, "color": WHITE},
            {"text": "FSD Rule","bold": True, "color": WHITE},
            {"text": "Risk",    "bold": True, "color": WHITE},
            {"text": "Decision Needed", "bold": True, "color": WHITE},
        ],
        "_header": True
    },
    {
        "cells": [
            {"text": "D1", "bold": True, "color": RED},
            "Approval data destroyed on Modify — all approval records (FirstApp, SecondApp, approver names) wiped if a partially-approved PR is modified. FSD recommends delta update + Modify block when approved.",
            "FSD Rec #3 / Section 5.5a",
            {"text": "HIGH", "bold": True, "color": RED},
            "Should Modify be blocked once any approval level is set? Or should a warning be shown and approval reset?",
        ],
        "_bg": LIGHT_RED,
    },
    {
        "cells": [
            {"text": "D2", "bold": True, "color": AMBER},
            "No pending order warning — when a user raises a PR for an item that already has an open PO, no warning is shown. VB6 used a hard stop.",
            "FSD Rec #8 / Section 4.4 (PendingOrderPara)",
            {"text": "MEDIUM", "bold": True, "color": AMBER},
            "Should this be a hard stop or a dismissable warning modal? FSD Rec #8 recommends modal (warning-only).",
        ],
        "_bg": LIGHT_AMBER,
    },
    {
        "cells": [
            {"text": "D3", "bold": True, "color": AMBER},
            "Rate Source selector not in UI — users cannot choose Average Rate from the item line. LPO Rate is always auto-filled. Only Manual rate is supported at save, but user must know to override.",
            "CEO R2.0 #14 / FSD Section 5.4",
            {"text": "MEDIUM", "bold": True, "color": AMBER},
            "Should a 3-option selector (LPO / Average / Manual) be added to each item line? Or is LPO default acceptable?",
        ],
        "_bg": LIGHT_AMBER,
    },
]

make_table(
    doc,
    ["#", "Issue", "FSD Rule", "Risk", "Decision Needed"],
    [d for d in decisions if not d.get("_header")],
    col_widths=[1.0, 5.5, 2.5, 1.5, 4.5],
)
doc.add_paragraph()


# ── Section 2: Intentional Changes ───────────────────────────────────────────

add_section_heading(doc, "2.  INTENTIONAL CHANGES FROM FSD  (By Design — Approved)", GREEN)
add_para(doc,
    "The following items were consciously changed during migration. These are not defects — "
    "they are either covered by FSD amendments, platform changes, or explicit migration decisions.",
    size=10, space_before=4, space_after=4)

intentional = [
    ["1", "Sub-Cost Centre field on PR form", "Removed from UI; DB column retained for legacy data", "FSD Amendment F-05 explicitly closed this field"],
    ["2", "Scope Code field on PR form",       "Removed from UI; DB column retained",                "FSD Amendment F-05"],
    ["3", "Crystal Reports print",             "Replaced with QuestPDF server-side PDF (A4 Landscape)", "No Crystal Reports on web platform"],
    ["4", "Rate_Find() GRN receipt rate path", "Not implemented",                                   "FSD Rec #14 marks as dead code; no live scenario"],
    ["5", "VB6 keyboard shortcuts",            "Replaced with web-native shortcuts (Ctrl+S, F3, Ctrl+Arrows)", "Platform modernisation"],
    ["6", "Dual-stock min (current vs year-end)", "Simplified to single current stock value",        "Intentional simplification noted in migration"],
    ["7", "DIV_LOGO binary image in print",    "Not rendered; text letterhead from PP_DIVMAS used", "Complex binary join excluded; text sufficient"],
]

make_table(
    doc,
    ["#", "FSD Specification", "What Was Done Instead", "Reason"],
    [{"cells": r} for r in intentional],
    header_bg=RGBColor(0x06, 0x5F, 0x46),
    col_widths=[0.8, 4.0, 5.0, 4.2],
)
doc.add_paragraph()


# ── Section 3: Open Gaps ──────────────────────────────────────────────────────

add_section_heading(doc, "3.  OPEN GAPS  (FSD Required — Not Yet Implemented)", AMBER)
add_para(doc,
    "These features are specified in the FSD but have not been implemented. Low-priority items "
    "will be addressed in a future sprint unless directed otherwise.",
    size=10, space_before=4, space_after=4)

gaps = [
    ["G1", "Add Mode UI suppression (KPI strip, Created By hidden in Add mode)", "FSD Rec #32", "Medium", "Pending CEO sign-off per FSD note"],
    ["G2", "Tab skip rule — Tab must skip auto-filled read-only fields",         "CEO R2.0 #26","Low",    "Grid navigation partially implemented"],
    ["G3", "Focus-out validation — red border on mandatory fields",              "FSD Rec #4",  "Low",    "Validation on Save; not on blur"],
    ["G4", "Block Modify when partially approved (approval guard at API)",       "Section 5.5a","HIGH",   "See Decision D1 above"],
    ["G5", "Approval data delta update on Modify",                               "FSD Rec #3",  "HIGH",   "Currently delete-reinsert; approval data lost"],
    ["G6", "Signature labels driven by PO_PARA (not hardcoded)",                "FSD Rec #12", "Low",    "Labels hardcoded; configurable version deferred"],
    ["G7", "Pending order warning on item entry",                                "Section 4.4", "Medium", "See Decision D2 above"],
    ["G8", "Order Type (PO Group) mandatory when PurTypeFlg=1",                  "Section 4.4", "Medium", "Field present; mandatory check deferred"],
    ["G9", "BudgetQty flag — budget balance field + red highlight",              "Section 4.4", "Low",    "Budget module not in scope for M01"],
    ["G10","Rate Source selector UI (LPO / Average / Manual)",                   "CEO R2.0 #14","Medium", "See Decision D3 above"],
    ["G11","Numeric row-count insert (power-user N blank rows in picker)",       "CEO R2.0 #15","Low",    "Multi-select implemented; numeric mode deferred"],
    ["G12","Year boundary lock (no Add/Modify/Delete in previous year)",         "Section 6",   "Medium", "Enforcement not confirmed; needs verification"],
]

gap_rows = []
for g in gaps:
    risk = g[3]
    bg = LIGHT_RED if risk == "HIGH" else (LIGHT_AMBER if risk == "Medium" else None)
    risk_cell = {"text": risk, "bold": True, "color": RED if risk == "HIGH" else (AMBER if risk == "Medium" else GRAY)}
    gap_rows.append({
        "cells": [g[0], g[1], g[2], risk_cell, g[4]],
        "_bg": bg,
    })

make_table(
    doc,
    ["Ref", "Gap Description", "FSD Rule", "Risk", "Status / Note"],
    gap_rows,
    header_bg=RGBColor(0xD9, 0x7D, 0x06),
    col_widths=[0.8, 6.0, 2.0, 1.5, 4.7],
)
doc.add_paragraph()


# ── Section 4: Fixed Defects ──────────────────────────────────────────────────

add_section_heading(doc, "4.  FSD-LISTED DEFECTS  —  FIXED IN IMPLEMENTATION", BLUE)
add_para(doc,
    "The following defects were identified and documented in the FSD. All have been resolved "
    "in the SPINRISE V2 implementation.",
    size=10, space_before=4, space_after=4)

fixed = [
    ["F1", "Ghost record shown after Delete (Rec #21)",             "State cleared immediately; no stale record displayed"],
    ["F2", "Stale LPO Rate / Date shown after Save (Rec #20)",      "getById() called after every Save; full data reload"],
    ["F3", "Machine code duplicate rows in print (Rec #19)",        "Print SP joins MM_MACMAS with DIVCODE + DEPCODE + MACFLAG='M'; no duplicates"],
    ["F4", "Drawing No + Catalogue No suppressed in print (Rec #28)","Both columns added to ksp_PR_GetPrint and PDF table"],
    ["F5", "Creator / Employee name missing from print (Rec #17/18)","Both ReqEmpName and CreatedBy returned by print SP; shown in Prepared By box"],
    ["F6", "Navigation direction reversed (Prev/Next swapped)",      "SP returns DESC; list reversed client-side so First=oldest, Last=newest"],
]

make_table(
    doc,
    ["Ref", "FSD Defect", "Resolution"],
    [{"cells": r, "_bg": LIGHT_GREEN} for r in fixed],
    header_bg=RGBColor(0x18, 0x5F, 0xA5),
    col_widths=[0.8, 6.5, 7.7],
)
doc.add_paragraph()


# ── Section 5: Enhancements ───────────────────────────────────────────────────

add_section_heading(doc, "5.  ENHANCEMENTS ADDED  (Beyond FSD Scope)", BLUE)
add_para(doc,
    "The following features were not specified in the FSD but were added to improve usability "
    "and data integrity in the web version.",
    size=10, space_before=4, space_after=4)

enhancements = [
    ["E1", "Machine No lookup popup",
     "FSD allowed free-text entry. Implemented as enforced lookup against MM_MACMAS (filtered by division, department, MACFLAG='M'). Auto-fills Machine Description and Model."],
    ["E2", "Sub Cost Centre lookup popup",
     "FSD allowed free-text CC code entry. Implemented as enforced lookup against IN_CC (filtered by division). Displays name instead of code in grid."],
    ["E3", "Company letterhead in print from PP_DIVMAS",
     "FSD used Crystal Reports templates. New QuestPDF print fetches live company name, address, phone, email from PP_DIVMAS for the letterhead block."],
    ["E4", "Item image in line detail drawer",
     "Not in FSD. Item image (IN_ITEM.imagepath/ITEMIMAGE) shown in the right-side detail drawer when a line is expanded."],
]

make_table(
    doc,
    ["Ref", "Enhancement", "Detail"],
    [{"cells": r} for r in enhancements],
    header_bg=RGBColor(0x18, 0x5F, 0xA5),
    col_widths=[0.8, 4.0, 10.2],
)
doc.add_paragraph()


# ── Section 6: Compliance Summary ─────────────────────────────────────────────

add_section_heading(doc, "6.  OVERALL COMPLIANCE SUMMARY", DARK_NAVY)
doc.add_paragraph()

summary_table = doc.add_table(rows=6, cols=3)
summary_table.style = "Table Grid"
summary_table.alignment = WD_TABLE_ALIGNMENT.LEFT

summary_data = [
    ("Category",                   "Count", "Status"),
    ("Intentional changes (FSD amendments / migration decisions)", "7", "Documented above"),
    ("Open gaps (FSD required, not yet done)",                     "12", "3 HIGH, 5 Medium, 4 Low"),
    ("FSD-listed defects fixed",                                   "6",  "All resolved"),
    ("Enhancements added beyond FSD",                              "4",  "Value additions"),
    ("Decisions required from CEO",                                "3",  "See Section 1"),
]

for i, (col1, col2, col3) in enumerate(summary_data):
    cells = summary_table.rows[i].cells
    if i == 0:
        for c in cells:
            set_cell_bg(c, DARK_NAVY)
        for c, text in zip(cells, [col1, col2, col3]):
            p = c.paragraphs[0]
            p.paragraph_format.space_before = Pt(3)
            p.paragraph_format.space_after  = Pt(3)
            r = p.add_run(text)
            r.bold = True
            r.font.size = Pt(9)
            r.font.color.rgb = WHITE
            set_cell_border(c, "1E293B")
    else:
        bg = LIGHT_RED if i == 2 else (LIGHT_AMBER if i == 5 else None)
        for c in cells:
            if bg:
                set_cell_bg(c, bg)
            set_cell_border(c, "CCCCCC", "2")
        for c, text in zip(cells, [col1, col2, col3]):
            p = c.paragraphs[0]
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after  = Pt(2)
            r = p.add_run(text)
            r.font.size = Pt(9)

for row in summary_table.rows:
    row.cells[0].width = Cm(9.5)
    row.cells[1].width = Cm(2.0)
    row.cells[2].width = Cm(4.5)

doc.add_paragraph()


# ── Closing ───────────────────────────────────────────────────────────────────

add_para(doc,
    "Kindly review the three decision points in Section 1 and provide direction at your earliest "
    "convenience so that the approval workflow implementation can proceed without further delay. "
    "All other items are documented here for your records.",
    size=10, space_before=4, space_after=6)

add_para(doc, "Thank you for your time and continued guidance.", size=10, space_after=14)

add_para(doc, "Regards,", size=10, space_after=2)
add_para(doc, "Abinandan N", bold=True, size=10, color=DARK_NAVY, space_after=1)
add_para(doc, "Development Team — SPINRISE ERP V2", size=9.5, color=GRAY, space_after=1)
add_para(doc, "Kalsofte Pvt. Ltd.", size=9.5, color=GRAY, space_after=1)
add_para(doc, "abinandan.n@kalsofte.com", size=9.5, color=BLUE, space_after=1)


# ── Save ──────────────────────────────────────────────────────────────────────
doc.save(OUTPUT)
print(f"Document saved: {OUTPUT}")
