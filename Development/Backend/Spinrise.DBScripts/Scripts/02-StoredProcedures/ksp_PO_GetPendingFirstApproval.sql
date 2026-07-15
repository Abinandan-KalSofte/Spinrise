-- ============================================================
-- ksp_PO_GetPendingFirstApproval
-- Returns POs pending First Level approval (BR-01: FirstlevelApp<>'Y'),
-- excluding cancelled POs.
-- Result set 1: header rows. Result set 2: line rows (First Level shows
-- full line detail — FSD §10.2 only groups Final Level).
--
-- 10-Jul-2026 legacy-exact ruling (critical validation pass vs
-- ksp_porder_FirstLevelapproval): the activation gate below is
-- po_para.po_confirm (Final Level's own flag), NOT a First-Level-specific
-- one — this is what legacy's own First Level query literally does (looks
-- like copy-paste residue from Final Level's query, but user ruled to
-- replicate legacy exactly rather than the FSD-consistent PoFirstLevelApp
-- gate that was here before).
--
-- 10-Jul-2026 REVERSED: the postpone re-surface filter was also set to
-- legacy's generic `postponedt` column per the same ruling — but that
-- column is never written by ksp_PO_SetFirstApproval's Postpone branch
-- (it writes `Firstlevelpostponedt`), so postponed POs never actually
-- left the queue — confirmed live, not just theoretical. Reversed back to
-- filtering `Firstlevelpostponedt` (matches BR-05's actual intent and
-- what its own SET SP writes). This is the only Addendum 3 finding
-- reversed; the other 3 legacy-exact rulings (First's po_confirm gate,
-- Second's missing activation gate, Final's unconditional SecondlevelApp
-- requirement) stand as originally ruled.
--
-- Greenfield SP, not subject to CLAUDE.md's existing-SP CR gate — safe
-- to deploy once the flagged unverified columns below are confirmed
-- against live JAT sys.columns (no DB access available this session):
--   - FA_SLMAS "place"/city column (not confirmed — see ksp_PO_GetPrint.sql
--     comment "add3/city/pin unverified"); left blank until confirmed.
--   - AMDORDNO's exact semantics vs. the frontend's "amendNo" (count vs.
--     reference-order-number) — used as best-effort mapping, flagged.
--   - "Approver display name" for LogDet_PO provenance is not needed by
--     First Level's own grid (no firstLevel/secondLevel provenance shown
--     on First Level rows per poApprovalTypes.ts) — not built here.
--
-- 10-Jul-2026: Financial Year guard added on PORDDT (user-confirmed,
-- "same as PR module" — see ksp_PR_GetPendingFirstApproval's @YFDate/
-- @YLDate pattern). Legacy has no equivalent FY-range filter at all;
-- this is an additive scope-narrowing per FY, not a legacy-parity item.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPendingFirstApproval
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
        RTRIM(ISNULL(h.Conflg, 'N'))                        AS Conflg
    FROM dbo.PO_ORDH h
    INNER JOIN dbo.PO_PARA p
        ON p.divcode = h.DIVCODE
       AND ISNULL(p.po_confirm, 'N') = 'Y'          -- legacy-exact (10-Jul-2026 ruling): ksp_porder_FirstLevelapproval
                                                      -- literally gates First Level's own queue on po_confirm (Final's
                                                      -- flag), not a First-Level-specific one. Replicated as-is.
    LEFT JOIN dbo.pp_divmas divi
        ON divi.DIVCODE = h.DIVCODE                  -- 10-Jul-2026: division display name, same column ksp_Auth_GetActiveDivisions uses
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    WHERE (@DivCode = '0' OR h.DIVCODE = @DivCode)
      AND RTRIM(ISNULL(h.FirstlevelApp, 'N')) <> 'Y'        -- BR-01: not yet first-approved
      AND ISNULL(h.CANFLG, '') = ''                          -- exclude cancelled POs
      AND (h.Firstlevelpostponedt IS NULL OR CAST(h.Firstlevelpostponedt AS DATE) = CAST(GETDATE() AS DATE))  -- 10-Jul-2026 reversed legacy-exact ruling: filters the column ksp_PO_SetFirstApproval actually writes on Postpone (BR-05); comparison operator (exact-date match) unchanged, matches Final Level's existing convention
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
    INNER JOIN dbo.PO_PARA p
        ON p.divcode = h.DIVCODE
       AND ISNULL(p.po_confirm, 'N') = 'Y'          -- legacy-exact (10-Jul-2026 ruling), see header result set comment
    LEFT JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE (@DivCode = '0' OR l.DIVCODE = @DivCode)
      AND RTRIM(ISNULL(h.FirstlevelApp, 'N')) <> 'Y' 
      AND ISNULL(h.CANFLG, '') = ''
      AND (h.Firstlevelpostponedt IS NULL OR CAST(h.Firstlevelpostponedt AS DATE) = CAST(GETDATE() AS DATE))  -- 10-Jul-2026 reversed, see header result set comment
      AND CAST(h.PORDDT AS DATE) BETWEEN @YFDate AND @YLDate                                 -- 10-Jul-2026: FY guard, same pattern as PR module
      AND (@Search IS NULL OR @Search = '' OR CAST(l.PORDNO AS VARCHAR(20)) LIKE '%' + @Search + '%')
    ORDER BY l.PORDNO, l.PORDSNO;
END;
GO
