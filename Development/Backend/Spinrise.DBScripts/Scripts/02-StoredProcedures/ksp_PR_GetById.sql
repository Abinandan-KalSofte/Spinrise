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
        -- PR Status: derived from PO_PRL line-level prstatus (not a PO_PRH column)
        CASE
            WHEN ISNULL(h.cancelflag, '') <> ''
                THEN 'PR. CANCELLED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='O' AND ISNULL(lx.qtyord,0)>0)
                THEN 'ORDERED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='O')
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='E')
                THEN 'ENQUIRED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.prstatus='C')
                THEN 'RECEIVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate
                  AND lx.FirstApp='Y')
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
        'LPO'                                       AS RateSource,
        ''                                          AS RateJustification,
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
