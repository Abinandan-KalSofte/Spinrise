-- ============================================================
-- ksp_PR_GetAmendmentForNew
-- Returns PR header + lines to pre-populate a new amendment form.
-- FSD: M01 PR Amendment Entry v2.3 / CR-M01-AM-001
-- Primary path:   reads header from PO_PRH, lines from PO_PRL (includes row_version per line).
-- Fallback path:  PO_PRH/PO_PRL absent (legacy data from pre-CR save) — reads from PO_APRH/PO_APRL.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentForNew]
    @DivCode    VARCHAR(10),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 0. BR-AMD-03: PR eligibility guard ────────────────────────────────────
    IF NOT EXISTS (
        SELECT 1 FROM dbo.PO_PRH
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
          AND  ISNULL(APPFLG, 'N') = 'N'
          AND  ISNULL(cancelflag, 'N') <> 'Y'
    )
        RAISERROR('This PR is not eligible for amendment — it is approved or cancelled.', 16, 1);

    IF EXISTS (
        SELECT 1 FROM dbo.PO_PRL
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
          AND  (ISNULL(qtyord, 0) > 0 OR ISNULL(prstatus, '') IN ('O', 'E', 'C', 'Z'))
    )
        RAISERROR('This PR is not eligible for amendment — lines have been ordered, enquired, or received.', 16, 1);

    -- ── 1. Header ─────────────────────────────────────────────────────────────
    IF EXISTS (
        SELECT 1 FROM dbo.PO_PRH
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
    )
    BEGIN
        -- Primary path — read from PO_PRH
        SELECT
            h.divcode,
            h.prno,
            CONVERT(VARCHAR(10), CAST(h.prdate AS DATE), 103)        AS prDate,
            0                                                        AS amendno,
            CONVERT(VARCHAR(10), GETDATE(), 103)                     AS amendDate,
            ''                                                       AS amendmentReason,
            ''                                                       AS refNo,
            RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby, '')))   AS createdby,
            ISNULL(h.createddt, '')                                  AS createdDt,
            ''                                                       AS rowVersion,
            h.depcode,
            ISNULL(d.Depname, h.depcode)                             AS depName,
            ISNULL(h.REQNAME, '')                                    AS reqName,
            RTRIM(ISNULL(e.ename, ''))                               AS reqEmpName,
            ISNULL(h.SECTION, '')                                    AS section,
            ISNULL(h.ITYPE,   '')                                    AS iType,
            ISNULL(it.IDESC,  '')                                    AS iDesc,
            ISNULL(h.APPFLG,  'N')                                   AS appFlg,
            ISNULL(h.cancelflag, '')                                 AS cancelFlag,
            (
                SELECT COUNT(*) FROM dbo.PO_APRH a2
                WHERE  a2.divcode              = h.divcode
                  AND  a2.prno                 = h.prno
                  AND  CAST(a2.prdate AS DATE) = CAST(h.prdate AS DATE)
            )                                                        AS existingAmendCount
        FROM   dbo.PO_PRH h
        LEFT JOIN dbo.IN_DEP d  ON d.divcode = h.divcode AND d.depcode = h.depcode
        LEFT JOIN dbo.PR_EMP e  ON CAST(e.empno AS VARCHAR(10)) = RTRIM(h.REQNAME)
        OUTER APPLY (
            SELECT TOP 1 IDESC FROM dbo.PO_INDENTTYPE WHERE ITYPE = h.ITYPE
        ) it
        OUTER APPLY (
            SELECT TOP 1 user_name FROM dbo.PP_PASSWD
            WHERE RTRIM(user_id) = RTRIM(h.createdby)
              AND RTRIM(divcode)  = RTRIM(h.divcode)
        ) pwd
        WHERE  h.divcode              = @DivCode
          AND  h.prno                 = @PrNo
          AND  CAST(h.prdate AS DATE) = @PrDate;
    END
    ELSE
    BEGIN
        -- Fallback: legacy data where PO_PRH was deleted by pre-CR save — read from latest PO_APRH
        SELECT TOP 1
            a.divcode,
            a.prno,
            CONVERT(VARCHAR(10), CAST(a.prdate AS DATE), 103)        AS prDate,
            0                                                        AS amendno,
            CONVERT(VARCHAR(10), GETDATE(), 103)                     AS amendDate,
            ''                                                       AS amendmentReason,
            ''                                                       AS refNo,
            RTRIM(ISNULL(pwd.user_name, ISNULL(a.createdby, '')))   AS createdby,
            ISNULL(a.createddt, '')                                  AS createdDt,
            ''                                                       AS rowVersion,
            ISNULL(a.depcode, '')                                    AS depcode,
            ISNULL(d.Depname, a.depcode)                             AS depName,
            ISNULL(a.REQNAME, '')                                    AS reqName,
            RTRIM(ISNULL(e.ename, ''))                               AS reqEmpName,
            ISNULL(a.SECTION, '')                                    AS section,
            ISNULL(a.ITYPE,   '')                                    AS iType,
            ISNULL(it.IDESC,  '')                                    AS iDesc,
            'N'                                                      AS appFlg,
            ''                                                       AS cancelFlag,
            (
                SELECT COUNT(*) FROM dbo.PO_APRH a2
                WHERE  a2.divcode              = a.divcode
                  AND  a2.prno                 = a.prno
                  AND  CAST(a2.prdate AS DATE) = CAST(a.prdate AS DATE)
            )                                                        AS existingAmendCount
        FROM   dbo.PO_APRH a
        LEFT JOIN dbo.IN_DEP d  ON d.divcode = a.divcode AND d.depcode = a.depcode
        LEFT JOIN dbo.PR_EMP e  ON CAST(e.empno AS VARCHAR(10)) = RTRIM(a.REQNAME)
        OUTER APPLY (
            SELECT TOP 1 IDESC FROM dbo.PO_INDENTTYPE WHERE ITYPE = a.ITYPE
        ) it
        OUTER APPLY (
            SELECT TOP 1 user_name FROM dbo.PP_PASSWD
            WHERE RTRIM(user_id) = RTRIM(a.createdby)
              AND RTRIM(divcode)  = RTRIM(a.divcode)
        ) pwd
        WHERE  a.divcode              = @DivCode
          AND  a.prno                 = @PrNo
          AND  CAST(a.prdate AS DATE) = @PrDate
        ORDER BY a.amendno DESC;
    END

    -- ── 2. Lines ──────────────────────────────────────────────────────────────
    IF EXISTS (
        SELECT 1 FROM dbo.PO_PRL
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
    )
    BEGIN
        -- Primary path — read from PO_PRL; include row_version for PATH A concurrency
        SELECT
            l.prsno,
            l.itemcode,
            ISNULL(i.itemname, l.itemcode)          AS itemName,
            ISNULL(i.UOM, '')                       AS uom,
            ISNULL(i.minlevel, 0)                   AS minLevel,
            ISNULL(i.maxlevel, 0)                   AS maxLevel,
            ISNULL(l.macno, '')                     AS macNo,
            ISNULL(m.DESCRIPTION, '')               AS macDesc,
            l.qtyind,
            CONVERT(VARCHAR(10), l.reqddate, 103)   AS reqdDate,
            ISNULL(l.RATE, 0)                       AS rate,
            'ORIGINAL'                              AS rateSource,
            ''                                      AS rateJustification,
            ISNULL(l.curstock, 0)                   AS curStock,
            ISNULL(l.CCCODE, 0)                     AS ccCode,
            ISNULL(cc.ccname, '')                   AS ccName,
            ISNULL(l.CATCODE, '')                   AS catCode,
            ISNULL(l.BGRPCODE, '')                  AS bgrpCode,
            ''                                      AS place,
            ISNULL(l.APPCOST, 0)                    AS appCost,
            ISNULL(l.remarks, '')                   AS remarks,
            ISNULL(l.FirstAppQty, 0)                AS qtyApproved,
            ISNULL(l.qtyord, 0)                     AS qtyOrdered,
            ISNULL(l.qtyrec, 0)                     AS qtyReceived,
            ISNULL(l.prstatus, '')                  AS lineStatus,
            l.row_version                           AS RowVersion
        FROM   dbo.PO_PRL l
        JOIN   dbo.IN_ITEM i    ON i.itemcode  = l.itemcode
        JOIN   dbo.PO_PRH  h    ON h.divcode              = l.divcode
                               AND h.prno                 = l.prno
                               AND CAST(h.prdate AS DATE) = CAST(l.prdate AS DATE)
        LEFT JOIN dbo.MM_MACMAS m  ON m.MAC_NO  = l.macno AND m.DIVCODE = l.divcode AND m.DEPCODE = h.depcode
        LEFT JOIN dbo.IN_CC     cc ON cc.cccode = l.CCCODE AND cc.divcode = l.divcode
        WHERE  l.divcode              = @DivCode
          AND  l.prno                 = @PrNo
          AND  CAST(l.prdate AS DATE) = @PrDate
        ORDER BY l.prsno;
    END
    ELSE
    BEGIN
        -- Fallback: legacy data where PO_PRL was deleted by pre-CR save — read from latest PO_APRL
        DECLARE @LatestAmendNo INT;
        SELECT @LatestAmendNo = MAX(amendno)
        FROM   dbo.PO_APRL
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate;

        SELECT
            l.prsno,
            l.itemcode,
            ISNULL(i.itemname, l.itemcode)          AS itemName,
            ISNULL(i.UOM, '')                       AS uom,
            ISNULL(i.minlevel, 0)                   AS minLevel,
            ISNULL(i.maxlevel, 0)                   AS maxLevel,
            ISNULL(l.macno, '')                     AS macNo,
            ISNULL(m.DESCRIPTION, '')               AS macDesc,
            l.qtyind,
            CONVERT(VARCHAR(10), l.reqddate, 103)   AS reqdDate,
            ISNULL(l.RATE, 0)                       AS rate,
            ISNULL(l.RATE_SOURCE, 'ORIGINAL')       AS rateSource,
            ISNULL(l.RATE_JUSTIFICATION, '')        AS rateJustification,
            ISNULL(l.curstock, 0)                   AS curStock,
            ISNULL(l.CCCODE, 0)                     AS ccCode,
            ISNULL(cc.ccname, '')                   AS ccName,
            ISNULL(l.CATCODE, '')                   AS catCode,
            ISNULL(l.BGRPCODE, '')                  AS bgrpCode,
            ISNULL(l.PLACE, '')                     AS place,
            ISNULL(l.APPCOST, 0)                    AS appCost,
            ISNULL(l.remarks, '')                   AS remarks,
            0                                       AS qtyApproved,
            0                                       AS qtyOrdered,
            0                                       AS qtyReceived,
            ''                                      AS lineStatus,
            NULL                                    AS RowVersion
        FROM   dbo.PO_APRL l
        JOIN   dbo.IN_ITEM i    ON i.itemcode  = l.itemcode
        JOIN   dbo.PO_APRH ah   ON ah.divcode              = l.divcode
                                AND ah.prno                = l.prno
                                AND CAST(ah.prdate AS DATE) = CAST(l.prdate AS DATE)
                                AND ah.amendno             = l.amendno
        LEFT JOIN dbo.MM_MACMAS m  ON m.MAC_NO  = l.macno AND m.DIVCODE = l.divcode AND m.DEPCODE = ah.depcode
        LEFT JOIN dbo.IN_CC     cc ON cc.cccode = l.CCCODE AND cc.divcode = l.divcode
        WHERE  l.divcode              = @DivCode
          AND  l.prno                 = @PrNo
          AND  CAST(l.prdate AS DATE) = @PrDate
          AND  l.amendno              = @LatestAmendNo
        ORDER BY l.prsno;
    END
END;
GO
