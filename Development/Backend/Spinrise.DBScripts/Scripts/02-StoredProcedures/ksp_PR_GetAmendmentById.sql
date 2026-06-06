-- ============================================================
-- ksp_PR_GetAmendmentById
-- Returns 2 result sets:
--   #1 — Amendment header (PO_APRH; LEFT JOIN PO_PRH as fallback)
--   #2 — Amendment lines (PO_APRL + IN_ITEM)
-- PO_PRH is deleted after the first amendment — all header field
-- reads use ISNULL(a.<col>, h.<col>) to fall back gracefully.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentById]
    @DivCode    VARCHAR(10),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE,
    @AmendNo    INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Amendment header
    SELECT
        a.divcode,
        a.prno,
        CONVERT(VARCHAR(10), CAST(a.prdate    AS DATE), 103)             AS prDate,
        CAST(a.amendno AS INT)                                           AS amendno,
        CONVERT(VARCHAR(10), CAST(a.amenddate AS DATE), 103)             AS amendDate,
        ISNULL(a.amendreason, '')                                        AS amendmentReason,
        ISNULL(a.refno, '')                                              AS refNo,
        RTRIM(ISNULL(pwd.user_name, ISNULL(a.createdby, ISNULL(h.createdby, '')))) AS createdby,
        ISNULL(a.createddt, ISNULL(h.createddt, ''))                    AS createdDt,
        CONVERT(VARBINARY(8), a.row_version)                            AS rowVersion,
        -- header fields stored on PO_APRH; fall back to PO_PRH if NULL (legacy rows)
        ISNULL(a.depcode,    ISNULL(h.depcode,    ''))                  AS depcode,
        ISNULL(d.Depname, ISNULL(a.depcode, h.depcode))                 AS depName,
        ISNULL(a.REQNAME,    ISNULL(h.REQNAME,    ''))                  AS reqName,
        RTRIM(ISNULL(e.ename, ''))                                       AS reqEmpName,
        ISNULL(a.SECTION,    ISNULL(h.SECTION,    ''))                  AS section,
        ISNULL(a.ITYPE,      ISNULL(h.ITYPE,      ''))                  AS iType,
        ISNULL(it.IDESC,  '')                                           AS iDesc,
        ISNULL(h.APPFLG,  'N')                                          AS appFlg,
        ISNULL(h.cancelflag, '')                                        AS cancelFlag
    FROM   dbo.PO_APRH a
    LEFT JOIN dbo.PO_PRH h  ON  h.divcode              = a.divcode
                            AND h.prno                 = a.prno
                            AND CAST(h.prdate AS DATE) = CAST(a.prdate AS DATE)
    LEFT JOIN dbo.IN_DEP d  ON  d.divcode = a.divcode
                            AND d.depcode = ISNULL(a.depcode, h.depcode)
    LEFT JOIN dbo.PR_EMP e  ON  CAST(e.empno AS VARCHAR(10)) = RTRIM(ISNULL(a.REQNAME, h.REQNAME))
    OUTER APPLY (
        SELECT TOP 1 IDESC FROM dbo.PO_INDENTTYPE
        WHERE ITYPE = ISNULL(a.ITYPE, h.ITYPE)
    ) it
    OUTER APPLY (
        SELECT TOP 1 user_name FROM dbo.PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(ISNULL(a.createdby, h.createdby))
          AND RTRIM(divcode)  = RTRIM(a.divcode)
    ) pwd
    WHERE  a.divcode              = @DivCode
      AND  a.prno                 = @PrNo
      AND  CAST(a.prdate AS DATE) = @PrDate
      AND  a.amendno              = @AmendNo;

    -- Result set 2: Amendment lines
    -- PO_APRL PK = (divcode, prno, prdate, prsno) — no amendno in key.
    -- Each prsno has exactly one row; amendno tracks which amendment last wrote it.
    -- Do NOT filter by l.amendno: a newer amendment overwrites existing rows,
    -- so filtering by the viewed amendno would return zero rows after any subsequent save.
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
        -- Original PR line reference (NULL when PO_PRL deleted on 2nd+ amendment)
        ISNULL(p.FirstAppQty, 0)                AS qtyApproved,
        ISNULL(p.qtyord, 0)                     AS qtyOrdered,
        ISNULL(p.qtyrec, 0)                     AS qtyReceived,
        ISNULL(l.prstatus, '')                  AS lineStatus
    FROM   dbo.PO_APRL l
    JOIN   dbo.IN_ITEM i    ON i.itemcode  = l.itemcode
    -- Anchor PO_APRH join to @AmendNo (not l.amendno) for depcode used in machine lookup
    JOIN   dbo.PO_APRH ah   ON ah.divcode              = @DivCode
                            AND ah.prno                = @PrNo
                            AND CAST(ah.prdate AS DATE) = @PrDate
                            AND ah.amendno             = @AmendNo
    LEFT JOIN dbo.PO_PRL p  ON  p.divcode              = l.divcode
                            AND p.prno                 = l.prno
                            AND CAST(p.prdate AS DATE) = CAST(l.prdate AS DATE)
                            AND p.prsno                = l.prsno
    LEFT JOIN dbo.MM_MACMAS m  ON m.MAC_NO  = l.macno AND m.DIVCODE = l.divcode AND m.DEPCODE = ah.depcode
    LEFT JOIN dbo.IN_CC     cc ON cc.cccode = l.CCCODE AND cc.divcode = l.divcode
    WHERE  l.divcode              = @DivCode
      AND  l.prno                 = @PrNo
      AND  CAST(l.prdate AS DATE) = @PrDate
    ORDER BY l.prsno;
END;
GO
