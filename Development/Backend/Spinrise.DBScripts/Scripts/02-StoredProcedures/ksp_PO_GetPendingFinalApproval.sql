-- ============================================================
-- ksp_PO_GetPendingFinalApproval
-- Returns POs pending Final Level confirmation. BR-01 gating:
-- FirstlevelApp='Y' AND SecondlevelApp='Y', both unconditional (10-Jul-2026
-- legacy-exact ruling — see the WHERE clause comment; this SP no longer
-- mirrors ksp_PO_SetFinalApproval's own conditional SAVE-side guard).
-- BR-02: silent empty result when Final Level's own activation flag
-- (Po_Confirm) is off for a division.
--
-- BR-06: single GROUPED result set only — one row per PO header, no
-- line-item rows (Final Level reviewers see PO value + supplier
-- exposure, not line detail). lineCount/poValue are aggregates from
-- PO_ORDL. Both firstLevel and secondLevel provenance are shown.
--
-- Greenfield SP, not subject to CLAUDE.md's existing-SP CR gate.
-- Unverified — flagged, not guessed (no DB access this session):
--   - FA_SLMAS "place"/city column.
--   - AMDORDNO semantics vs frontend's "amendNo".
--   - Approver display name resolution — same LogDet_PO/PP_PASSWD
--     pattern as ksp_PO_GetPendingSecondApproval.sql, most-recent-row
--     per level via Trans_Name='PO_FirstLevel'/'PO_SecondLevel'.
--
-- 10-Jul-2026: Financial Year guard added on PORDDT (user-confirmed,
-- "same as PR module" — see ksp_PR_GetPendingFirstApproval's @YFDate/
-- @YLDate pattern). Legacy has no equivalent FY-range filter at all;
-- this is an additive scope-narrowing per FY, not a legacy-parity item.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPendingFinalApproval
(
    @DivCode VARCHAR(2),
    @YFDate  DATETIME,         -- financial year start
    @YLDate  DATETIME,         -- financial year end
    @Search  VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

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
        ISNULL(agg.LineCount, 0)                            AS LineCount,   -- BR-06
        ISNULL(agg.PoValue, 0)                               AS PoValue,     -- BR-06
        fl.ApproverName                                     AS FirstLevelBy,
        fl.ApprovedOn                                       AS FirstLevelOn,
        sl2.ApproverName                                    AS SecondLevelBy,
        sl2.ApprovedOn                                      AS SecondLevelOn
    FROM dbo.PO_ORDH h
    INNER JOIN dbo.PO_PARA p
        ON p.divcode = h.DIVCODE
       AND ISNULL(p.Po_Confirm, 'N') = 'Y'                -- BR-02: silently exclude divisions where Final Level is inactive
    LEFT JOIN dbo.pp_divmas divi
        ON divi.DIVCODE = h.DIVCODE                  -- 10-Jul-2026: division display name
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    OUTER APPLY (
        SELECT COUNT(*) AS LineCount, SUM(ISNULL(l.ORDVAL, 0)) AS PoValue
        FROM dbo.PO_ORDL l
        WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
          AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
    ) agg
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
    OUTER APPLY (
        SELECT TOP 1
            RTRIM(ISNULL(u.user_name, ld.Trans_UserId)) AS ApproverName,
            CONVERT(varchar(10), ld.Trans_date, 103)    AS ApprovedOn
        FROM dbo.LogDet_PO ld
        LEFT JOIN dbo.PP_PASSWD u
            ON RTRIM(u.user_id) = RTRIM(ld.Trans_UserId) AND RTRIM(u.divcode) = RTRIM(ld.divcode)
        WHERE ld.divcode = h.DIVCODE AND ld.pordno = h.PORDNO
          AND CAST(ld.porddt AS DATE) = CAST(h.PORDDT AS DATE)
          AND ld.Trans_Name = 'PO_SecondLevel'
        ORDER BY ld.Trans_date DESC
    ) sl2
    WHERE (@DivCode = '0' OR h.DIVCODE = @DivCode)
      -- 10-Jul-2026 legacy-exact ruling (critical validation pass vs
      -- ksp_porder_FinalLevelapproval): legacy requires SecondlevelApp='Y'
      -- UNCONDITIONALLY — no allowance for divisions where Second Level is
      -- switched off, even though ksp_PO_SetFinalApproval's own SAVE-side
      -- guard *does* allow Final to proceed without it in that case. This
      -- creates a known GET/SET inconsistency (a PO could be saveable at
      -- Final Level but never appear in this queue, for divisions with
      -- Second Level off) — replicated as literal legacy behavior per
      -- ruling, not reconciled with the SET SP. Flagged, not silently fixed.
      AND RTRIM(ISNULL(h.FirstlevelApp, 'N')) = 'Y'
      AND RTRIM(ISNULL(h.SecondlevelApp, 'N')) = 'Y'
      AND RTRIM(ISNULL(h.Conflg, 'N')) <> 'Y'
      AND ISNULL(h.CANFLG, '') = ''
      AND (h.postponedt IS NULL OR CAST(h.postponedt AS DATE) = CAST(GETDATE() AS DATE))  -- BR-05: postpone re-surface gate (legacy parity)
      AND CAST(h.PORDDT AS DATE) BETWEEN @YFDate AND @YLDate                                 -- 10-Jul-2026: FY guard, same pattern as PR module
      AND (@Search IS NULL OR @Search = '' OR CAST(h.PORDNO AS VARCHAR(20)) LIKE '%' + @Search + '%')
    ORDER BY h.PORDDT DESC, h.PORDNO;
END;
GO
