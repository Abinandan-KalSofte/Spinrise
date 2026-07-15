-- ============================================================
-- ksp_PO_GetPendingSecondApproval
-- Returns POs pending Second Level approval
-- (BR-01: FirstlevelApp='Y' AND SecondlevelApp<>'Y'), excluding cancelled POs.
-- Result set 1: header rows (+ firstLevel provenance: who/when First
-- Level approved, sourced from LogDet_PO). Result set 2: line rows.
--
-- 10-Jul-2026 legacy-exact ruling (critical validation pass vs
-- ksp_porder_SecondLevelapproval): legacy has NO activation gate at all
-- for Second Level — every division is visible once FirstlevelApp='Y',
-- regardless of PO_PARA.PoSecondLevelApp (its own PO_ParaPOApproval read
-- is dead code, immediately overwritten by a hardcoded SET). The
-- PO_PARA join/filter that was here before has been removed to match.
--
-- 10-Jul-2026 REVERSED: the postpone re-surface filter was also set to
-- legacy's generic `postponedt` column per the same ruling, but that
-- column is never written by ksp_PO_SetSecondApproval's Postpone branch
-- (it writes `SecondLevelPostPoneDt`), so postponed POs never actually
-- left the queue — confirmed live, not just theoretical (same defect
-- found and reversed on First Level's GET SP). Reversed back to filtering
-- `SecondLevelPostPoneDt`.
--
-- Greenfield SP, not subject to CLAUDE.md's existing-SP CR gate.
-- Unverified — flagged, not guessed (no DB access this session):
--   - FA_SLMAS "place"/city column (see ksp_PO_GetPrint.sql comment).
--   - AMDORDNO semantics vs frontend's "amendNo".
--   - "Approver display name": LogDet_PO.Trans_UserId is a user ID, not
--     a display name. Resolved via the same PP_PASSWD.user_name lookup
--     pattern already used in ksp_PO_GetPOHeader.sql (OUTER APPLY on
--     user_id + divcode). Trans_Name='PO_FirstLevel' identifies the row.
--     If multiple First Level actions exist historically (re-approval
--     after a prior decline resets the flag — CR-PO-APPROVAL-01 BR-04),
--     the MOST RECENT Trans_date row is used.
--
-- 10-Jul-2026: Financial Year guard added on PORDDT (user-confirmed,
-- "same as PR module" — see ksp_PR_GetPendingFirstApproval's @YFDate/
-- @YLDate pattern). Legacy has no equivalent FY-range filter at all;
-- this is an additive scope-narrowing per FY, not a legacy-parity item.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPendingSecondApproval
(
    @DivCode VARCHAR(2),
    @YFDate  DATETIME,         -- financial year start
    @YLDate  DATETIME,         -- financial year end
    @Search  VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── Result set 1: Header ─────────────────────────────────────────────────
    SELECT
        RTRIM(h.DIVCODE)                                   AS DivCode,
        RTRIM(ISNULL(divi.DIVNAME, ''))                     AS DivName,
        h.PORDNO                                            AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)  AS PoDate,
        RTRIM(ISNULL(t.TYPNAME, h.POGRP))                   AS OrderType,
        RTRIM(ISNULL(h.SLCODE, ''))                         AS SupplierCode,
        RTRIM(ISNULL(sl.slname, ''))                        AS SupplierName,
        ''                                                  AS SupplierPlace,  -- TBC: FA_SLMAS city/place column unverified
        RTRIM(ISNULL(h.CurrCode, ''))                       AS Currency,
        RTRIM(ISNULL(h.PAYTERMS, ''))                       AS PaymentTerm,
        ISNULL(h.ORDVAL, 0)                                 AS NetTotal,
        ISNULL(TRY_CAST(NULLIF(RTRIM(h.AMDORDNO), '') AS INT), 0) AS AmendNo,  -- TBC: AMDORDNO semantics vs frontend amendNo not confirmed
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                 AS FirstLevelApp,
        RTRIM(ISNULL(h.SecondlevelApp, 'N'))                AS SecondLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                        AS Conflg,
        fl.ApproverName                                     AS FirstLevelBy,
        fl.ApprovedOn                                       AS FirstLevelOn
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.pp_divmas divi
        ON divi.DIVCODE = h.DIVCODE                  -- 10-Jul-2026: division display name
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    OUTER APPLY (
        SELECT TOP 1
            RTRIM(ISNULL(u.user_name, ld.Trans_UserId)) AS ApproverName,
            CONVERT(varchar(10), ld.Trans_date, 103)    AS ApprovedOn
        FROM dbo.LogDet_PO ld
        LEFT JOIN dbo.PP_PASSWD u
            ON RTRIM(u.user_id) = RTRIM(ld.Trans_UserId) AND RTRIM(u.divcode) = RTRIM(ld.divcode)
        WHERE ld.divcode = h.DIVCODE AND ld.pordno = h.PORDNO
          AND CAST(ld.porddt AS DATE) = CAST(h.PORDDT AS DATE)
          AND ld.Trans_Name = 'PO_FirstLevel'
        ORDER BY ld.Trans_date DESC
    ) fl
    WHERE (@DivCode = '0' OR h.DIVCODE = @DivCode)
      AND RTRIM(ISNULL(h.FirstlevelApp, 'N')) = 'Y'          -- BR-01
      AND RTRIM(ISNULL(h.SecondlevelApp, 'N')) <> 'Y'
      AND ISNULL(h.CANFLG, '') = ''
      AND (h.SecondLevelPostPoneDt IS NULL OR CAST(h.SecondLevelPostPoneDt AS DATE) = CAST(GETDATE() AS DATE))  -- 10-Jul-2026 reversed legacy-exact ruling: filters the column ksp_PO_SetSecondApproval actually writes on Postpone (BR-05)
      AND CAST(h.PORDDT AS DATE) BETWEEN @YFDate AND @YLDate                                 -- 10-Jul-2026: FY guard, same pattern as PR module
      AND (@Search IS NULL OR @Search = '' OR CAST(h.PORDNO AS VARCHAR(20)) LIKE '%' + @Search + '%')
    ORDER BY h.PORDDT DESC, h.PORDNO;

    -- ─── Result set 2: Lines (grouped under headers by the repository) ────────
    SELECT
        l.PORDSNO                                           AS PordSno,
        RTRIM(l.ITEMCODE)                                   AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                       AS ItemName,
        ISNULL(l.ORDqty, 0)                                 AS Qty,
        RTRIM(ISNULL(i.uom, ''))                             AS Uom,
        ISNULL(l.Rate, 0)                                    AS Rate,
        ISNULL(l.ORDVAL, 0)                                  AS Value,
        RTRIM(ISNULL(l.onlineremarks, ''))                   AS OnlineRemarks,
        RTRIM(ISNULL(l.FClosed, 'N'))                        AS FClosed,
        l.DIVCODE                                            AS DivCode,
        l.PORDNO                                             AS PoNo,
        CONVERT(varchar(10), CAST(l.PORDDT AS DATE), 120)   AS PoDate
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.PO_ORDH h
        ON h.DIVCODE = l.DIVCODE AND h.PORDNO = l.PORDNO
       AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
    LEFT JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE (@DivCode = '0' OR l.DIVCODE = @DivCode)
      AND RTRIM(ISNULL(h.FirstlevelApp, 'N')) = 'Y'
      AND RTRIM(ISNULL(h.SecondlevelApp, 'N')) <> 'Y'
      AND ISNULL(h.CANFLG, '') = ''
      AND (h.SecondLevelPostPoneDt IS NULL OR CAST(h.SecondLevelPostPoneDt AS DATE) = CAST(GETDATE() AS DATE))  -- 10-Jul-2026 reversed, see header comment
      AND CAST(h.PORDDT AS DATE) BETWEEN @YFDate AND @YLDate                                 -- 10-Jul-2026: FY guard, same pattern as PR module
      AND (@Search IS NULL OR @Search = '' OR CAST(l.PORDNO AS VARCHAR(20)) LIKE '%' + @Search + '%')
    ORDER BY l.PORDNO, l.PORDSNO;
END;
GO
