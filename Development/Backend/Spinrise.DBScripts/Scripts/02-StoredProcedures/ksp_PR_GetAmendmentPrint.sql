-- ============================================================
-- ksp_PR_GetAmendmentPrint
-- Returns 2 result sets for QuestPDF report generation:
--   #1 — Amendment header + PP_DIVMAS letterhead data
--   #2 — Amendment lines with item / machine / rate data
-- PO_PRH is deleted after the first amendment — LEFT JOIN used;
-- header fields fall back to PO_APRH columns stored on ADD.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentPrint]
    @DivCode    VARCHAR(10),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE,
    @AmendNo    INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Header + division letterhead
    SELECT
        a.divcode,
        a.prno,
        CONVERT(VARCHAR(10), CAST(a.prdate    AS DATE), 103)             AS prDate,
        CAST(a.amendno AS INT)                                           AS amendno,
        CONVERT(VARCHAR(10), CAST(a.amenddate AS DATE), 103)             AS amendDate,
        ISNULL(a.amendreason, '')                                        AS amendmentReason,
        ISNULL(a.refno,       '')                                        AS refNo,
        RTRIM(ISNULL(pwd.user_name, ISNULL(a.createdby, ISNULL(h.createdby, '')))) AS createdby,
        ISNULL(a.depcode,    ISNULL(h.depcode,    ''))                   AS depcode,
        ISNULL(d.Depname, ISNULL(a.depcode, h.depcode))                  AS depName,
        ISNULL(a.REQNAME,    ISNULL(h.REQNAME,    ''))                   AS reqName,
        -- Division letterhead
        dv.DIV_LOGO                                                      AS divLogo,
        RTRIM(ISNULL(dv.DIVNAME,          ''))                           AS divName,
        RTRIM(ISNULL(dv.div_printname,    ''))                           AS divPrintName,
        RTRIM(ISNULL(dv.div_unitname,     ''))                           AS divUnitName,
        RTRIM(ISNULL(dv.DIVISION_ADDR1,   ''))                           AS divAddress1,
        RTRIM(ISNULL(dv.DIVISION_ADDR2,   ''))                           AS divAddress2,
        RTRIM(ISNULL(dv.DIVISION_ADDR3,   ''))                           AS divAddress3,
        RTRIM(ISNULL(dv.PINCODE,          ''))                           AS divPinCode,
        RTRIM(ISNULL(dv.STATENAME,        ''))                           AS divState,
        RTRIM(ISNULL(dv.PHONE1,           ''))                           AS divPhone,
        RTRIM(ISNULL(dv.EMAIL,            ''))                           AS divEmail
    FROM   dbo.PO_APRH a
    LEFT JOIN dbo.PO_PRH h  ON  h.divcode              = a.divcode
                            AND h.prno                 = a.prno
                            AND CAST(h.prdate AS DATE) = CAST(a.prdate AS DATE)
    LEFT JOIN dbo.IN_DEP    d  ON  d.divcode  = a.divcode
                               AND d.depcode  = ISNULL(a.depcode, h.depcode)
    LEFT JOIN dbo.PP_DIVMAS dv ON  dv.DIVCODE = a.divcode
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
    SELECT
        ROW_NUMBER() OVER (ORDER BY l.prsno)                            AS sNo,
        l.prsno,
        l.itemcode,
        ISNULL(i.itemname, l.itemcode)                                  AS itemName,
        ISNULL(i.UOM, '')                                               AS uom,
        ISNULL(l.qtyind, 0)                                             AS qtyInd,
        CONVERT(VARCHAR(10), l.reqddate, 103)                           AS reqdDate,
        ISNULL(l.curstock, 0)                                           AS curStock,
        ISNULL(l.RATE, 0)                                               AS rate,
        CAST(ISNULL(l.qtyind, 0) * ISNULL(l.RATE, 0)
             AS NUMERIC(15,2))                                          AS value,
        ISNULL(l.RATE_SOURCE, 'ORIGINAL')                               AS rateSource,
        ISNULL(l.RATE_JUSTIFICATION, '')                                AS rateJustification,
        ISNULL(p.FirstAppQty, 0)                                        AS qtyApproved,
        ISNULL(p.qtyord, 0)                                             AS qtyOrdered,
        ISNULL(p.qtyrec, 0)                                             AS qtyReceived,
        ISNULL(l.macno, '')                                             AS macNo,
        ISNULL(
            (SELECT TOP 1 mm.DESCRIPTION
             FROM   dbo.MM_MACMAS mm
             WHERE  mm.MAC_NO  = l.macno
               AND  mm.DIVCODE = l.divcode
               AND  mm.DEPCODE = ah.depcode),
        '')                                                             AS macDesc,
        RTRIM(ISNULL(i.DRAWNO, ''))                                     AS drawNo,
        RTRIM(ISNULL(i.CATLNO, ''))                                     AS catNo,
        ISNULL(l.CATCODE, '')                                           AS catCode,
        ISNULL(l.BGRPCODE, '')                                          AS bgrpCode,
        ISNULL(l.PLACE, '')                                             AS place,
        ISNULL(l.APPCOST, 0)                                            AS appCost,
        ISNULL(l.remarks, '')                                           AS remarks
    FROM   dbo.PO_APRL l
    -- PO_APRH for depcode (PO_PRH deleted after first amendment)
    JOIN   dbo.PO_APRH ah   ON  ah.divcode              = l.divcode
                            AND ah.prno                 = l.prno
                            AND CAST(ah.prdate AS DATE) = CAST(l.prdate AS DATE)
                            AND ah.amendno              = l.amendno
    JOIN   dbo.IN_ITEM i    ON  i.itemcode  = l.itemcode
    LEFT JOIN dbo.PO_PRL p  ON  p.divcode              = l.divcode
                            AND p.prno                 = l.prno
                            AND CAST(p.prdate AS DATE) = CAST(l.prdate AS DATE)
                            AND p.prsno                = l.prsno
    WHERE  l.divcode              = @DivCode
      AND  l.prno                 = @PrNo
      AND  CAST(l.prdate AS DATE) = @PrDate
      AND  l.amendno              = @AmendNo
    ORDER BY l.prsno;
END;
GO
