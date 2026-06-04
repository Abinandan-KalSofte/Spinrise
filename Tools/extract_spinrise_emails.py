"""
SPINRISE M01 Email Extractor
Reads Thunderbird MBOX files, filters last 2 weeks of SPINRISE-related emails,
saves bodies + attachments, outputs email_index.csv
"""

import mailbox
import email
import email.utils
import os
import csv
import re
import hashlib
from pathlib import Path
from datetime import datetime, timezone, timedelta

# ── Config ───────────────────────────────────────────────────────────────────

PROFILE = r"C:\Users\Admin\AppData\Roaming\Thunderbird\Profiles\fjzej4xv.default-release\Mail"

MBOX_SOURCES = [
    (r"mail.kalsofte-4.com\Inbox",    "Inbox-Primary"),
    (r"mail.kalsofte.com\Inbox",      "Inbox-Secondary"),
    (r"mail.kalsofte-4.com\Sent",     "Sent"),
    (r"mail.kalsofte-4.com\External", "External"),
]

CUTOFF_DATE = datetime(2026, 5, 17, tzinfo=timezone.utc)

KEYWORDS = [
    "spinrise", "pr form", "first level", "final level", "foreclosure",
    "cancellation", "def-fa", "prstatus", "pr-06", "pr-12", "pr-20",
    "il-35", "il-36", "fa-add", "badge", "appuserlabel", "sms",
    "undo", "ksp_pr", "jat", "scmts", "m01", "ist result", "ist pass",
    "ist fail", "abinandan", "palanivel", "mariyaiya", "muthuvel",
    "defect", "checklist", "tracker", "blueprint", "fsd", "ksp_pr_",
    "po_para", "prapproval", "fc-ex", "fc-br", "sp-i1", "sp-i2",
    "dep-fa", "dep-fc", "dep-can", "pr transaction", "pr approval",
    "purchase requisition",
]

OUT_DIR      = Path(r"D:\SpinriseEmailExtract")
BODIES_DIR   = OUT_DIR / "bodies"
ATT_DOCX     = OUT_DIR / "attachments" / "docx"
ATT_XLSX     = OUT_DIR / "attachments" / "xlsx"
ATT_PDF      = OUT_DIR / "attachments" / "pdf"
ATT_IMAGES   = OUT_DIR / "attachments" / "images"
INDEX_CSV    = OUT_DIR / "email_index.csv"

EXT_MAP = {
    ".docx": ATT_DOCX, ".doc": ATT_DOCX,
    ".xlsx": ATT_XLSX, ".xls": ATT_XLSX,
    ".pdf":  ATT_PDF,
    ".png":  ATT_IMAGES, ".jpg": ATT_IMAGES,
    ".jpeg": ATT_IMAGES, ".gif": ATT_IMAGES,
    ".bmp":  ATT_IMAGES,
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def parse_date(msg):
    date_str = msg.get("Date", "")
    try:
        t = email.utils.parsedate_to_datetime(date_str)
        if t.tzinfo is None:
            t = t.replace(tzinfo=timezone.utc)
        return t
    except Exception:
        return None

def is_recent(dt):
    return dt is not None and dt >= CUTOFF_DATE

def contains_keyword(text):
    low = text.lower()
    return any(k in low for k in KEYWORDS)

def get_body(msg):
    body_parts = []
    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            cd = part.get("Content-Disposition", "")
            if ct == "text/plain" and "attachment" not in cd:
                try:
                    charset = part.get_content_charset() or "utf-8"
                    body_parts.append(part.get_payload(decode=True).decode(charset, errors="replace"))
                except Exception:
                    pass
    else:
        try:
            charset = msg.get_content_charset() or "utf-8"
            body_parts.append(msg.get_payload(decode=True).decode(charset, errors="replace"))
        except Exception:
            pass
    return "\n".join(body_parts)

def safe_filename(name):
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name)
    return name[:180]

def save_attachments(msg, email_id):
    saved = []
    if not msg.is_multipart():
        return saved
    for part in msg.walk():
        cd = part.get("Content-Disposition", "")
        filename = part.get_filename()
        if not filename:
            continue
        filename = email.header.decode_header(filename)
        decoded_parts = []
        for frag, enc in filename:
            if isinstance(frag, bytes):
                decoded_parts.append(frag.decode(enc or "utf-8", errors="replace"))
            else:
                decoded_parts.append(frag)
        filename = "".join(decoded_parts)
        ext = Path(filename).suffix.lower()
        target_dir = EXT_MAP.get(ext)
        if target_dir is None:
            continue
        safe_name = f"email{email_id:04d}_{safe_filename(filename)}"
        out_path = target_dir / safe_name
        if not out_path.exists():
            try:
                data = part.get_payload(decode=True)
                if data:
                    out_path.write_bytes(data)
                    saved.append(safe_name)
            except Exception as e:
                saved.append(f"[ERROR saving {filename}: {e}]")
        else:
            saved.append(safe_name + " (already exists)")
    return saved

def msg_id(msg):
    return msg.get("Message-ID", "").strip()

# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    seen_ids = set()
    rows = []
    email_counter = 0

    for rel_path, label in MBOX_SOURCES:
        full_path = os.path.join(PROFILE, rel_path)
        if not os.path.exists(full_path):
            print(f"  SKIP (not found): {full_path}")
            continue
        print(f"\nReading {label}: {full_path}")
        try:
            mbox = mailbox.mbox(full_path, factory=None, create=False)
        except Exception as e:
            print(f"  ERROR opening: {e}")
            continue

        count_total = 0
        count_matched = 0

        for msg in mbox:
            count_total += 1
            dt = parse_date(msg)
            if not is_recent(dt):
                continue

            subject = msg.get("Subject", "")
            try:
                decoded_subject = ""
                for frag, enc in email.header.decode_header(subject):
                    if isinstance(frag, bytes):
                        decoded_subject += frag.decode(enc or "utf-8", errors="replace")
                    else:
                        decoded_subject += frag
                subject = decoded_subject
            except Exception:
                pass

            body = get_body(msg)
            haystack = subject + " " + body

            if not contains_keyword(haystack):
                continue

            mid = msg_id(msg)
            if mid and mid in seen_ids:
                continue
            if mid:
                seen_ids.add(mid)

            email_counter += 1
            count_matched += 1
            eid = email_counter

            # Save body
            body_file = BODIES_DIR / f"email_{eid:04d}.txt"
            header_block = (
                f"FOLDER : {label}\n"
                f"DATE   : {dt.strftime('%Y-%m-%d %H:%M %Z') if dt else 'unknown'}\n"
                f"FROM   : {msg.get('From', '')}\n"
                f"TO     : {msg.get('To', '')}\n"
                f"CC     : {msg.get('Cc', '')}\n"
                f"SUBJECT: {subject}\n"
                f"{'='*80}\n\n"
            )
            body_file.write_text(header_block + body, encoding="utf-8", errors="replace")

            # Save attachments
            att_list = save_attachments(msg, eid)

            rows.append({
                "id":           eid,
                "folder":       label,
                "date":         dt.strftime("%Y-%m-%d %H:%M") if dt else "",
                "from":         msg.get("From", ""),
                "to":           msg.get("To", ""),
                "subject":      subject,
                "body_file":    body_file.name,
                "attachments":  "; ".join(att_list),
                "message_id":   mid,
            })

        print(f"  Scanned {count_total} messages -> {count_matched} matched")

    # Write CSV index
    if rows:
        with open(INDEX_CSV, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
        print(f"\nDone. {len(rows)} emails saved to {OUT_DIR}")
        print(f"Index: {INDEX_CSV}")
    else:
        print("\nNo matching emails found in the date range.")


if __name__ == "__main__":
    main()
