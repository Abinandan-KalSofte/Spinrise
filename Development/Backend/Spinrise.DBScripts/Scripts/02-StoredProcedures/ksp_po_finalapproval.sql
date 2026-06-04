-- ============================================================
-- SP: ksp_po_finalapproval
-- Purpose: Final Level PR Approval — Grid load (imode 2/3) and Save (imode 4)
-- FSD: v1.4  |  Mockdown: SPINRISE_M01_FinalLevel_PR_Approval_Mockdown.md §4-§8
-- Author: Mohan Babu  |  Date: [implementation date]
-- DB: JAT (172.16.16.52\sql2016)
-- ============================================================
-- CD Fixes applied vs VB6 AS-IS:
--   CD-07: @logindate removed — SP uses GETDATE() internally
--   CD-08: @FinalLevel_Remarks is int; stored as CAST(int -> varchar)
--   CD-09: All PRINT statements removed
--   CD-10: Phone lookup (@phno) inside imode=4 block only
--   CD-11: Al_SMSMessage INSERT for Disposition=5 includes SendDate + NoofTry
--   CD-12: CAST(@Prdate AS DATE) used; @@ROWCOUNT checked
-- OI-09: FirstApp NOT written by this SP.
--        SecondApp='Y' written ONLY when @Bypass=1.
-- OBS-2: imode=1 does NOT exist.
--        Company=ALL -> imode=2, divcode='0'.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_finalapproval]
    @imode              int,
    @divcode            varchar(2),
    @dbname             varchar(20)     = NULL,
    @Prno               numeric(6,0)    = NULL,
    @Prdate             datetime        = NULL,
    @Prsno              numeric(5,0)    = NULL,
    @FinalAppUser       varchar(35)     = NULL,
    @FinalAppQty        numeric(12,3)   = NULL,
    @FinalLevel_Remarks int             = NULL,   -- CD-08: int (not varchar)
    @Bypass             int             = 1,
    @row_version        binary(8)       = NULL,
    @Result             int             OUTPUT    -- 0=success, 2=business, 3=conflict, 4=not found
AS
BEGIN
    SET NOCOUNT ON;

    -- ── imode 2/3 — SELECT pending grid rows ──────────────────────────────────
    -- imode=2: all divisions (Company=ALL or Division=ALL) — no division filter
    -- imode=3: specific division
    IF @imode IN (2, 3)
    BEGIN
        SELECT
            l.divcode,
            h.prno,
            CONVERT(varchar(10), h.prdate, 103)         AS prdate,
            l.prsno,
            d.DEPNAME                                   AS department,
            l.itemcode                                  AS itemCode,
            i.ITEMNAME                                  AS itemName,
            i.UOM                                       AS uom,
            -- TODO: Replace with stock functions once confirmed to exist in JAT DB.
            --       KSP_PRItemStock_FUN and KSP_PRItemStock_WITH_DIV not found in JAT.
            --       Using PO_PRL.curstock as fallback (confirmed column, schema §PO_PRL).
            ISNULL(l.curstock, 0)                       AS currentStock,
            CASE
                WHEN l.ThirdAppQty  > 0 THEN l.ThirdAppQty
                WHEN l.SecondAppQty > 0 THEN l.SecondAppQty
                WHEN l.FirstAppQty  > 0 THEN l.FirstAppQty
                ELSE l.qtyreqd
            END                                         AS qtyRequired,
            ISNULL(l.FinalAppQty,
                CASE
                    WHEN l.ThirdAppQty  > 0 THEN l.ThirdAppQty
                    WHEN l.SecondAppQty > 0 THEN l.SecondAppQty
                    WHEN l.FirstAppQty  > 0 THEN l.FirstAppQty
                    ELSE l.qtyreqd
                END)                                    AS qtyApproved,
            ISNULL(TRY_CAST(l.FinalLevel_Remarks AS int), 2) AS disposition,
            l.LPO_RATE                                  AS lpoRate,
            CASE
                WHEN l.LPO_DATE IS NOT NULL
                THEN CONVERT(varchar(10), l.LPO_DATE, 103)
                ELSE NULL
            END                                         AS lpoDate,
            CASE WHEN ISNULL(l.APPCOST, 0) = 0
                THEN NULL
                ELSE l.APPCOST
            END                                         AS approxCost,
            CASE
                WHEN l.ThirdApp  IS NOT NULL AND l.ThirdApp  = 'Y' THEN 'final'
                WHEN l.SecondApp IS NOT NULL AND l.SecondApp = 'Y' THEN 'second'
                ELSE 'first'
            END                                         AS approvalStatus,
            -- Return raw timestamp; C# layer converts to hex via Convert.ToHexString
            l.row_version                               AS rowVersion
        FROM   PO_PRL  l
        JOIN   PO_PRH  h  ON  h.divcode = l.divcode
                          AND h.prno    = l.prno
                          AND CAST(h.prdate AS DATE) = CAST(l.prdate AS DATE)
        JOIN   IN_DEP  d  ON  d.DEPCODE = h.depcode
                          AND d.divcode = h.divcode
        JOIN   IN_ITEM i  ON  i.ITEMCODE = l.itemcode
        WHERE  ISNULL(l.prstatus, '') NOT IN ('C', 'X', 'Z', 'O', 'D')
          AND  ISNULL(h.cancelflag, 'N') <> 'Y'
          AND  l.FirstApp = 'Y'
          AND  (
                @Bypass = 1
                OR (
                    @Bypass = 0
                    AND (ISNULL(l.SecondApp, 'N') = 'Y' OR ISNULL(l.ThirdApp, 'N') = 'Y')
                )
               )
          AND  (@imode = 2 OR l.divcode = @divcode)
        ORDER BY l.divcode, h.prno, h.prdate, l.prsno;

        SET @Result = 0;
        RETURN;
    END

    -- ── imode=4 — SAVE (one row per call; backend loops) ─────────────────────
    IF @imode = 4
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Guard: cancelled PR
            IF EXISTS (
                SELECT 1 FROM PO_PRH
                WHERE divcode  = @divcode
                  AND prno     = @Prno
                  AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE)
                  AND cancelflag = 'Y'
            )
            BEGIN
                SET @Result = 2;
                RAISERROR('This PR has been cancelled and cannot be approved.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- UPDATE PO_PRL with concurrency guard on row_version
            UPDATE PO_PRL
            SET
                FinalAppUser       = @FinalAppUser,
                prstatus           = 'D',
                DirectApp          = 'Y',
                -- OI-09: SecondApp='Y' ONLY when Bypass is active
                SecondApp          = CASE WHEN @Bypass = 1 THEN 'Y' ELSE SecondApp END,
                ThirdApp           = 'Y',
                DirectAppDate      = GETDATE(),
                qtyreqd            = @FinalAppQty,
                FinalAppQty        = @FinalAppQty,
                FinalLevel_Remarks = CAST(@FinalLevel_Remarks AS varchar(20)),   -- CD-08
                FClosed            = CASE WHEN @FinalLevel_Remarks = 4 THEN 'Y' ELSE FClosed END,
                FCloseddt          = CASE WHEN @FinalLevel_Remarks = 4 THEN GETDATE() ELSE FCloseddt END
            WHERE divcode     = @divcode
              AND prno        = @Prno
              AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE)   -- CD-12
              AND prsno       = @Prsno
              AND row_version = @row_version;                     -- concurrency guard

            -- CD-12: Check if UPDATE matched a row
            IF @@ROWCOUNT = 0
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM PO_PRL
                    WHERE divcode = @divcode AND prno = @Prno
                      AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE)
                      AND prsno = @Prsno
                )
                    SET @Result = 3;   -- concurrency conflict
                ELSE
                    SET @Result = 4;   -- not found
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- UPDATE PO_PRH — ISNULL pattern so existing approvals are preserved
            UPDATE PO_PRH
            SET
                APPFLG   = 'Y',
                APP1     = ISNULL(APP1,    'DIR'),
                APP1DATE = ISNULL(APP1DATE, GETDATE()),
                APP1TIME = ISNULL(APP1TIME, GETDATE()),
                APP2     = ISNULL(APP2,    'DIR'),
                APP2DATE = ISNULL(APP2DATE, GETDATE()),
                APP2TIME = ISNULL(APP2TIME, GETDATE()),
                APP3     = ISNULL(APP3,    'DIR'),
                APP3DATE = ISNULL(APP3DATE, GETDATE()),
                APP3TIME = ISNULL(APP3TIME, GETDATE())
            WHERE divcode = @divcode
              AND prno    = @Prno
              AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE);

            -- UPDATE PO_Para — PRSMSStatusFlg
            -- TODO: Confirm key column(s) for WHERE clause with DBA (currently keyed by divcode)
            UPDATE PO_Para
            SET    PRSMSStatusFlg = 'Y'
            WHERE  divcode = @divcode;

            -- CD-10: Phone lookup (inside imode=4 only — moved from outer scope)
            DECLARE @phno varchar(20) = NULL;
            -- TODO: Confirm phone source table and column name with DBA
            -- Example:
            -- SELECT @phno = [phone_column] FROM [phone_table] WHERE [key_condition];

            -- SMS INSERT — Remarks=1/3/4/5 per FSD v1.4 OI-09 / QA directive 29-May-2026
            -- Guard: PO_PARA.PRSMSSendFlg='Y' (CEO referenced FinalApproval_SMSEnabled which
            -- does not exist in live DB; PRSMSSendFlg is the PR SMS send control flag)
            -- Column names verified from live SpinRiseSaranya DDL (1 Jun 2026)
            IF @FinalLevel_Remarks IN (1, 3, 4, 5)
               AND EXISTS (
                   SELECT 1 FROM PO_Para
                   WHERE divcode = @divcode
                     AND ISNULL(PRSMSSendFlg, 'N') = 'Y'
               )
            BEGIN
                INSERT INTO Al_SMSMessage (
                    Divcode, SmsMobileNo, SmsMsg,
                    EntryDate, EntryUserID, NoofTry, SendDate, Sendflg
                )
                VALUES (
                    @divcode,
                    @phno,
                    CASE @FinalLevel_Remarks
                        WHEN 1 THEN 'PR No.' + CAST(@Prno AS varchar(10)) + ' has been set to PL Discuss'
                        WHEN 3 THEN 'PR No.' + CAST(@Prno AS varchar(10)) + ' is on Hold'
                        WHEN 4 THEN 'PR No.' + CAST(@Prno AS varchar(10)) + ' has been Declined'
                        WHEN 5 THEN 'PR No.' + CAST(@Prno AS varchar(10)) + ' has been Postponed'
                    END,
                    GETDATE(), @FinalAppUser, 0, NULL, 'P'
                );
            END

            -- Audit log
            INSERT INTO LogDet_po (
                divcode, prno, prdate, prsno,
                prstatus, Trans_UserId, Trans_date,
                Trans_Name, Trans_Mod, Activity
            )
            VALUES (
                @divcode, @Prno, @Prdate, @Prsno,
                'D', @FinalAppUser, GETDATE(),
                'Final Level PR Approval', 'FinalApp',
                CASE @FinalLevel_Remarks
                    WHEN 1 THEN 'PL_DISCUSS'
                    WHEN 2 THEN 'APPROVED'
                    WHEN 3 THEN 'HOLD'
                    WHEN 4 THEN 'DECLINED'
                    WHEN 5 THEN 'POSTPONED'
                END
            );

            COMMIT TRANSACTION;
            SET @Result = 0;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @Result = 2;
            THROW;
        END CATCH
    END

END;
GO
