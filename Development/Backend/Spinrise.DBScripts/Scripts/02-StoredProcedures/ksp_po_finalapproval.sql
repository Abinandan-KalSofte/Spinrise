-- ============================================================
-- SP: ksp_po_finalapproval
-- Purpose: Final Level PR Approval — Grid (imode 2/3), Save (imode 4)
-- Original author: Menaga.M (modified 15 Jul 2013)
-- Compatibility hotfix: 06 Jun 2026
--   Single SP supports both Legacy VB6/ASP.NET and Spinrise V2 simultaneously.
--   No changes required in VB6, ASP.NET, or Spinrise C# backend code.
-- Approved by: Sasi (FirstApp='Y' and SecondApp='Y' unconditional in imode=4)
-- DB: JAT (172.16.16.52\sql2016)
-- ============================================================
-- COMPATIBILITY DESIGN:
--   Parameters : All original VB6 params restored (exact order + types).
--                V2 params (@dbname, @row_version, @Result) appended with NULL
--                defaults — VB6 callers omit them safely.
--   @FinalLevel_Remarks : Restored to varchar(20). SQL Server implicitly converts
--                         Spinrise int values on assignment.
--   SELECT (imode 2/3) : VB6 original columns in original order.
--                        V2 Spinrise columns appended at end — Dapper maps by name.
--   imode=4 UPDATE : Original VB6 logic restored (FirstApp/SecondApp/ThirdApp='Y').
--                    row_version guard applied only when @row_version IS NOT NULL.
--                    @Result OUTPUT has NULL default — VB6 omits it, Spinrise reads it.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_finalapproval]
(
    -- Original VB6 parameters — exact original order and types
    @imode              int             = null,
    @divcode            varchar(2)      = null,
    @FinalAppUser       varchar(35)     = null,
    @FinalAppQty        numeric(12,3)   = null,
    @FinalLevel_Remarks varchar(20)     = null,
    @prno               numeric(6)      = null,
    @prdate             datetime        = null,
    @prsno              numeric(5)      = null,
    @logindate          datetime        = null,
    @Bypass             int             = null,
    -- Spinrise V2 parameters — NULL defaults so VB6 callers safely omit them
    @dbname             varchar(20)     = null,
    @row_version        binary(8)       = null,
    @Result             int             = null OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @phno        VARCHAR(50),
            @FinFromDate DATETIME,
            @ToFinYear   DATETIME;

    -- Financial year lookup (restored from original)
    SELECT @FinFromDate = py.AYFDATE,
           @ToFinYear   = GETDATE()
    FROM   PP_YEAR py
    WHERE  py.AYFDATE <= GETDATE()
      AND  py.AYLDATE  >= GETDATE();

    -- Phone lookup for SMS (restored to top-level from original)
    SET @phno = (
        SELECT DISTINCT TOP 1 ISNULL(CONVERT(varchar(50), phone), '')
        FROM (
            SELECT DISTINCT phone, ae.EmpNo FROM Al_Emp  ae WHERE phone <> ''
            UNION ALL
            SELECT DISTINCT phone, ae.EmpNo FROM PR_EMP  ae WHERE phone <> ''
        ) A
        WHERE A.EmpNo IN (
            SELECT pe.empno
            FROM   PO_PRH  pp
            INNER JOIN PR_EMP pe ON pe.divcode = pp.divcode
                                AND pp.REQNAME = CONVERT(varchar(10), pe.empno)
            WHERE  pp.prno   = @prno
              AND  pp.prdate = @prdate
        )
    );

    -- ── imode 2/3 — SELECT grid rows ─────────────────────────────────────────
    -- imode=2 : all divisions (no divcode filter)
    -- imode=3 : single division (adds hd.divcode = @divcode to WHERE)
    -- @Bypass=1   : items where FirstApp is set (any first-approved)
    -- @Bypass=0/null : items where FirstApp + SecondApp + ThirdApp are all set
    IF @imode IN (2, 3)
    BEGIN
        SELECT
            -- ── VB6 original columns in original order ──────────────────────
            DB_NAME()                                                   AS CName,
            div.divcode,
            div.abbr,
            div.divname,
            hd.Prno,
            hd.Prdate,
            dt.prsno,
            dt.itemcode,
            itm.itemname,
            itm.uom,
            dep.Depname,
            ISNULL(S.SccName, '')                                       AS SccName,
            hd.depcode,
            ISNULL(hd.SubCost, 0)                                      AS SubCost,
            dt.qtyind,
            CASE
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.FirstAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0 THEN dt.qtyreqd
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0
                 AND dt.FirstAppQty > 0           THEN dt.FirstAppQty
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.SecondAppQty
                WHEN dt.ThirdAppQty  > 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.ThirdAppQty
                ELSE dt.qtyreqd
            END                                                         AS QTYREQD,
            dt.LPO_RATE                                                 AS rat,
            CONVERT(varchar, dt.LPO_DATE, 103)                         AS val,
            dt.remarks,
            hd.refno,
            dt.FirstApp,
            dt.SecondApp,
            dt.ThirdApp,
            -- Curstock: imode=2 uses KSP_PRItemStock_FUN (cross-div, GETDATE())
            --           imode=3 uses KSP_PRItemStock_FUN_WITH_DIV (hd.Prdate)
            CASE
                WHEN @imode = 2
                THEN (SELECT dbo.KSP_PRItemStock_FUN(
                        @divcode,
                        REPLACE(CONVERT(VARCHAR(15), GETDATE(),      102), '.', '-'),
                        dt.itemcode,
                        REPLACE(CONVERT(VARCHAR(15), @FinFromDate,   102), '.', '-'),
                        REPLACE(CONVERT(VARCHAR(15), @ToFinYear,     102), '.', '-')
                     ))
                ELSE (SELECT dbo.KSP_PRItemStock_FUN_WITH_DIV(
                        @divcode,
                        REPLACE(CONVERT(VARCHAR(15), hd.Prdate,      102), '.', '-'),
                        dt.itemcode,
                        REPLACE(CONVERT(VARCHAR(15), @FinFromDate,   102), '.', '-'),
                        REPLACE(CONVERT(VARCHAR(15), @ToFinYear,     102), '.', '-')
                     ))
            END                                                         AS Curstock,
            dt.DepCode                                                  AS Dep,
            dt.FinalLevel_Remarks                                       AS Fremark,
            CONVERT(varchar, hd.Prdate, 103)                            AS Prdate1,
            CASE ISNULL(dt.APPCOST, 0)
                WHEN 0    THEN NULL
                WHEN 0.00 THEN NULL
                ELSE dt.APPCOST
            END                                                         AS value,
            ISNULL(dt.remarks, '')                                      AS remarks,
            CASE ISNULL(dt.APPCOST, 0)
                WHEN 0    THEN NULL
                WHEN 0.00 THEN NULL
                ELSE dt.APPCOST
            END                                                         AS NetAmount,

            -- ── Spinrise V2 columns appended (Dapper maps by column name) ───
            dep.Depname                                                 AS department,
            CASE
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.FirstAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0 THEN dt.qtyreqd
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0
                 AND dt.FirstAppQty > 0           THEN dt.FirstAppQty
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.SecondAppQty
                WHEN dt.ThirdAppQty  > 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.ThirdAppQty
                ELSE dt.qtyreqd
            END                                                         AS qtyRequired,
            ISNULL(dt.FinalAppQty,
                CASE
                    WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                     AND ISNULL(dt.FirstAppQty,  0) = 0
                     AND ISNULL(dt.SecondAppQty, 0) = 0 THEN dt.qtyreqd
                    WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                     AND ISNULL(dt.SecondAppQty, 0) = 0
                     AND dt.FirstAppQty > 0           THEN dt.FirstAppQty
                    WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                     AND dt.SecondAppQty > 0
                     AND dt.FirstAppQty  > 0          THEN dt.SecondAppQty
                    WHEN dt.ThirdAppQty  > 0
                     AND dt.SecondAppQty > 0
                     AND dt.FirstAppQty  > 0          THEN dt.ThirdAppQty
                    ELSE dt.qtyreqd
                END
            )                                                           AS qtyApproved,
            CASE WHEN ISNULL(TRY_CAST(dt.FinalLevel_Remarks AS int), 0) = 0
                 THEN 2
                 ELSE TRY_CAST(dt.FinalLevel_Remarks AS int)
            END                                                         AS disposition,
            dt.LPO_RATE                                                 AS lpoRate,
            CONVERT(varchar, dt.LPO_DATE, 103)                         AS lpoDate,
            CASE ISNULL(dt.APPCOST, 0)
                WHEN 0 THEN NULL
                ELSE dt.APPCOST
            END                                                         AS approxCost,
            CASE
                WHEN dt.ThirdApp  IS NOT NULL AND dt.ThirdApp  = 'Y' THEN 'final'
                WHEN dt.SecondApp IS NOT NULL AND dt.SecondApp = 'Y' THEN 'second'
                ELSE 'first'
            END                                                         AS approvalStatus,
            dt.row_version                                              AS rowVersion,
            ISNULL(dt.RATE, 0)                                         AS rate

        FROM   PO_PRH    hd
        LEFT JOIN PO_PRL    dt  ON  hd.divcode  = dt.divcode
                                AND hd.prno     = dt.prno
                                AND hd.prdate   = dt.prDate
        LEFT JOIN IN_DEP    dep ON  dep.divcode = hd.divcode
                                AND hd.depcode  = dep.depcode
        LEFT JOIN In_Scc    S   ON  hd.SubCost  = S.SccCode
                                AND hd.DepCode  = S.DepCode
                                AND hd.DivCOde  = S.DivCode
        LEFT JOIN IN_ITEM   itm ON  itm.itemcode = dt.itemcode
        LEFT JOIN PP_DIVMAS div ON  div.divcode  = hd.divcode

        WHERE  ISNULL(hd.cancelflag, '')  <> 'Y'
          AND  ISNULL(dt.Fclosed, 'N')   <> 'Y'
          AND  hd.divcode = div.divcode
          AND  ISNULL(dt.directApp, 'N') <> 'Y'
          AND  ISNULL(dt.QtyReqd, 0)      > 0
          AND  (dt.FirstApp IS NOT NULL AND dt.FirstApp <> '')
          -- Bypass=1 : only FirstApp required
          -- Bypass=0/null : SecondApp + ThirdApp must also be set
          AND  (
                @Bypass = 1
                OR (
                    (dt.SecondApp IS NOT NULL AND dt.SecondApp <> '')
                AND (dt.ThirdApp  IS NOT NULL AND dt.ThirdApp  <> '')
                )
               )
          AND  (@imode = 2 OR hd.divcode = @divcode)

        ORDER BY div.divcode, hd.Prdate, hd.Prno, dt.prsno;

        SET @Result = 0;
        RETURN;
    END

    -- ── imode=4 — SAVE ───────────────────────────────────────────────────────
    IF @imode = 4
    BEGIN
        BEGIN TRY
            BEGIN TRAN;

            UPDATE PO_PRL
            SET    FinalAppUser       = @FinalAppUser,
                   Prstatus           = 'D',
                   DirectApp          = 'Y',
                   FirstApp           = 'Y',
                   SecondApp          = 'Y',
                   ThirdApp           = 'Y',
                   DirectAppDate      = GETDATE(),
                   QtyReqd            = @FinalAppQty,
                   FinalAppQty        = @FinalAppQty,
                   FinalLevel_Remarks = @FinalLevel_Remarks,
                   FClosed            = CASE WHEN @FinalLevel_Remarks = '4' THEN 'Y'        ELSE FClosed    END,
                   FCloseddt          = CASE WHEN @FinalLevel_Remarks = '4' THEN GETDATE()  ELSE FCloseddt  END
            WHERE  prno      = @prno
              AND  prdate    = @prdate
              AND  prsno     = @prsno
              AND  divcode   = @divcode
              -- row_version guard: active only for Spinrise V2 (VB6 passes NULL — guard skipped)
              AND  (@row_version IS NULL OR row_version = @row_version);

            -- Concurrency check for Spinrise V2 (skipped when VB6 passes @row_version=NULL)
            IF @@ROWCOUNT = 0 AND @row_version IS NOT NULL
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM PO_PRL
                    WHERE  divcode = @divcode AND prno = @prno
                      AND  prdate  = @prdate  AND prsno = @prsno
                )
                    SET @Result = 3;   -- concurrency conflict
                ELSE
                    SET @Result = 4;   -- row not found
                ROLLBACK TRAN;
                RETURN;
            END

            UPDATE PO_PRH
            SET    appflg    = 'Y',
                   app1      = ISNULL(app1,     'DIR'),
                   APP1DATE  = ISNULL(APP1DATE,  GETDATE()),
                   APP1TIME  = ISNULL(APP1TIME,  GETDATE()),
                   app2      = ISNULL(app2,     'DIR'),
                   APP2DATE  = ISNULL(APP2DATE,  GETDATE()),
                   APP2TIME  = ISNULL(APP2TIME,  GETDATE()),
                   app3      = ISNULL(app3,     'DIR'),
                   APP3DATE  = ISNULL(APP3DATE,  GETDATE()),
                   APP3TIME  = ISNULL(APP3TIME,  GETDATE())
            WHERE  prno    = @prno
              AND  prdate  = @prdate
              AND  divcode = @divcode;

            UPDATE PO_Para
            SET    PRSMSStatusFlg = 'Y'
            WHERE  Divcode = @divcode;

            -- SMS notifications (original column list restored)
            IF @FinalLevel_Remarks = '1'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES
                    (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(15), @prdate) + ' Is PL Discuss',
                     @phno, 'N', 0, '', 0, GETDATE());

            ELSE IF @FinalLevel_Remarks = '3'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES
                    (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(15), @prdate) + ' Is Hold',
                     @phno, 'N', 0, '', 0, GETDATE());

            ELSE IF @FinalLevel_Remarks = '4'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES
                    (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(15), @prdate) + ' Declined',
                     @phno, 'N', 0, '', 0, GETDATE());

            ELSE IF @FinalLevel_Remarks = '5'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES
                    (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(10), @prdate) + ' Postponed',
                     @phno, 'N', 0, '', 0, GETDATE());

            -- Audit log (Spinrise V2 addition — transparent to VB6)
            INSERT INTO LogDet_po
                (divcode, prno, prdate, prsno,
                 prstatus, Trans_UserId, Trans_date, Trans_Name, Trans_Mod, Activity)
            VALUES
                (@divcode, @prno, @prdate, @prsno,
                 'D', @FinalAppUser, GETDATE(), 'Final Level PR Approval', 'FinalApp',
                 CASE @FinalLevel_Remarks
                     WHEN '1' THEN 'PL_DISCUSS'
                     WHEN '2' THEN 'APPROVED'
                     WHEN '3' THEN 'HOLD'
                     WHEN '4' THEN 'DECLINED'
                     WHEN '5' THEN 'POSTPONED'
                     ELSE          'APPROVED'
                 END);

            COMMIT TRAN;
            SET @Result = 0;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            SET @Result = 2;
            DECLARE @ErrMsg      nvarchar(4000) = ERROR_MESSAGE(),
                    @ErrSeverity int            = ERROR_SEVERITY();
            RAISERROR(@ErrMsg, @ErrSeverity, 1);
        END CATCH
    END

END;
GO
