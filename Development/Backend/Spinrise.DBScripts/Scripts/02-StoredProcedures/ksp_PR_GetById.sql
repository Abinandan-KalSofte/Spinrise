-- ============================================================
-- ksp_PR_GetById
-- Loads a specific PR by divcode + prno + prdate.
-- Used by Find / Modify / navigation.
-- Two result sets: header then lines.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetById
(
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Header
    SELECT
        RTRIM(h.divcode)                                        AS DivCode,
        h.prno                                                  AS PrNo,
        CAST(h.prdate AS DATE)                                  AS PrDate,
        RTRIM(ISNULL(h.depcode, ''))                            AS DepCode,
        RTRIM(ISNULL(d.depname, ''))                            AS DepName,
        RTRIM(ISNULL(h.REQNAME, ''))                            AS ReqName,
        RTRIM(ISNULL(e.ename,   ''))                            AS ReqEmpName,
        RTRIM(ISNULL(h.SECTION, ''))                            AS Section,
        RTRIM(ISNULL(h.ITYPE,   ''))                            AS IType,
        RTRIM(ISNULL(it.IDESC,  ''))                            AS IDesc,
        RTRIM(ISNULL(h.refno,   ''))                            AS RefNo,
        RTRIM(ISNULL(h.PO_GRP,  ''))                            AS PoGrp,
        ISNULL(h.APPFLG, 'N')                                   AS AppFlg,
        ISNULL(h.cancelflag, '')                                AS CancelFlag,
        ISNULL(h.amendno, 0)                                    AS AmendNo,
        CASE
            WHEN h.PRSTATUS = 'O' AND ISNULL(
                (SELECT SUM(l2.qtyord) FROM dbo.PO_PRL l2
                 WHERE l2.divcode=h.divcode AND l2.prno=h.prno AND l2.prdate=h.prdate), 0) > 0
                THEN 'ORDERED'
            WHEN h.PRSTATUS = 'O'   THEN 'ORDER CANCELLED'
            WHEN h.PRSTATUS = 'E'   THEN 'ENQUIRED'
            WHEN h.PRSTATUS = 'C'   THEN 'RECEIVED'
            WHEN h.PRSTATUS IS NULL AND ISNULL(
                (SELECT TOP 1 l3.QTYREQD FROM dbo.PO_PRL l3
                 WHERE l3.divcode=h.divcode AND l3.prno=h.prno AND l3.prdate=h.prdate), 1) = 0
                THEN 'PR. CANCELLED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL l4
                WHERE l4.divcode=h.divcode AND l4.prno=h.prno AND l4.prdate=h.prdate AND l4.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL l5
                WHERE l5.divcode=h.divcode AND l5.prno=h.prno AND l5.prdate=h.prdate AND l5.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL l6
                WHERE l6.divcode=h.divcode AND l6.prno=h.prno AND l6.prdate=h.prdate AND l6.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL l7
                WHERE l7.divcode=h.divcode AND l7.prno=h.prno AND l7.prdate=h.prdate AND l7.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            ELSE 'REQUESTED'
        END                                                     AS PrStatus,
        RTRIM(ISNULL(h.createdby, ''))                          AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                          AS CreatedDt,
        RTRIM(ISNULL(h.userId,    ''))                          AS UserId
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PR_EMP e
        ON CAST(e.empno AS VARCHAR(10)) = h.REQNAME
    LEFT JOIN dbo.PO_INDENTTYPE it
        ON it.ITYPE = h.ITYPE
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND CAST(h.prdate AS DATE) = @PrDate;

    -- Lines
    SELECT
        l.prsno                                     AS PrSno,
        RTRIM(l.itemcode)                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))               AS ItemName,
        RTRIM(ISNULL(i.uom,      ''))               AS Uom,
        RTRIM(ISNULL(l.macno,    ''))               AS MacNo,
        ISNULL(l.qtyind,         0)                 AS QtyInd,
        CAST(l.reqddate AS DATE)                    AS ReqdDate,
        ISNULL(l.RATE,           0)                 AS Rate,
        ISNULL(l.LPO_RATE,       0)                 AS LpoRate,
        CAST(l.LPO_DATE AS DATE)                    AS LpoDate,
        RTRIM(ISNULL(l.PUR_FROM, ''))               AS LpoFrom,
        RTRIM(ISNULL(l.RATE_SOURCE,      'LPO'))    AS RateSource,
        RTRIM(ISNULL(l.RATE_JUSTIFICATION,''))      AS RateJustification,
        ISNULL(l.curstock,       0)                 AS CurStock,
        l.CCCODE                                    AS CcCode,
        RTRIM(ISNULL(l.CATCODE,  ''))               AS CatCode,
        RTRIM(ISNULL(l.BGRPCODE, ''))               AS BgrpCode,
        ISNULL(l.APPCOST,        0)                 AS AppCost,
        RTRIM(ISNULL(l.remarks,  ''))               AS Remarks,
        ISNULL(l.Sample,         'N')               AS Sample,
        ISNULL(l.prstatus,       '')                AS LineStatus
    FROM dbo.PO_PRL l
    LEFT JOIN dbo.IN_ITEM i ON i.itemcode = l.itemcode
    WHERE l.divcode = @DivCode
      AND l.prno    = @PrNo
      AND CAST(l.prdate AS DATE) = @PrDate
      AND ISNULL(l.AmdFlg, '') <> 'Y'
    ORDER BY l.prsno;
END;
GO
