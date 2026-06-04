"""
SPINRISE M01 — Rollout Confirmation Email Script
Sends confirmation mail to CEO/QA covering all 7 action items.

Usage:
    python send_confirmation_email.py [--preview] [--send]
    --preview : Print email to console only (default)
    --send    : Actually send via SMTP (reads credentials from Thunderbird prefs.js)
"""

import argparse
import smtplib
import sys
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path


# ── Email recipients ──────────────────────────────────────────────────────────
FROM_ADDR  = "abinandan.n@kalsofte.com"
TO_ADDRS   = ["abinandan.n@kalsofte.com"]
CC_ADDRS   = [
    
]


def build_email_body() -> str:
    today = datetime.now().strftime("%d %B %Y")
    return f"""Dear Sir,

This is to confirm the status of all 7 action items directed in the CEO Final Rollout Call mail (31 May 2026). All items are addressed as of {today}.

─────────────────────────────────────────────────────
ABINANDAN — 7 ACTION ITEMS — CONFIRMATION
─────────────────────────────────────────────────────

1. PR First Level Approval — DEF-FA-01 to DEF-FA-07 (All 7 Defects)
   Status: FIXED AND DEPLOYED
   Details:
   — DEF-FA-01 (P1): Server-side qty validation added in PrFirstApprovalService.cs and ksp_PR_SaveFirstApproval SP. Save is now blocked at both frontend and backend when First Approval Quantity exceeds Quantity Required.
   — DEF-FA-03 (P1): PO_PRH header APPFLG='Y' is now set conditionally — only when ALL PO_PRL lines for the PR have FirstApp='Y'. Partial approval no longer marks the PR as fully First Approved.
   — DEF-FA-04/05: Mode transition to SAVED is now set immediately on successful save, before the detail refresh. Form is read-only in SAVED mode regardless of refresh outcome.
   — DEF-FA-02: Validation message corrected to "Quantity Required" (was "Required Quantity").
   — DEF-FA-06: Find mode correctly uses SAVED filter (firstApp='Y' lines only) — already handled in page handler; verified.
   — DEF-FA-07: pendingList cleared on save so the next Load PRs re-fetches fresh from API. SP fix for DEF-FA-03 ensures fully approved PRs drop from pending list naturally.
   — FA-ADD-12: First Approval Quantity pre-fills with Quantity Required on PR load in APPROVE mode (already implemented in loadDetail; verified).
   Playwright regression tests: def-fa-fixes.spec.ts (9 test cases: DEF-FA-01-A, 01-B, 02-A, 04-A, 05-A, 06-A, 07-A, FA-ADD-12-A)

2. PR Foreclosure — PRSTATUS WHERE Clause (Both SPs)
   Status: FIXED AND DEPLOYED
   Details: Both stored procedures updated:
   — ksp_PR_GetOpenForForeclosure: WHERE clause changed from two separate <>'C'/<>'X' conditions to NOT IN ('O','E','C','Z','X').
   — ksp_PR_SaveForeclosureLine: WHERE clause changed from <>'C' to NOT IN ('O','E','C','Z','X').
   This ensures Ordered, Enquired, Received, Force Closed, and Cancelled lines are all excluded from both the Foreclosure grid and the Save path.
   merged.sql: Updated with both SP changes.
   Playwright regression tests: FC-PRSTATUS-A, FC-PRSTATUS-B added to foreclosure.spec.ts.

3. PR-06 Current Stock Print Fix
   Status: CONFIRMED DEPLOYED ✅
   Details: PR-06 Current Stock column fix is deployed and working. Mariyaiya confirmed Pass on 30 May 2026. Fix confirmed via QuestPDF — Current Stock is sourced from PO_PRL.curstock (ISNULL → 0.000).

4. Company Name Dynamic Fetch — All M01 Screens
   Status: CONFIRMED DEPLOYED AND QA-ACCEPTED ✅
   Details: Company name is now fetched dynamically from the compmas table via ksp_Auth_GetCompanies stored procedure. The selected company name is stored in the user session at login and displayed in the application header across ALL M01 screens. QA accepted this fix at 19:31 on 31 May 2026 (email: "CR-M01-FL-007 — Company Name dynamic fetch. Accepted.").

5. Approval Badge Labels — po_para.appuserlabel1/2/3
   Status: FIXED AND DEPLOYED ✅
   Details: PR Final Level Approval grid legend labels are now loaded dynamically from po_para.appuserlabel1, appuserlabel2, appuserlabel3 via the existing ksp_PR_GetPoPara stored procedure. Labels default to 'First', 'Second', 'Third' if fetch fails. For JAT, these will display the configured values (e.g., SM, FM, GM). Labels are no longer hardcoded.

6. Al_SMSMessage — PO_PARA.PRSMSSendFlg (Final Level SP)
   Status: IMPLEMENTED IN SP ✅
   Details: ksp_po_finalapproval imode=4 now inserts into Al_SMSMessage for FinalLevel_Remarks = 1 (PL Discuss), 3 (Hold), 4 (Declined), and 5 (Postponed), guarded by PO_PARA.PRSMSSendFlg='Y'. Column names verified from live SpinRiseSaranya DDL (1 Jun 2026): SmsMobileNo, SmsMsg, Divcode, EntryDate, EntryUserID, NoofTry, SendDate, Sendflg. Remarks=2 (Approved, normal path) does not trigger an SMS per business rule.
   Note: CEO referenced PO_PARA.FinalApproval_SMSEnabled — this column does not exist in the live database. PRSMSSendFlg is the PR SMS send control flag confirmed in PO_PARA DDL and has been used as the guard. Please confirm this is the correct flag for Final Level SMS trigger at SKS Mills.
   Rowversion concurrency guard: ksp_po_finalapproval imode=4 includes WHERE row_version = @row_version on PO_PRL UPDATE with @@ROWCOUNT=0 → HTTP 409 per FSD v1.4 CD-12. This is deployed and active.

7. Undo Cancellation SP — ksp_PR_UndoCancellation
   Status: CONFIRMED DEPLOYED ✅
   Details: SP-I1 (rowversion fix) is deployed. Trans_Name is corrected. SP-I2 (depcode asymmetry comment) is pending Sasi — this is Sasi's action item and does not block rollout. BR-UNDO-01 (NULL revert confirmed correct) is implemented and verified.

─────────────────────────────────────────────────────
DEPLOYMENT DETAILS
─────────────────────────────────────────────────────
Server       : http://172.16.16.40:3000 (Frontend) / http://172.16.16.40:5001 (API)
Database     : JAT (172.16.16.52\\sql2016)
SP deploy    : merged.sql executed against SpinRiseSaranya

─────────────────────────────────────────────────────
PENDING FROM OTHERS (not Abinandan)
─────────────────────────────────────────────────────
— Sasi: Confirm PRSMSSendFlg is the correct column for Final Level SMS trigger at SKS Mills (CEO referenced FinalApproval_SMSEnabled which does not exist in live DB — PRSMSSendFlg used as the SMS send control flag).
— SP-I2 comment (Sasi): ksp_PR_UndoCancellation SP header comment for depcode asymmetry.
— Palanivel: IST retest for DEF-FA-01 to 07 on deployed build. Report pass/fail by tomorrow morning.
— Palanivel: IST retest for FC-EX-09/FC-BR-03 (5 PRSTATUS scenarios) on redeployed Foreclosure SP.
— Sasi: DB Migration scripts confirmation on JAT and SCMTS databases.
— Sasi: PendingOrderPara='N' confirmation on all divisions.

─────────────────────────────────────────────────────
Requesting your review and Go/No-Go decision by tomorrow noon for the afternoon rollout.

Thanks & Regards,
Abinandan N
Developer — M01 PR Module
Kalpatharu Software Ltd
"""


def read_smtp_config() -> dict:
    """Read SMTP server config from Thunderbird prefs.js."""
    prefs_path = Path(r"C:\Users\Admin\AppData\Roaming\Thunderbird\Profiles\fjzej4xv.default-release\prefs.js")
    config = {"host": "mail.kalsofte.com", "port": 587, "user": FROM_ADDR}
    if prefs_path.exists():
        text = prefs_path.read_text(encoding="utf-8", errors="ignore")
        for line in text.splitlines():
            if "mail.smtpserver" in line and "hostname" in line:
                val = line.split('"')[-2] if '"' in line else ""
                if val:
                    config["host"] = val
            if "mail.smtpserver" in line and "port" in line:
                val = line.split('"')[-2] if '"' in line else ""
                if val.isdigit():
                    config["port"] = int(val)
    return config


def send_email(password: str) -> None:
    cfg  = read_smtp_config()
    body = build_email_body()

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"REG: SPINRISE M01 — Rollout Action Item Confirmation — All 7 Items Addressed | {datetime.now().strftime('%d %b %Y')}"
    msg["From"]    = FROM_ADDR
    msg["To"]      = ", ".join(TO_ADDRS)
    msg["Cc"]      = ", ".join(CC_ADDRS)
    msg.attach(MIMEText(body, "plain"))

    all_recipients = TO_ADDRS + CC_ADDRS
    print(f"\nConnecting to {cfg['host']}:{cfg['port']} ...")
    with smtplib.SMTP(cfg["host"], cfg["port"], timeout=15) as srv:
        srv.ehlo()
        srv.starttls()
        srv.ehlo()
        srv.login(cfg["user"], password)
        srv.sendmail(FROM_ADDR, all_recipients, msg.as_string())
    print("Email sent successfully.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true", default=True, help="Print email to console (default)")
    parser.add_argument("--send",    action="store_true", help="Send via SMTP")
    args = parser.parse_args()

    body = build_email_body()

    if args.send:
        password = input(f"SMTP password for {FROM_ADDR}: ")
        if not password:
            print("No password provided. Aborting.")
            sys.exit(1)
        send_email(password)
    else:
        cfg = read_smtp_config()
        print("=" * 70)
        print("EMAIL PREVIEW (run with --send to actually send)")
        print("=" * 70)
        print(f"From   : {FROM_ADDR}")
        print(f"To     : {', '.join(TO_ADDRS)}")
        print(f"CC     : {', '.join(CC_ADDRS)}")
        print(f"SMTP   : {cfg['host']}:{cfg['port']}")
        print("=" * 70)
        sys.stdout.buffer.write(body.encode("utf-8")); sys.stdout.buffer.write(b"\n")
        print("=" * 70)
        print("\nRun with --send to dispatch this email.")


if __name__ == "__main__":
    main()
