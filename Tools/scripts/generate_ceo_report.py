"""
CEO Gap Analysis Report Generator
SPINRISE M01 — PR Foreclosure & Cancellation
Generated: 29 May 2026
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_ALIGN_VERTICAL, WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

doc = Document()

# ── Page margins ──────────────────────────────────────────────────────────────
for section in doc.sections:
    section.top_margin    = Cm(2.0)
    section.bottom_margin = Cm(2.0)
    section.left_margin   = Cm(2.2)
    section.right_margin  = Cm(2.2)

# ── Color palette ─────────────────────────────────────────────────────────────
RED         = RGBColor(0xA3, 0x2D, 0x2D)
ORANGE      = RGBColor(0xBA, 0x75, 0x17)
GREEN_DARK  = RGBColor(0x3B, 0x6D, 0x11)
BLUE_DARK   = RGBColor(0x0C, 0x44, 0x7C)
BLUE        = RGBColor(0x18, 0x5F, 0xA5)
GREY_DARK   = RGBColor(0x1E, 0x29, 0x3B)
GREY_MID    = RGBColor(0x47, 0x55, 0x69)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
YELLOW_BG   = RGBColor(0xFE, 0xF9, 0xC3)
RED_BG      = RGBColor(0xFC, 0xEB, 0xEB)
BLUE_BG     = RGBColor(0xE6, 0xF1, 0xFB)
GREEN_BG    = RGBColor(0xEA, 0xF3, 0xDE)
AMBER_BG    = RGBColor(0xFA, 0xEE, 0xDA)

# ── Helpers ───────────────────────────────────────────────────────────────────

def set_cell_bg(cell, rgb: RGBColor):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement('w:shd')
    hex_color = f"{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  hex_color)
    tcPr.append(shd)

def set_cell_border(cell, border_side='bottom', color='C0C0C0', sz=6):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = tcPr.find(qn('w:tcBorders'))
    if tcBorders is None:
        tcBorders = OxmlElement('w:tcBorders')
        tcPr.append(tcBorders)
    border = OxmlElement(f'w:{border_side}')
    border.set(qn('w:val'),   'single')
    border.set(qn('w:sz'),    str(sz))
    border.set(qn('w:space'), '0')
    border.set(qn('w:color'), color)
    tcBorders.append(border)

def cell_text(cell, text, bold=False, color=None, size=9, align=None, italic=False):
    cell.text = ''
    p    = cell.paragraphs[0]
    if align:
        p.alignment = align
    run  = p.add_run(text)
    run.bold   = bold
    run.italic = italic
    run.font.size = Pt(size)
    if color:
        run.font.color.rgb = color

def add_heading(doc, text, level=1, color=BLUE_DARK, size=None, bold=True):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = p.add_run(text)
    run.bold = bold
    run.font.color.rgb = color
    if size:
        run.font.size = Pt(size)
    else:
        sizes = {1: 15, 2: 13, 3: 11, 4: 10}
        run.font.size = Pt(sizes.get(level, 11))
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    if level == 1:
        bdr = OxmlElement('w:bottom')
        bdr.set(qn('w:val'),   'single')
        bdr.set(qn('w:sz'),    '6')
        bdr.set(qn('w:space'), '1')
        bdr.set(qn('w:color'), f"{BLUE_DARK[0]:02X}{BLUE_DARK[1]:02X}{BLUE_DARK[2]:02X}")
        pBdr.append(bdr)
        pPr.append(pBdr)
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after  = Pt(4)
    return p

def add_para(doc, text, size=9.5, bold=False, color=None, space_after=4, italic=False):
    p   = doc.add_paragraph()
    run = p.add_run(text)
    run.bold   = bold
    run.italic = italic
    run.font.size = Pt(size)
    if color:
        run.font.color.rgb = color
    p.paragraph_format.space_after  = Pt(space_after)
    p.paragraph_format.space_before = Pt(0)
    return p

def add_bullet(doc, text, size=9.5, color=None, bold=False):
    p   = doc.add_paragraph(style='List Bullet')
    run = p.add_run(text)
    run.font.size = Pt(size)
    run.bold = bold
    if color:
        run.font.color.rgb = color
    p.paragraph_format.space_after  = Pt(2)
    p.paragraph_format.space_before = Pt(0)
    return p

def make_table(doc, headers, rows, col_widths=None, header_bg=GREY_DARK,
               header_color=WHITE, row_size=8.5, alternate=True, header_size=8.5):
    cols = len(headers)
    tbl  = doc.add_table(rows=1 + len(rows), cols=cols)
    tbl.style = 'Table Grid'
    tbl.alignment = WD_TABLE_ALIGNMENT.LEFT

    # Header row
    hdr_row = tbl.rows[0]
    hdr_row.height = Cm(0.65)
    for i, h in enumerate(headers):
        c = hdr_row.cells[i]
        set_cell_bg(c, header_bg)
        c.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        cell_text(c, h, bold=True, color=header_color, size=header_size)

    # Data rows
    for ri, row_data in enumerate(rows):
        tr = tbl.rows[ri + 1]
        tr.height = Cm(0.5)
        for ci, val in enumerate(row_data):
            c = tr.cells[ci]
            c.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            # Color-coded severity
            sev = str(val).strip().upper()
            if sev == 'CRITICAL':
                set_cell_bg(c, RED_BG)
                cell_text(c, str(val), bold=True, color=RED, size=row_size)
            elif sev == 'HIGH':
                set_cell_bg(c, AMBER_BG)
                cell_text(c, str(val), bold=True, color=ORANGE, size=row_size)
            elif sev in ('OPEN', 'BLOCKER'):
                set_cell_bg(c, RED_BG)
                cell_text(c, str(val), bold=True, color=RED, size=row_size)
            elif sev in ('FIXED', 'CLOSED', 'RESOLVED'):
                set_cell_bg(c, GREEN_BG)
                cell_text(c, str(val), bold=False, color=GREEN_DARK, size=row_size)
            elif sev in ('WRONG', 'MISSING'):
                set_cell_bg(c, AMBER_BG)
                cell_text(c, str(val), bold=True, color=ORANGE, size=row_size)
            else:
                if alternate and ri % 2 == 1:
                    set_cell_bg(c, BLUE_BG)
                cell_text(c, str(val), size=row_size)
        # Bottom border
        for ci in range(cols):
            set_cell_border(tbl.rows[ri + 1].cells[ci])

    # Column widths
    if col_widths:
        for ri in range(len(tbl.rows)):
            for ci, w in enumerate(col_widths):
                tbl.rows[ri].cells[ci].width = Cm(w)

    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return tbl

def add_severity_box(doc, severity, text, size=9):
    """Inline colored severity label paragraph."""
    p   = doc.add_paragraph()
    clr = RED if severity == 'CRITICAL' else ORANGE if severity == 'HIGH' else GREY_MID
    lbl = p.add_run(f"[{severity}]  ")
    lbl.bold = True
    lbl.font.color.rgb = clr
    lbl.font.size = Pt(size)
    body = p.add_run(text)
    body.font.size = Pt(size)
    p.paragraph_format.space_after  = Pt(2)
    p.paragraph_format.space_before = Pt(0)
    return p

def page_break(doc):
    doc.add_page_break()

# ══════════════════════════════════════════════════════════════════════════════
# COVER PAGE
# ══════════════════════════════════════════════════════════════════════════════

p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(40)
p.paragraph_format.space_after  = Pt(4)
run = p.add_run("SPINRISE ERP")
run.bold = True
run.font.size = Pt(20)
run.font.color.rgb = BLUE_DARK
p.alignment = WD_ALIGN_PARAGRAPH.CENTER

p = doc.add_paragraph()
run = p.add_run("KALPATHARU SPINNERS PVT. LTD.")
run.font.size = Pt(12)
run.font.color.rgb = GREY_MID
run.bold = True
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_after = Pt(2)

p = doc.add_paragraph()
run = p.add_run("KALSOFTE SOLUTIONS PVT. LTD.")
run.font.size = Pt(10)
run.font.color.rgb = GREY_MID
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_after = Pt(40)

# Title box
tbl = doc.add_table(rows=1, cols=1)
tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
tbl.style = 'Table Grid'
c = tbl.rows[0].cells[0]
set_cell_bg(c, BLUE_DARK)
c.width = Cm(14)
p2 = c.paragraphs[0]
p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
p2.paragraph_format.space_before = Pt(14)
p2.paragraph_format.space_after  = Pt(4)
r = p2.add_run("FORENSIC GAP ANALYSIS REPORT")
r.font.size = Pt(18)
r.font.color.rgb = WHITE
r.bold = True

p3 = c.add_paragraph()
p3.alignment = WD_ALIGN_PARAGRAPH.CENTER
r3 = p3.add_run("M01 — PR Foreclosure & PR Cancellation / Undo")
r3.font.size = Pt(13)
r3.font.color.rgb = RGBColor(0x93, 0xC5, 0xFD)
r3.bold = True
p3.paragraph_format.space_after = Pt(14)

doc.add_paragraph().paragraph_format.space_after = Pt(6)

meta = [
    ("Report Date",       "29 May 2026"),
    ("Prepared By",       "Claude Code — Senior ERP Analyst / Dev Architect / QA Lead"),
    ("Submitted To",      "CEO — T. Mani, Kalpatharu Software Ltd."),
    ("FSD Reference",     "SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1.1 — Approved 19 May 2026"),
    ("UI/UX Reference",   "SPINRISE_FSD_M01_PRForeclosure_v1_1.html · SPINRISE_FSD_M01_PRCancellationUndo_v1_1.html"),
    ("Dev Branch",        "feature/m01-pr"),
    ("Sessions Covered",  "28 May 2026 (R-01 to R-51) + 29 May 2026 (AM–PM)"),
    ("Report Status",     "FINAL — CEO Submission Ready"),
]
mt = doc.add_table(rows=len(meta), cols=2)
mt.style = 'Table Grid'
for ri, (k, v) in enumerate(meta):
    rc = mt.rows[ri].cells
    set_cell_bg(rc[0], BLUE_BG)
    cell_text(rc[0], k, bold=True, color=BLUE_DARK, size=9)
    cell_text(rc[1], v, size=9)
    rc[0].width = Cm(4.5)
    rc[1].width = Cm(12)

doc.add_paragraph().paragraph_format.space_after = Pt(30)

# Overall RAG
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("OVERALL PROJECT HEALTH: ")
r.bold = True
r.font.size = Pt(13)
r.font.color.rgb = GREY_DARK
r2 = p.add_run("🔴  AMBER-RED")
r2.bold = True
r2.font.size = Pt(14)
r2.font.color.rgb = RED

p2 = doc.add_paragraph()
p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
r3 = p2.add_run("1 BLOCKER DEFECT OUTSTANDING · 8 OPEN GAPS · CEO-MANDATED GUARD NOT IMPLEMENTED")
r3.bold = True
r3.font.size = Pt(9)
r3.font.color.rgb = RED
p2.paragraph_format.space_after = Pt(4)

p3 = doc.add_paragraph()
p3.alignment = WD_ALIGN_PARAGRAPH.CENTER
r4 = p3.add_run("NOT READY FOR UAT. IMMEDIATE CORRECTIVE ACTION REQUIRED.")
r4.bold = True
r4.font.size = Pt(9)
r4.font.color.rgb = ORANGE

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — EXECUTIVE SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "1. EXECUTIVE SUMMARY", 1)

add_para(doc,
    "This report presents a forensic-level, cross-document audit of the SPINRISE M01 PR Foreclosure and "
    "PR Cancellation / Undo modules. The analysis compares the Approved FSD v1.1 (baseline), the approved "
    "UI/UX HTML prototypes (implementation blueprint), the Mariyaiya functional documentation (business "
    "interpretation), and two development session logs (28–29 May 2026). Every gap, defect, mismatch, "
    "assumption-based error, and rework event has been identified, classified, and traced to its source.",
    size=9.5)

add_para(doc,
    "The audit reveals a module that was built substantially but carries systemic risk from assumption-based "
    "development, FSD ambiguities, and UI/UX-to-implementation mismatches. As of 29 May 2026, the module "
    "is NOT ready for UAT.",
    size=9.5, bold=True, color=RED)

add_heading(doc, "1.1  Key Statistics", 2)
make_table(doc,
    ["Metric", "Count / Status"],
    [
        ["Total issues resolved across both sessions",         "64  (R-01 through R-51 + 13 new in 29 May)"],
        ["BLOCKER defects identified",                         "5"],
        ["BLOCKER defects resolved",                           "4"],
        ["BLOCKER defects still open (as of 29 May EOD)",      "1  — GAP-FE-02 (UndoSubTab badge)"],
        ["WRONG / incorrect behaviour gaps remaining",         "4  — GAP-BE-03, BE-05, FE-03, FE-08"],
        ["MISSING feature gaps remaining",                     "3  — GAP-BE-04, FE-04, FE-05"],
        ["CEO-mandated business rule not implemented",         "1  — PO guard (GAP-BE-04)"],
        ["Database column assumed from FSD — does not exist",  "1  — MM_MACMAS.SCCCODE"],
        ["DB table name in FSD incorrect",                     "1  — PO_ORD (actual name unconfirmed)"],
        ["Schema migration not in FSD",                        "1  — pre_cancel_status column (ALTER TABLE)"],
        ["API endpoints not yet confirmed working",            "4  — /detail, /cancel, /undo, /fc-save"],
        ["Avoidable rework events (assumption-based)",         "≥ 18  (documented in Sections 7–8)"],
        ["FSD field / rule gaps identified",                   "12"],
        ["UI/UX vs FSD mismatches identified",                 "14"],
        ["Documentation inaccuracies vs FSD",                  "7"],
    ],
    col_widths=[9, 7.5],
    alternate=False)

add_heading(doc, "1.2  Critical Findings Summary", 2)
add_para(doc, "The following five findings demand immediate CEO attention:", size=9.5)

critical = [
    ("CF-01", "CEO-Mandated PO Guard Not Implemented",
     "The business rule preventing cancellation of PRs with existing Purchase Orders (OI-02-F2, mandated by CEO) "
     "was removed during development because the table name PO_ORD in the FSD does not exist in the live database. "
     "DBA must confirm the correct PO header table name before this can be restored."),
    ("CF-02", "FSD Column SCCCODE Does Not Exist in Live Database",
     "The FSD (Section 3, Field Table) specifies MM_MACMAS.SCCCODE as the Sub Cost Centre column added per CEO "
     "direction. This column does not exist in the live SpinRiseSaranya database. The UI shows placeholder data. "
     "This is a fundamental FSD error — the column source was never verified against the live schema."),
    ("CF-03", "1 BLOCKER Defect Open — UndoSubTab Badge Broken",
     "GAP-FE-02: The 'Lines Restore To' cell in the Undo Cancellation view renders the literal string "
     "'Lines Restore To' instead of the status badge (e.g., 'Requested'). A second duplicate grid block "
     "was also introduced. The undo flow is visually broken and cannot proceed to UAT in this state."),
    ("CF-04", "Cancellation Reason Not Returned to Undo View",
     "GAP-BE-03 + GAP-FE-03: The stored procedure ksp_PR_GetCancelledPRsForUndo does not return the "
     "canreason field. The Undo view currently displays 'Cancelled on 05-Apr-2026' as the reason text. "
     "This is a data integrity gap — users cannot see WHY a PR was cancelled when attempting to undo."),
    ("CF-05", "Audit Log Stores User ID Instead of User Name",
     "GAP-BE-05: LogDet_PO.username is populated with the technical user ID from claims (e.g., 'USR001') "
     "instead of the user's display name (e.g., 'Suresh Kumar'). All foreclosure and cancellation audit "
     "records created to date contain user IDs, not names. Historical audit trail is compromised."),
]
for cf_id, cf_title, cf_desc in critical:
    t = doc.add_table(rows=1, cols=1)
    t.style = 'Table Grid'
    c = t.rows[0].cells[0]
    set_cell_bg(c, RED_BG)
    p_h = c.paragraphs[0]
    rh1 = p_h.add_run(f"{cf_id}  |  ")
    rh1.bold = True; rh1.font.color.rgb = RED; rh1.font.size = Pt(9)
    rh2 = p_h.add_run(cf_title)
    rh2.bold = True; rh2.font.color.rgb = RED; rh2.font.size = Pt(9)
    p_b = c.add_paragraph(cf_desc)
    p_b.runs[0].font.size = Pt(8.5)
    p_b.paragraph_format.space_after = Pt(4)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — SCOPE OF ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "2. SCOPE OF ANALYSIS", 1)
add_para(doc, "This audit covers the following documents and source materials:", size=9.5)
make_table(doc,
    ["#", "Document", "Role in Analysis", "Version / Date"],
    [
        ["1", "SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1.1.docx", "Baseline Requirement", "v1.1 · 19 May 2026"],
        ["2", "SPINRISE_FSD_M01_PRForeclosure_v1_1.html",              "Approved UI/UX Blueprint — Foreclosure",   "FSD v1.1 · IST Cleared 23 May 2026"],
        ["3", "SPINRISE_FSD_M01_PRCancellationUndo_v1_1.html",         "Approved UI/UX Blueprint — Cancellation/Undo", "FSD v1.1 · IST Cleared 23 May 2026"],
        ["4", "PR_Cancellation and foreclosure Forms_Documentation.md", "Business Interpretation Document",         "Mariyaiya — date not stamped"],
        ["5", "GAPS_M01_PRForeclosure_Cancellation.md",                "Gap Tracking Document",                    "28 May — updated 29 May 2026"],
        ["6", "2026-05-28_session_resolution_log.md",                  "Development Session Log (Day 1)",           "28 May 2026 — R-01 to R-51"],
        ["7", "2026-05-29_session_foreclosure_cancellation_fixes.md",  "Development Session Log (Day 2)",           "29 May 2026 — AM/PM session"],
    ],
    col_widths=[0.6, 6.5, 4.2, 4.2])

add_heading(doc, "2.1  Methodology", 2)
for step in [
    "All documents read and cross-referenced at field level — no assumptions made.",
    "FSD treated as the binding baseline. Every deviation from FSD is a gap.",
    "HTML prototypes treated as the approved UX specification. Every deviation from HTML is a defect.",
    "Development logs treated as ground truth for execution history.",
    "Mariyaiya documentation treated as business interpretation — validated against FSD and HTML.",
    "Each finding is assigned: Gap ID, Severity (Critical / High / Medium / Low), source evidence, business impact, and recommendation.",
    "Root cause categories applied: Requirement Failure / Design Failure / Documentation Failure / Development Failure / Review Failure / Testing Failure.",
]:
    add_bullet(doc, step)

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — FSD GAP ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "3. FSD GAP ANALYSIS", 1)
add_para(doc,
    "The following gaps were identified in the Approved FSD v1.1. These are deficiencies within the FSD itself — "
    "missing rules, ambiguous specifications, incorrect data, or contradictions that directly caused development "
    "failures or rework.",
    size=9.5)

make_table(doc,
    ["Gap ID", "Severity", "Requirement Area", "Description", "Business Impact", "Recommendation"],
    [
        ["FSD-01", "Critical",
         "DB Schema — MM_MACMAS.SCCCODE",
         "FSD Section 3 (Field Table, col 9) specifies MM_MACMAS.SCCCODE as the Sub Cost Centre column added per CEO direction. This column does NOT exist in the live SpinRiseSaranya database. Confirmed during development (R-08): removed as placeholder.",
         "CEO-directed feature cannot be implemented. Grid shows '—' for all Sub Cost Centre values. No data integrity guarantee.",
         "CEO / DBA to identify the correct column for Sub Cost Centre in MM_MACMAS. Update FSD with confirmed column name before next sprint."],
        ["FSD-02", "Critical",
         "DB Table — PO_ORD (CEO-mandated PO guard)",
         "FSD specifies PO_ORD as the PO header table for the CEO-mandated guard (OI-02-F2): 'PRs with existing POs must not appear in cancel list.' PO_ORD does not exist in the live DB. Table name was never verified.",
         "PRs that have active Purchase Orders appear in the cancellation list. Users can cancel PRs they should not be able to. Critical business control missing.",
         "DBA to execute: SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE 'PO_%'. Identify correct PO header table. Restore NOT EXISTS guard in ksp_PR_GetCancellablePRs."],
        ["FSD-03", "High",
         "SP Naming Convention",
         "FSD Section 1 (Key Stored Procedures) states SP names as sp_PR_GetOpenForForeclosure, sp_PR_GetCancellablePRs, sp_PR_GetCancelledPRsForUndo (prefix: sp_PR_). Confirmed by Sasi at Stage 2. However, actual project SP prefix is ksp_PR_ (all existing SPs use ksp_ prefix, confirmed with Sasi per dev log R-03). FSD was never corrected after Stage 2 clarification.",
         "Any future developer reading FSD will use wrong SP names. FSD is inconsistent with actual codebase. Risk of confusion in next sprint or after developer change.",
         "Update FSD Section 1 to correct SP prefix to ksp_PR_. Add note: 'Confirmed with Sasi 20 May 2026 — prefix changed from sp_ to ksp_.'"],
        ["FSD-04", "High",
         "Cancel Reason — Max Length Contradiction",
         "FSD Field Table says cancel reason max 100 chars (matching VB6 MaxLength=100). DB column PO_PRH.canreason is varchar(250). HTML prototype has maxlength=200. Three different values for the same constraint across three authoritative documents.",
         "Developer must guess the correct limit. HTML prototype was built to 200 chars — if FSD limit of 100 is enforced, valid user inputs will be rejected. DB can store 250 — 150 chars wasted.",
         "CEO to decide: 100 chars (VB6 legacy), 200 chars (HTML prototype), or 250 chars (DB capacity). Align all three documents. Recommend 200 chars (HTML) as it is the approved UX standard."],
        ["FSD-05", "High",
         "APPFLG Filter — Missing from Cancellability Rules",
         "FSD Section 4 (ScopeLookup eligibility) lists: CANCELFLAG IS NULL, not in PO_ENQL, QTYORD=0. The filter APPFLG<>'Y' appears in the VB6 code (adoPrimaryRS WHERE clause) but is NOT documented in the FSD business rules. SPINRISE dev logs do not mention implementing this filter.",
         "PRs that are already approved (APPFLG='Y') may appear in the cancellation list. Approved PRs should not be cancellable without explicit business rule coverage.",
         "Confirm with business: should approved PRs be excludable from cancellation? If yes, add APPFLG filter to FSD Section 4 and SP ksp_PR_GetCancellablePRs."],
        ["FSD-06", "High",
         "pre_cancel_status Column — Schema Migration Not Documented",
         "Business Rule BR-UNDO-01 requires storing the pre-cancellation PRSTATUS per line so undo can restore the correct status. This requires ALTER TABLE PO_PRL ADD pre_cancel_status. This migration is not documented anywhere in the FSD. Dev log R-05 shows it was added as a guard in merged.sql.",
         "Without pre_cancel_status, the undo operation cannot restore lines to correct status. If migration is not in FSD, future deployments or rollbacks will miss this critical step.",
         "Add pre_cancel_status column requirement explicitly to FSD Section 6 (DB Migration) with: ALTER TABLE PO_PRL ADD pre_cancel_status CHAR(1) NULL. Ensure merged.sql guard is part of deployment script."],
        ["FSD-07", "High",
         "rowversion Concurrency — Schema Migration Not Verified",
         "FSD Architecture Standards section states: 'ALTER TABLE PO_PRH ADD row_version ROWVERSION and ALTER TABLE PO_PRL ADD row_version ROWVERSION required before SPINRISE go-live.' This is a mandatory schema change — not in the FSD migration section and no evidence it has been executed in the live DB.",
         "Without rowversion, simultaneous foreclosure/cancellation by two users on the same PR will cause data corruption. No optimistic concurrency protection in place.",
         "Add rowversion migration to FSD Section 6. Include in merged.sql. Verify against live DB using: SELECT * FROM sys.columns WHERE name='row_version' AND object_id IN (OBJECT_ID('PO_PRH'),OBJECT_ID('PO_PRL'))."],
        ["FSD-08", "Medium",
         "Foreclosure — Cross-FY Scope Not Specified",
         "FSD Billdisplay query filters on divcode only — no date range filter. HTML prototype loads all open lines across all financial years. Dev log N-04 shows FY filter was added as a new requirement (fdate/ldate params) during development. This was a developer-initiated change, not FSD-directed.",
         "Without FY boundary, the foreclosure grid loads records from all financial years. For legacy data (2022–2026), this could load hundreds of irrelevant rows, causing performance issues and user confusion.",
         "Add FY date range filter to FSD Section 4 Billdisplay business rule. Document getFYBounds() utility and its role. Update SP signature to include @fdate, @ldate."],
        ["FSD-09", "Medium",
         "Audit Log — username vs userId Ambiguity",
         "FSD Section 4 LogDet_PO INSERT specifies: 'Trans_UserId, username'. The FSD does not explicitly distinguish between the technical user ID (from auth claims) and the display name. This ambiguity caused GAP-BE-05 where userId was stored in username column.",
         "Audit log quality compromised. username column contains technical IDs ('USR001') instead of readable names ('Suresh Kumar'). Audit reports cannot be understood without cross-referencing a user master table.",
         "Clarify in FSD: username = User display name from SpinriseClaims.UserName; Trans_UserId = Technical user ID from SpinriseClaims.UserId. Both values required. Extract both from controller."],
        ["FSD-10", "Medium",
         "Foreclosure — Status Column Not in Original FSD",
         "The HTML prototype includes a 'Status' column (Requested / Partial / Enquired / Ordered) in the foreclosure grid. The FSD original 8-column grid has NO Status column. FSD was not updated to reflect this UI addition.",
         "Status column is showing in the UI without FSD authorization. SP must return prevStatus — not defined in FSD SP signature. Developer had to derive this independently.",
         "Add Status column to FSD Section 3 Foreclosure Grid field table. Document: DB source = PO_PRL.PRSTATUS decoded, include in SP SELECT list."],
        ["FSD-11", "Medium",
         "Cancellation — Undo Scope Limited to Current FY Only",
         "FSD Section 4 (undoLookup) states filter: 'prdate BETWEEN yfdate AND yldate' — restricting undo to current financial year. HTML prototype also shows this. However, the Mariyaiya documentation does not mention this restriction. This creates a documentation gap that could mislead testers or future developers.",
         "Testers may attempt to undo PRs from prior FY and report false failures. Training materials will be incorrect.",
         "Add explicit note to FSD business rules: 'Undo Cancellation is restricted to current financial year (yfdate to yldate). Cross-FY undo is not supported.' Also update Mariyaiya documentation."],
        ["FSD-12", "Low",
         "Keyboard Shortcuts — Ctrl+M Modify Not in HTML",
         "FSD Section 4 lists keyboard shortcuts: Ctrl+M=Modify for Foreclosure. The HTML prototype does not implement Ctrl+M — only Ctrl+S and Alt+X are keyboard-bound. Implementation status ambiguous.",
         "Minor UX inconsistency. Users accustomed to Ctrl+M from FSD documentation may find it unresponsive.",
         "Clarify in FSD whether Ctrl+M is required or optional for Foreclosure page. Update HTML prototype if required."],
    ],
    col_widths=[1.3, 1.5, 2.8, 4.8, 3.0, 3.6])

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — UI/UX DESIGN GAP ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "4. UI/UX DESIGN GAP ANALYSIS", 1)
add_para(doc,
    "The approved HTML prototypes were compared against the FSD field tables and business rules. "
    "The following gaps were identified where the HTML deviates from or adds to the FSD specification.",
    size=9.5)

add_heading(doc, "4.1  PR Foreclosure Screen", 2)
make_table(doc,
    ["UI Gap ID", "Screen Area", "Severity", "Finding", "Impact", "Recommendation"],
    [
        ["UI-FC-01", "Grid Columns", "High",
         "HTML grid has 13 columns (Checkbox, #, PR No, PR Date, Department, Item Id, Item Name, Unit, Quantity, Ordered, Balance, Sub Cost Centre, Status). FSD grid has 8 columns + 1 CEO-added (SCCCODE) = 9. Extra HTML columns not in FSD: Row Number (#), Unit (UOM), Quantity (QTYREQD), Ordered (QTYORD), Status.",
         "5 columns displayed in production are not documented in FSD. SP was built to return them (causing extra mapping work) but they are not formally approved. Scope creep without FSD coverage.",
         "Update FSD Section 3 to include all 13 columns with DB sources. Get formal approval for added columns."],
        ["UI-FC-02", "Filter Bar", "Medium",
         "HTML has a PR No. text filter and a 'Load' button in a filter bar. FSD specifies a DTPicker1 date picker inside a FrameSelection area with Show/Cancel buttons. The HTML date filter is absent. Implemented dev solution (FY fdate/ldate) is different from both.",
         "User cannot filter by date range in UI as FSD specifies. FY auto-filter added by developer is not user-accessible — user cannot change date scope.",
         "Align FSD and HTML on filter approach. Either: (a) add date range picker to HTML prototype and implement, or (b) document FY auto-filter as the approved approach in FSD."],
        ["UI-FC-03", "Footer Stats", "Low",
         "HTML footer shows: Total Lines, Selected, Total Balance, Selected Balance. FSD does not specify a footer stats bar for foreclosure. This is a helpful UX addition not covered in FSD.",
         "Minor. Addition is positive UX. No FSD coverage.",
         "Add footer stats specification to FSD Section 3 or note as designer-added feature approved via HTML prototype."],
        ["UI-FC-04", "Confirm Dialog", "Medium",
         "HTML confirm dialog explicitly states: 'Sets FClosed=Y and FCloseddt=GETDATE(). Audit entry written to LogDet_PO inside BeginTrans. This action cannot be undone.' FSD does not specify the exact confirm dialog message text.",
         "Confirm dialog text is the only user-visible warning about irreversibility. If text is wrong, users may not understand the permanence of foreclosure.",
         "Add confirm dialog message specification to FSD Section 4 (Save flow). Approve HTML confirm text as the standard."],
        ["UI-FC-05", "Status Badge", "Medium",
         "HTML shows Status column with 'Requested' badge (green) for all sample data rows. FSD grid Billdisplay query does not filter by PRSTATUS — it shows all lines with balance>0. HTML implies only 'Requested' lines are shown. If partial/enquired lines can also be foreclosed, the badge mapping needs documentation.",
         "If the intent is foreclosure applies to all statuses (not just Requested), the HTML sample data is misleading. If only Requested lines should appear, FSD must add this filter explicitly.",
         "Confirm with business: can Partial, Enquired, Ordered lines be foreclosed? Update FSD WHERE clause accordingly. Update HTML to show varied statuses in sample data."],
    ],
    col_widths=[1.5, 2.0, 1.3, 5.5, 3.0, 3.7])

add_heading(doc, "4.2  PR Cancellation Screen", 2)
make_table(doc,
    ["UI Gap ID", "Screen Area", "Severity", "Finding", "Impact", "Recommendation"],
    [
        ["UI-CN-01", "Cancellation Item Grid", "Critical",
         "HTML items table shows 12 columns: #, Item Id, Item Name, Unit, Required Quantity, Rate, ₹ Approx. Value, Required Date, Machine, Sub Cost Centre, Remarks, Sample. FSD cancellation grid (VB6 DataGrid1) specifies 17 fields including: Current Stock (in_item.curstk), Qty Approved (QTYREQD), Qty Ordered (QTYord), Qty Received (qtyrec), PR Status (PRSTATUS), Place Of Issue. These 6 fields from FSD are MISSING from HTML.",
         "Users cannot see approved qty, ordered qty, received qty, current stock, or place of issue when reviewing a PR for cancellation. These are critical data points for cancellation decision-making. Major functional gap between FSD and UI.",
         "Update HTML prototype to include all FSD-specified columns. Add Qty Approved, Qty Ordered, Qty Received, Current Stock, PR Status, Place Of Issue to items table. Get CEO approval for revised HTML."],
        ["UI-CN-02", "KPI Strip", "Medium",
         "HTML cancellation screen includes a KPI strip showing: Total Lines, Total Quantity, Approx. Budget, Days Open — plus an approval pipeline visualization (Requested → L1 Approved → L2 Approved → Final). These are NOT specified in the FSD at all.",
         "KPI strip is positive UX addition. Pipeline visualization may confuse users if approval stages are not relevant to cancellation. Days Open color-coding (green/amber/red) requires business rules for thresholds (5 days, 14 days) that are not documented.",
         "Either: (a) Add KPI strip specification to FSD including Days Open threshold rules, or (b) note as designer-added enhancement approved via HTML prototype. Remove approval pipeline if it does not apply to cancellation context."],
        ["UI-CN-03", "Cancel Reason", "High",
         "HTML reason textarea has maxlength=200 and does NOT enforce alpha-numeric-only characters. FSD specifies: 'alpha-numeric only (ToAlphaNumber validation), max 100 chars, UPPERCASE enforced.' Three discrepancies: (1) length 100 vs 200, (2) alpha-numeric not enforced, (3) UPPERCASE not shown in UI.",
         "Users can enter special characters (@, #, !, etc.) in cancellation reason. Long-form reason (>100 chars) will be accepted by UI but may fail if server enforces 100-char limit. No visual indication reason is stored uppercase — confusing when displayed later.",
         "Align HTML and FSD on: maxlength (recommend 200 per HTML). Add client-side alpha-numeric validation. Add note '(stored in UPPERCASE)' to placeholder text. Enforce UPPERCASE in React oninput handler."],
        ["UI-CN-04", "Cancel Eligibility Filter", "High",
         "HTML cancel modal header comment (line 1034) states: 'sp_PR_GetCancellablePRs: not approved, not cancelled, QTYORD=0, not in PO_ENQL, not in PO_ORD, within FY.' However, the PO_ORD guard is NOT implemented in the actual SP (table name unconfirmed — GAP-BE-04). HTML implies this guard is active when it is not.",
         "HTML prototype claims a business control exists (PO guard) that is actually not implemented. Any IST tester reading the HTML comment would expect PRs with POs to be excluded — they are not.",
         "Either implement the PO guard (after DBA confirms table name) or update HTML comment to note 'PO_ORD guard pending DBA confirmation of table name.'"],
        ["UI-CN-05", "Undo — Lines View", "Medium",
         "HTML Undo view does not show line-level items table for the cancelled PR being reviewed. FSD bindcontls specifies loading PO_PRL + IN_ITEM + mm_MACmas for detail grid display. The undo HTML only shows a summary card (reason, line count) without per-line detail.",
         "Users cannot review individual line items before undoing a cancellation. For PRs with multiple lines, users cannot verify which items will be restored.",
         "Confirm with business: is line-level detail required on the Undo view? If yes, add items table to HTML Undo prototype and implement. If no, document as intentional simplification in FSD."],
        ["UI-CN-06", "Auto-Open Behavior", "Medium",
         "HTML prototype (line 1278) calls setTimeout(() => openCancelModal(), 150) on DOMContentLoaded — cancel modal auto-opens on page load. HTML switchSubTab also auto-opens undo modal (line 1332). Dev log GAP-FE-04 and GAP-FE-05 show these behaviors are NOT yet implemented in the React application.",
         "Users land on an empty screen and must manually click 'Find PR to Cancel.' This contradicts both the VB6 Form_Load behavior (ScopeLookup auto-called) and the approved HTML prototype behavior.",
         "Implement auto-open behaviors as specified in HTML. Both are listed as open gaps (GAP-FE-04, GAP-FE-05) and must be fixed before UAT."],
        ["UI-CN-07", "Cancel Modal Columns", "Low",
         "HTML cancel lookup modal shows: PR No, PR Date, Department, Requester, Items (5 cols). FSD ScopeLookup result set specifies: prno, prdate, depcode, Depname only (4 cols). HTML adds Requester and Items count — not in FSD.",
         "Minor enhancement. Requester and Items count are helpful for PR identification. No negative impact.",
         "Update FSD ScopeLookup result set specification to include Requester (PO_PRH.REQNAME) and Items count."],
        ["UI-CN-08", "Undo Modal Columns", "Low",
         "HTML undo modal shows: PR No, PR Date, Department, Requested By, Cancelled On, Prev. Status (6 cols). FSD undoLookup result set specifies: prno, prdate, depcode, Depname only. HTML adds 2 extra columns (Cancelled On, Prev. Status) not in FSD.",
         "Added columns are essential for undo identification — Cancelled On and Prev. Status are necessary for informed undo decisions.",
         "Update FSD undoLookup SP signature to include canceldt and pre_cancel_status in SELECT list."],
        ["UI-CN-09", "Toolbar — F3 Shortcut", "Low",
         "HTML Cancellation keyboard handler (line 1771) binds F3 to open the cancel or undo modal. FSD keyboard shortcut specification does not mention F3 for Cancellation. FSD VB6 uses F3 via showForm4FunctionKey() for help navigation.",
         "F3 key behavior differs from VB6 convention (help). In Cancellation, F3 triggers lookup modal. May confuse users transitioning from VB6.",
         "Clarify F3 intent in FSD: if F3 = Find PR modal, document this in FSD shortcut table. If F3 should remain as help key, change HTML to different shortcut."],
    ],
    col_widths=[1.5, 2.0, 1.3, 5.5, 3.0, 3.2])

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — DOCUMENTATION GAP ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "5. MARIYAIYA DOCUMENTATION GAP ANALYSIS", 1)
add_para(doc,
    "The PR_Cancellation and foreclosure Forms_Documentation.md was compared against the FSD v1.1 and "
    "HTML prototypes. The following gaps, inaccuracies, and omissions were identified.",
    size=9.5)

make_table(doc,
    ["Doc Gap ID", "Section", "Severity", "Finding", "Impact", "Recommendation"],
    [
        ["DOC-01", "Undo Flow — PRSTATUS restoration",
         "High",
         "Documentation states: 'PO_PRL.PRSTATUS is set to NULL' on undo. This is incorrect. The FSD business rule BR-UNDO-01 explicitly requires restoring each line to its PRE-CANCEL status (stored in pre_cancel_status column) — not NULL. Setting to NULL would leave lines in an undefined state.",
         "If developers or testers reference this documentation for undo behavior, they will implement or test the wrong outcome. Lines restored to NULL would not appear correctly in the PR form.",
         "Correct documentation: 'On undo, PO_PRL.PRSTATUS is restored to its previous value stored in PO_PRL.pre_cancel_status for each line.' Remove the NULL statement."],
        ["DOC-02", "Missing — PO_ORD Guard",
         "Critical",
         "Documentation does not mention the CEO-mandated business rule that PRs with existing Purchase Orders (in PO_ORD/correct table) must be excluded from the cancellation list. This is open item OI-02-F2 in the FSD.",
         "Testers will not test this scenario. Training materials will not inform users of this restriction. Business control gap will not be caught during UAT.",
         "Add section: 'PRs with active Purchase Orders are not eligible for cancellation. Error message: A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR.'"],
        ["DOC-03", "Missing — Current Financial Year Restriction on Undo",
         "Medium",
         "Documentation describes undo flow but does not mention the restriction that undo is limited to current financial year only (yfdate to yldate). PRs cancelled in prior FY cannot be undone.",
         "Testers and users will attempt to undo cross-FY cancellations and report false failures. Support calls will result.",
         "Add explicit note: 'Undo Cancellation is restricted to the current financial year. Cancellations from prior financial years cannot be undone through this module.'"],
        ["DOC-04", "Cancel Reason — Character Limit Discrepancy",
         "Medium",
         "Documentation implies max 100 chars (matching VB6). Does not mention the discrepancy with DB (varchar 250) and HTML prototype (maxlength 200).",
         "Documentation is inconsistent with the implemented system. Users may be surprised when typing stops at a limit different from the documented one.",
         "Update documentation with agreed character limit once FSD contradiction is resolved (see FSD-04)."],
        ["DOC-05", "Missing — Cross-FY Cancellability Rule",
         "Medium",
         "Documentation's ScopeLookup description does not mention the cross-FY prdate guard added during development. The cancellation SP must include AND x.prdate = a.prdate in all subqueries to prevent PR number collisions across financial years.",
         "Without documenting this, future developers modifying the SP may remove the prdate guard, causing cross-year data contamination. This was a discovered runtime bug — not an FSD-documented rule.",
         "Document: 'All subqueries in ksp_PR_GetCancellablePRs must include AND x.prdate = a.prdate to prevent PR number collision across financial years. PR numbers reset per financial year in SpinRiseSaranya.'"],
        ["DOC-06", "Security Note — Misapplied to Wrong Form",
         "Low",
         "Documentation Section (Shared Infrastructure / Security Notes) states: 'The Indentcancellation form uses string-concatenated SQL queries and should be refactored.' This refers to the VB6 AS-IS code, not to SPINRISE. The SPINRISE implementation uses Dapper parameterized queries throughout.",
         "Any reader of this documentation will believe SPINRISE has SQL injection vulnerabilities. This is factually incorrect for the new system.",
         "Remove the VB6-referencing security note from documentation. Replace with: 'SPINRISE implementation uses Dapper parameterized stored procedures throughout. SQL injection risk is eliminated.'"],
        ["DOC-07", "Missing — APPFLG Filter in ScopeLookup",
         "Medium",
         "Documentation ScopeLookup description lists eligibility criteria (CANCELFLAG IS NULL, not in PO_ENQL, QTYORD=0) but omits the APPFLG<>'Y' filter present in VB6 code.",
         "Approved PRs may appear in cancellation list if APPFLG filter is not implemented. This is a business rule omission that could cause incorrect cancellations.",
         "Add APPFLG filter to documentation once confirmed with business (see FSD-05)."],
    ],
    col_widths=[1.5, 2.2, 1.3, 5.5, 3.0, 3.5])

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — DEVELOPMENT EXECUTION AUDIT
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "6. DEVELOPMENT EXECUTION AUDIT", 1)
add_para(doc,
    "Analysis of the 28 May and 29 May 2026 development session logs. Every defect, rework event, "
    "and assumption-based error is documented below with root cause, evidence, and preventability assessment.",
    size=9.5)

add_heading(doc, "6.1  Defect Register", 2)
make_table(doc,
    ["Defect ID", "Root Cause Category", "Evidence", "Impact", "Preventable", "Recommendation"],
    [
        ["DEF-01\nGAP-BE-01",
         "Dapper type mapping not verified before DTO authoring — IsSample",
         "GAPS doc: PrCancellationRepository.cs line 66. CASE...1/0 returns SQL INT. DTO used C# bool. Dapper positional record constructor fails. 28 May log R-28 (open), 29 May log resolved.",
         "BLOCKER — GET /api/v1/pr-cancellation/detail threw materialization exception. Entire cancellation detail endpoint non-functional.",
         "YES — Rule: always CAST SQL expressions to the target C# type in the SP. Document in team standards.",
         "Add CAST(... AS BIT) to all boolean-like CASE expressions in SPs. Enforce Dapper type compatibility table in code review checklist."],
        ["DEF-02\nGAP-BE-02",
         "SQL NUMERIC to C# int mismatch — prsno",
         "GAPS doc: PrCancellationRepository.cs line 51. PO_PRL.prsno is SQL numeric. DTO used int. Same endpoint as DEF-01.",
         "BLOCKER — Same endpoint failure as DEF-01. Compound error requiring two separate fixes.",
         "YES — SP should CAST(b.prsno AS INT) at source. Rule established but not applied.",
         "Enforce CAST at SP level for all numeric-to-int mappings. Add to SP code review checklist."],
        ["DEF-03\nGAP-BE-03",
         "SP SELECT list incomplete — canreason field missing",
         "GAPS doc: ksp_PR_GetCancelledPRsForUndo.sql — canreason column from PO_PRH never included in SELECT. UndoSubTab fell back to cancelledOn date.",
         "WRONG — Undo cancellation reason display shows date string ('Cancelled on 05-Apr-2026') instead of actual reason. Users cannot see WHY a PR was cancelled before undoing.",
         "YES — A pre-build review of the SP against FSD field table would have caught this.",
         "Fix: Add RTRIM(ISNULL(a.canreason,'')) AS CancelReason to SP SELECT. Update DTO, types.ts, UndoSubTab. End-to-end fix required together."],
        ["DEF-04\nGAP-BE-04",
         "FSD table name PO_ORD does not exist in live DB — CEO-mandated guard removed",
         "GAPS doc: ksp_PR_GetCancellablePRs.sql — PO_ORD commented out. 28 May log R-09: 'PO_ORD invalid table name removed.' CEO directed this check (OI-02-F2 CLOSED in FSD).",
         "MISSING — CRITICAL BUSINESS CONTROL: PRs with active POs appear in cancel list. Users can cancel PRs that have active purchase orders. Financial/procurement data integrity risk.",
         "YES — FSD table name should have been verified against live DB before SP authoring began.",
         "DBA to confirm PO header table name. Restore NOT EXISTS guard in SP. Add user-facing error message per FSD spec."],
        ["DEF-05\nGAP-BE-05",
         "Claims extraction — username vs userId not distinguished",
         "GAPS doc: Both repositories extract UserId from claims but pass it to LogDet_PO.username. FSD says username = display name. SpinriseClaims.UserName claim not extracted.",
         "WRONG — All audit records contain technical user IDs, not human-readable names. Audit trail is technically correct but operationally unreadable for management review.",
         "YES — FSD was ambiguous but the field name 'username' implies display name. Clarification before coding would have avoided this.",
         "Extract SpinriseClaims.UserName in both controllers. Pass as separate parameter. Use: var userName = User.FindFirstValue(SpinriseClaims.UserName) ?? userId;"],
        ["DEF-06\nGAP-FE-01",
         "Shared component interface not read before use — PRDocBand",
         "GAPS doc + 29 May log: PrForeclosurePage.tsx and PrCancellationPage.tsx passed title, breadcrumb, subLabel, subValue to PRDocBand. None of these props exist in component interface. Props silently ignored. Breadcrumb showed hardcoded 'Purchase Requisition' on all pages.",
         "BLOCKER — Both new pages showed wrong breadcrumb and metadata. Visually broken for any user or tester.",
         "YES — Team rule: read the component interface before importing. One-minute read would have prevented this.",
         "Fixed in 29 May session. Add to code review: 'Verify all component props against interface before use.' Consider TypeScript strict prop validation to make this a compile error."],
        ["DEF-07\nGAP-FE-02",
         "Complex conditional rendering logic error — badge shows label string",
         "GAPS doc line 72: {label === 'Lines Restore To' ? label === 'Lines Restore To' && label : label} evaluates to the string 'Lines Restore To' always. Second bug: duplicate gridTemplateColumns block creates empty row.",
         "BLOCKER — Undo view 'Lines Restore To' cell shows literal text instead of status badge. Still open as of 29 May EOD. Undo flow visually broken.",
         "YES — Code review of conditional logic would have caught the tautological expression immediately.",
         "Fix: replace with {label} directly. Remove duplicate grid block. Must be fixed before any UAT activity."],
        ["DEF-08\nGAP-FE-04/05",
         "VB6 Form_Load auto-open behavior not implemented",
         "HTML prototype line 1278: setTimeout(() => openCancelModal(), 150). FSD: ScopeLookup called on Form_Load. Neither implemented in React. Users see empty screen on page load.",
         "MISSING UX — Users must manually click 'Find PR to Cancel' on every page load. Violates both FSD and approved HTML prototype specification.",
         "YES — Both the FSD and HTML prototype specified this behavior. It was simply not built.",
         "Implement useEffect auto-open in usePrCancellation.ts: loadCancellable().then(data => { if (data.length > 0) setCancelModalOpen(true) }). Similarly for undo tab switch."],
        ["DEF-09\nN-01/N-02",
         "DB schema assumption — prsno not a sequential line number",
         "29 May log N-01: PO_PRL.prsno is always 1 in SpinRiseSaranya DB. rowKey = prNo-prSno collides for all lines of same PR. All rows select/deselect together.",
         "Critical UX bug — foreclosure grid multi-selection completely broken. Selecting one line selected all lines in the same PR. Reported and fixed 29 May.",
         "YES — Schema discovery session before development would have revealed prsno=1 for all rows.",
         "Fixed: rowKey changed to prNo-prDate-itemCode-depCode-sccCode. Document legacy schema characteristic in team knowledge base."],
        ["DEF-10\nN-03",
         "Ant Design Spin component breaks flex scroll chain",
         "29 May log N-03: Spin wrapper renders additional div layers. height:100% resolves to content height, not viewport height. Grid scroll broken — 20 rows loaded but only 15 visible.",
         "UX defect — grid not scrollable. Users could not see all available PR lines for foreclosure.",
         "Partial — Ant Design Spin behavior is a known framework quirk. Should be in team's shared knowledge.",
         "Fixed: position:relative container + absolute overlay spinner. Document: 'Never use Ant Design Spin with height:100% in flex containers — use absolute positioning overlay.'"],
        ["DEF-11\nN-04",
         "FY boundary filter absent from foreclosure SP",
         "29 May log N-04: SP had no date filter — loaded all FY data. Developer added fdate/ldate parameters. Not in FSD, not in HTML prototype.",
         "Performance risk: legacy data from 2022–2026 loaded in single query. For real production data this could be thousands of rows.",
         "YES — FSD should have specified date scope. Missing from FSD (see FSD-08).",
         "Fixed. Document getFYBounds() utility usage. Update FSD SP signature."],
        ["DEF-12\nN-05",
         "Cross-FY PR number collision in correlated subqueries",
         "29 May log N-05: ksp_PR_GetCancellablePRs returned 0 rows for current FY. Subqueries joined on prno+divcode only — old-year enquiry records with same prno blocked new-year PRs.",
         "Critical data bug — entire cancellation list was empty. No PRs available for cancellation despite valid data existing.",
         "YES — Database schema characteristic (PR numbers reset per FY) should be in team knowledge base. FSD should document.",
         "Fixed: added AND x.prdate = a.prdate to all 4 correlated subqueries. Document as mandatory pattern for any query joining PO_PRL, PO_ENQL, PO_ORD, PO_ENQUIRY."],
        ["DEF-13\nR-46..R-49",
         ".NET CamelCase serializer lowercases all leading uppercase chars — property naming",
         "29 May log R-46..R-49: PRDate→prDate, UOM→uom, PRType→prType. Incorrect TypeScript names used across 8 files. TypeScript had pRDate, uOM, pRType — all wrong.",
         "Data mapping failure — 3 fields displayed empty/undefined in UI across multiple components. Required fix across 8 files.",
         "YES — Rule documented after discovery: always verify JSON property name against actual API response. Never assume from C# property name.",
         "Fixed. Add to onboarding: .NET CamelCase serializer lowercases all consecutive leading uppercase chars. Always test against live JSON response. Add JSON property naming tests."],
        ["DEF-14\nGAP-FE-06",
         "CSS class tb-btn does not exist globally — buttons render unstyled",
         "GAPS doc: PrForeclosureGrid.tsx and PrCancellationPage.tsx used className='tb-btn' raw buttons. No global CSS for tb-btn. Project uses Ant Design + inline styles + TbBtn component.",
         "BLOCKER — All toolbar buttons rendered as plain browser-default buttons with no Spinrise styling.",
         "YES — Reading the existing PRToolbar.tsx component (which exports TbBtn) before writing new toolbar code would have prevented this.",
         "Fixed: replaced with TbBtn/TbSep components. Add to code review: 'Use TbBtn component for all toolbar buttons — never raw button with className.'"],
        ["DEF-15\nGAP-FE-07",
         "App wrapper applied per-page inconsistently",
         "GAPS doc: PrForeclosurePage.tsx and PrCancellationPage.tsx wrapped with <App>. All other pages rely on app-level <App> in main.tsx. Inconsistent pattern.",
         "Cosmetic/maintainability issue. Nested App providers can cause unexpected behavior in Ant Design (duplicate context).",
         "YES — Pattern review of existing pages before building new ones.",
         "Low priority. Remove <App> wrappers from both page components."],
        ["DEF-16\nGAP-FE-08",
         "Keyboard handlers have stale closure risk — functions not in useCallback",
         "GAPS doc: PrCancellationPage.tsx useEffect depends on doCancel, doUndo, openCancelModal etc. None wrapped in useCallback. Functions recreated on every render — keyboard handler always calls stale version.",
         "WRONG — Ctrl+S, F3, Alt+X may call stale function versions after state updates. Intermittent, hard-to-reproduce behavior in production.",
         "YES — React hooks stale closure is a well-known pattern. Should be caught in code review.",
         "Wrap doCancel, doUndo, openCancelModal, openUndoModal, reset in useCallback with correct dependency arrays in usePrCancellation.ts."],
    ],
    col_widths=[1.5, 2.5, 3.0, 2.8, 1.3, 5.9])

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7 — ROOT CAUSE ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "7. ROOT CAUSE ANALYSIS", 1)

rca_data = [
    ("Requirement Failures", "RED", RED, 4, [
        ("FSD-01", "High", "SCCCODE column specified without DB verification"),
        ("FSD-02", "Critical", "PO_ORD table name not verified against live schema"),
        ("FSD-04", "High", "Cancel reason max length contradicted across 3 documents"),
        ("FSD-05", "Medium", "APPFLG filter in VB6 code not documented in FSD"),
        ("FSD-06", "High", "pre_cancel_status schema migration not in FSD"),
        ("FSD-08", "Medium", "FY filter scope not specified for Foreclosure"),
    ], "FSD was authored from VB6 source code reading without independent database schema verification. "
       "Column names, table names, and field lengths were assumed from VB6 code comments and hardcoded values "
       "rather than confirmed against the live SpinRiseSaranya database. This is the single largest root cause "
       "category — 6 FSD gaps trace directly to this failure.",
    "All FSD schema references must be verified against INFORMATION_SCHEMA before FSD is finalized. "
    "A mandatory 'DB Verification Gate' must be added to the FSD review process."),

    ("Design Failures", "ORANGE", ORANGE, 3, [
        ("UI-CN-01", "Critical", "6 FSD-specified columns missing from HTML cancellation item grid"),
        ("UI-FC-02", "Medium", "Date filter in FSD replaced with PR No filter in HTML without FSD update"),
        ("UI-CN-03", "High", "Reason field length/validation inconsistent between HTML and FSD"),
    ], "The UI/UX designer (Mariyaiya) did not perform a line-by-line field cross-reference between the "
       "FSD field table and the HTML prototype. The cancellation item grid is missing 6 out of 17 FSD-specified "
       "columns. The designer added features (KPI strip, Days Open) without FSD authorization and missed mandatory "
       "fields. The FSD field table should have been the primary input for grid column design.",
    "HTML prototype review must include a mandatory column-by-column checklist against FSD field table. "
    "Every column added beyond FSD scope must be explicitly noted and approved. Every FSD column must appear."),

    ("Documentation Failures", "ORANGE", ORANGE, 2, [
        ("DOC-01", "High", "Undo PRSTATUS set to NULL — incorrect (should restore previous status)"),
        ("DOC-06", "Low", "VB6 SQL injection note misapplied to SPINRISE (which uses parameterized queries)"),
    ], "The Mariyaiya documentation was written from the VB6 AS-IS code description rather than the "
       "SPINRISE TO-BE specification. Critical business rule BR-UNDO-01 (restore pre_cancel_status) was "
       "documented as NULL restoration — the opposite of the required behavior. VB6-specific security "
       "concerns were carried over without filtering AS-IS from TO-BE.",
    "Documentation must be authored against SPINRISE TO-BE specification in FSD, not from VB6 AS-IS "
    "code reading. A documentation QA review against FSD Section 4 business rules is mandatory."),

    ("Development Failures", "RED", RED, 5, [
        ("DEF-01/02", "Critical", "Dapper type mismatch (IsSample bool, prsno int) — 2 BLOCKERs"),
        ("DEF-06", "Blocker", "PRDocBand interface not read before use"),
        ("DEF-07", "Blocker", "UndoSubTab tautological conditional — still open"),
        ("DEF-14", "Blocker", "tb-btn CSS class assumed to exist without verification"),
        ("DEF-09", "High", "prsno=1 schema characteristic not discovered pre-development"),
    ], "The dominant development failure pattern is assumption-based development: column names assumed from "
       "FSD text, component interfaces assumed to match usage, CSS classes assumed to exist, DB schema "
       "characteristics assumed without verification. Five BLOCKERs out of 5 total were caused by failing "
       "to read and verify existing code/schema before writing new code.",
    "Mandatory pre-coding discovery phase: (1) Read all existing SPs touching target tables. "
    "(2) Read all shared component interfaces before importing. "
    "(3) Verify CSS class existence before use. "
    "(4) Check DB schema via sys.columns before writing SPs."),

    ("Review Failures", "ORANGE", ORANGE, 2, [
        ("GAP-FE-02", "Blocker", "UndoSubTab tautological expression survived code review"),
        ("GAP-FE-08", "Medium", "Stale closure risk in keyboard handlers survived review"),
    ], "Two logic errors that should have been caught in code review were missed. The tautological expression "
       "{label === 'Lines Restore To' ? label === 'Lines Restore To' && label : label} should be immediately "
       "identifiable as always-true in any code review. This suggests code review is either absent or cursory.",
    "Implement mandatory code review checklist including: "
    "(1) All conditional expressions must have distinct branches. "
    "(2) React hooks must have stable dependencies (useCallback for event handlers). "
    "(3) All component prop types must be verified against interface."),

    ("Testing Failures", "ORANGE", ORANGE, 2, [
        ("DEF-08", "Medium", "Auto-open behavior never tested against FSD/HTML specification"),
        ("DEF-12", "Critical", "Cancellable PRs list returned 0 rows — not caught before code submission"),
    ], "The cross-year PR collision bug (N-05) returned 0 cancellable PRs — a complete functional failure "
       "that should have been caught before the session log was written. The Playwright test suite was "
       "created during the 28 May session but 4 tests were still failing at session end. "
       "Auto-open behaviors matching the HTML prototype were not part of the test criteria.",
    "Test criteria must include: (1) API returns non-empty result set for test data. "
    "(2) Modal auto-open on page load (matches HTML prototype). "
    "(3) All items in FSD field table visible in grid. "
    "Playwright tests must achieve 0 failures before any session log is written."),
]

for rca_idx, (cat_name, rag, rag_color, issue_count, issues, analysis, corrective) in enumerate(rca_data):
    add_heading(doc, f"7.{rca_idx+1}  {cat_name}", 2)

    p = doc.add_paragraph()
    r1 = p.add_run(f"Issues: {issue_count}  |  RAG: ")
    r1.font.size = Pt(9)
    r1.bold = True
    r2 = p.add_run(rag)
    r2.bold = True; r2.font.color.rgb = rag_color; r2.font.size = Pt(9)
    p.paragraph_format.space_after = Pt(3)

    for g_id, sev, desc in issues:
        add_bullet(doc, f"[{sev}] {g_id}: {desc}", size=8.5)

    add_para(doc, f"Analysis: {analysis}", size=9, italic=True, space_after=3)
    add_para(doc, f"Corrective Action: {corrective}", size=9, bold=False, space_after=6)

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8 — COST OF REWORK ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "8. COST OF REWORK ANALYSIS", 1)

add_heading(doc, "8.1  Rework Volume Summary", 2)
make_table(doc,
    ["Category", "Count", "Sessions Affected", "% of Total Effort"],
    [
        ["Total resolution items logged",                "64 (R-01 to R-51 + 13 new)", "Both sessions", "100%"],
        ["Initial build (planned work)",                 "30 (R-01 to R-30)",           "28 May",         "~47%"],
        ["Rework — bug fixes Round 1 (plan items missed)", "9 (R-31 to R-39)",          "28 May",         "~14%"],
        ["Rework — bug fixes Round 2 (cut-off session)",   "12 (R-40 to R-51)",         "28 May (cut-off)", "~19%"],
        ["Rework — 29 May additional fixes",               "13 (N-01 to N-08 + gaps)", "29 May",           "~20%"],
        ["Preventable rework events (assumption-based)",   "≥ 18",                     "Both sessions",   "~28%"],
        ["Rework caused by FSD gaps",                      "8 events",                 "Both sessions",   "~13%"],
        ["Rework caused by UI mismatch",                   "4 events",                 "Both sessions",   "~6%"],
        ["Repeated defect pattern (type mapping)",         "3 occurrences",            "Both sessions",   "Systemic"],
    ],
    col_widths=[6.0, 3.5, 3.5, 4.0])

add_heading(doc, "8.2  Management Observations", 2)
observations = [
    "AVOIDABLE EFFORT: Approximately 28% of total development effort was spent on rework caused by "
    "assumption-based development. This is effort that generated zero business value — it fixed problems "
    "that should not have existed.",

    "BLOCKER ACCUMULATION: 5 BLOCKER-severity defects were accumulated before the first functional test. "
    "This indicates the development-to-testing feedback loop is too long. Blockers must be identified "
    "and fixed within the same coding session, not discovered at integration test.",

    "FSD GAP MULTIPLIER: Each FSD gap generated an average of 2.3 downstream rework events "
    "(FSD-01→DEF-09/N-01, FSD-02→DEF-04, FSD-04→GAP-BE-01/02). Investing in FSD quality prevents "
    "exponential rework downstream.",

    "SCHEMA VERIFICATION COST: The failure to verify DB schema before authoring SPs caused: "
    "(a) 2 BLOCKER Dapper type mismatches, (b) 1 CEO-mandated feature removal, (c) 1 placeholder SCCCODE, "
    "(d) 1 cross-FY collision bug, (e) 1 PO table name error. A single 30-minute schema discovery session "
    "would have prevented all 5.",

    "REPEATED DEFECT PATTERN: The Dapper type mapping error (SQL type ≠ C# type) occurred in 3 separate "
    "instances (IsSample, prsno in Cancellation, prsno in Foreclosure). This is a systemic gap in team "
    "knowledge that has not been addressed by a team-wide rule. It will recur in the next module.",

    "API ENDPOINT RISK: 4 of 6 API endpoints are not yet confirmed working as of 29 May EOD "
    "(/pr-cancellation/detail, /cancel, /undo, /pr-foreclosure/save). The module cannot proceed "
    "to UAT with 4 unconfirmed endpoints.",
]
for obs in observations:
    add_bullet(doc, obs, size=9)

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 9 — RECOMMENDATIONS
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "9. RECOMMENDATIONS", 1)

add_heading(doc, "9.1  Immediate Action Items (Before UAT)", 2)
make_table(doc,
    ["Priority", "Action", "Owner", "Deadline", "Ref"],
    [
        ["P1 — BLOCKER", "Fix GAP-FE-02: UndoSubTab badge renders wrong text. Replace tautological conditional. Remove duplicate grid block.", "Abinandan", "Next session — Day 1", "DEF-07"],
        ["P1 — BLOCKER", "Fix GAP-BE-03 + GAP-FE-03 together: Add canreason to SP SELECT → DTO → types.ts → UndoSubTab display.", "Abinandan", "Next session — Day 1", "DEF-03"],
        ["P1 — CEO", "DBA to query INFORMATION_SCHEMA and confirm correct PO order table name. Restore NOT EXISTS guard in ksp_PR_GetCancellablePRs.", "DBA / Sasi", "Immediate", "DEF-04/CF-02"],
        ["P2 — WRONG", "Fix GAP-BE-05: Extract SpinriseClaims.UserName in both controllers. Pass to LogDet_PO.username.", "Abinandan", "Next session", "DEF-05"],
        ["P2 — MISSING", "Fix GAP-FE-04: Implement auto-open cancel modal on page load in usePrCancellation.ts.", "Abinandan", "Next session", "DEF-08"],
        ["P2 — MISSING", "Fix GAP-FE-05: Implement auto-open undo modal on sub-tab switch in switchTab().", "Abinandan", "Next session", "DEF-08"],
        ["P2 — WRONG", "Fix GAP-FE-08: Wrap doCancel, doUndo, openCancelModal, openUndoModal, reset in useCallback.", "Abinandan", "Next session", "DEF-16"],
        ["P3 — CLEANUP", "Fix GAP-FE-07: Remove <App> wrappers from PrForeclosurePage and PrCancellationPage.", "Abinandan", "Next session", "DEF-15"],
        ["P3 — SCHEMA", "Verify rowversion migration (PO_PRH, PO_PRL) against live DB. Execute if missing.", "DBA / Sasi", "Before go-live", "FSD-07"],
        ["P3 — CONFIRM", "Confirm APPFLG filter requirement with business. Implement in SP if required.", "Sasi + Business", "Before UAT", "FSD-05"],
    ],
    col_widths=[2.5, 6.5, 2.2, 2.8, 1.5])

add_heading(doc, "9.2  Long-Term Process Improvements", 2)
make_table(doc,
    ["#", "Improvement", "Category", "Expected Benefit"],
    [
        ["LT-01", "Mandatory DB Schema Discovery Session before every FSD finalization. DBA runs SELECT on all referenced tables and columns. FSD author validates all column names against output before submission.", "Process", "Eliminates assumption-based column/table errors. Prevents FSD-01, FSD-02, DEF-01, DEF-02, DEF-04."],
        ["LT-02", "FSD Field Table Completeness Checklist: every grid column in UI must appear in FSD field table with DB source, data type, validation rule. TL-Dev validates this before Stage 2 sign-off.", "Review Gate", "Prevents UI-CN-01 (6 missing columns), UI-FC-01 (5 undocumented columns)."],
        ["LT-03", "Dapper Type Compatibility Table added to team standards. All SPs must CAST to target C# type at source. Code review checklist item.", "Development Standard", "Prevents DEF-01, DEF-02 and future occurrences of the same pattern across all modules."],
        ["LT-04", "Pre-Build Component Inventory: before building any new page, developer must list all shared components to be used, read their prop interfaces, and document expected props. Reviewed by TL-Dev.", "Development Process", "Prevents DEF-06 (PRDocBand), DEF-14 (tb-btn), and similar component misuse defects."],
        ["LT-05", "HTML Prototype Column Cross-Reference: mandatory for every grid in every prototype. Designer produces a column mapping table: HTML column → FSD column → DB column → Validation. Reviewed by TL-Dev.", "Design Process", "Prevents UI-CN-01 type gaps from being discovered at development or UAT stage."],
        ["LT-06", "Mariyaiya Documentation Review Protocol: documentation must be reviewed against FSD Section 4 (Business Rules) line by line before acceptance. Incorrect AS-IS VB6 details must be filtered.", "Documentation QA", "Prevents DOC-01 (wrong undo behavior), DOC-06 (VB6 security note), future documentation defects."],
        ["LT-07", "Playwright Test Zero-Fail Requirement: all Playwright tests must pass before session log is written. API test must confirm non-empty result sets for all list endpoints before proceeding to UI build.", "Testing Gate", "Prevents shipping with 4 failing tests as occurred in 28 May session."],
        ["LT-08", "FSD Change Control for Developer-Initiated Scope: when a developer adds a feature not in FSD (e.g., FY filter N-04, KPI strip), this must be raised as a CR and approved before implementation.", "Change Management", "Prevents undocumented scope additions that become implicit requirements in future sprints."],
    ],
    col_widths=[0.8, 6.0, 2.5, 7.2])

page_break(doc)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 10 — OPEN GAPS STATUS DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "10. OPEN GAPS STATUS DASHBOARD", 1)
add_para(doc, "Complete status of all identified gaps as of 29 May 2026 EOD:", size=9.5)

make_table(doc,
    ["Gap ID", "Severity", "Description", "Status", "Blocker For"],
    [
        ["GAP-BE-01", "FIXED",    "IsSample BIT cast in PrCancellationRepository",          "FIXED",   "—"],
        ["GAP-BE-02", "FIXED",    "prsno INT cast in PrCancellationRepository",               "FIXED",   "—"],
        ["GAP-BE-03", "WRONG",    "canreason not returned from GetCancelledPRsForUndo",       "OPEN",    "GAP-FE-03, Undo reason display"],
        ["GAP-BE-04", "MISSING",  "PO_ORD guard not implemented — CEO mandated",             "OPEN",    "Business integrity — PRs with POs cancellable"],
        ["GAP-BE-05", "WRONG",    "LogDet_PO.username stores userId not display name",        "OPEN",    "Audit log quality"],
        ["GAP-FE-01", "FIXED",    "PRDocBand interface extended for new pages",              "FIXED",   "—"],
        ["GAP-FE-02", "BLOCKER",  "UndoSubTab badge renders 'Lines Restore To' string",      "OPEN",    "UAT — Undo flow visually broken"],
        ["GAP-FE-03", "WRONG",    "Cancellation reason box shows date not reason",           "OPEN",    "Depends on GAP-BE-03"],
        ["GAP-FE-04", "MISSING",  "Cancel modal does not auto-open on page load",            "OPEN",    "FSD compliance, UX"],
        ["GAP-FE-05", "MISSING",  "Undo modal does not auto-open on tab switch",             "OPEN",    "FSD compliance, UX"],
        ["GAP-FE-06", "FIXED",    "tb-btn CSS class replaced with TbBtn component",         "FIXED",   "—"],
        ["GAP-FE-07", "COSMETIC", "<App> wrapper on page components",                        "OPEN",    "Maintainability only — low priority"],
        ["GAP-FE-08", "WRONG",    "Keyboard handlers stale closure risk (no useCallback)",   "OPEN",    "Intermittent F3/Ctrl+S failure"],
        ["FSD-SCCCODE", "Critical", "MM_MACMAS.SCCCODE column does not exist in live DB",   "OPEN",    "CEO-directed feature — Sub Cost Centre blank for all rows"],
        ["FSD-PO_ORD",  "Critical", "PO_ORD table name in FSD is incorrect",               "OPEN",    "CEO-mandated PO guard cannot be implemented"],
    ],
    col_widths=[2.2, 1.8, 5.5, 1.8, 5.7])

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 11 — CONCLUSION
# ══════════════════════════════════════════════════════════════════════════════

add_heading(doc, "11. CONCLUSION", 1)

add_para(doc,
    "The SPINRISE M01 PR Foreclosure and PR Cancellation/Undo modules represent a substantial build effort "
    "across two intensive development sessions totalling 64 resolution items. The development team has "
    "demonstrated technical competence and responsiveness in fixing defects as they were discovered. "
    "However, this report identifies systemic process failures that caused unnecessary rework, left critical "
    "business controls unimplemented, and produced a codebase that is not yet ready for UAT.",
    size=9.5)

add_para(doc,
    "The three most urgent actions for the CEO are:",
    size=9.5, bold=True)

add_bullet(doc,
    "IMMEDIATE: DBA must confirm the correct PO header table name so the CEO-mandated PO guard (OI-02-F2) "
    "can be restored. Every day this remains unresolved, users can cancel PRs that have active Purchase Orders.",
    size=9)

add_bullet(doc,
    "IMMEDIATE: DBA / Sasi must confirm the correct column for Sub Cost Centre in MM_MACMAS. "
    "The FSD-specified SCCCODE column does not exist. The CEO-directed feature shows placeholder data.",
    size=9)

add_bullet(doc,
    "NEXT SESSION PRIORITY: Abinandan must fix GAP-FE-02 (UndoSubTab badge BLOCKER) and "
    "GAP-BE-03+FE-03 (cancellation reason end-to-end) before any UAT activity commences.",
    size=9)

add_para(doc,
    "The root causes identified in this report — assumption-based development, insufficient FSD verification, "
    "absent component interface review, and inadequate pre-build schema discovery — are systemic and will "
    "recur in subsequent modules (M02, M03...) unless the long-term process improvements in Section 9.2 "
    "are implemented. The cost of prevention is a fraction of the cost of rework.",
    size=9.5, space_after=8)

add_para(doc,
    "This report is submitted for CEO review and decision on: (1) UAT readiness gate, "
    "(2) DBA engagement for schema verification, (3) process improvement approvals.",
    size=9.5, italic=True)

add_para(doc, " ", size=6)
add_para(doc, "─" * 80, size=7, color=GREY_MID)
add_para(doc, "Report prepared by: Claude Code — Senior ERP Business Analyst / Solution Architect / QA Lead / Delivery Auditor", size=8, italic=True, color=GREY_MID)
add_para(doc, "Sources: FSD v1.1 (19 May 2026) · HTML Prototypes (IST Cleared 23 May 2026) · Dev Logs (28–29 May 2026) · Mariyaiya Documentation", size=8, italic=True, color=GREY_MID)
add_para(doc, "CONFIDENTIAL — For CEO and Senior Management Use Only", size=8, bold=True, color=RED)

# ── Save ──────────────────────────────────────────────────────────────────────
out_path = r"D:\SpinriseV2\Docs\CEO_Gap_Analysis_Report_M01_PRForeclosure_Cancellation_29May2026.docx"
doc.save(out_path)
print(f"SAVED: {out_path}")
