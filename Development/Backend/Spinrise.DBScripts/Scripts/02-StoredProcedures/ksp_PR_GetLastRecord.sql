-- ============================================================
-- ksp_PR_GetLastRecord
-- Loads the most recent PR for the division in the current FY.
-- Called on screen open (View mode initial load).
-- Returns header + lines in a single call (two result sets).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetLastRecord
(
    @DivCode VARCHAR(2),
    @FDate   DATE,    -- financial year start
    @LDate   DATE     -- financial year end
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Find the last PR header
    DECLARE @PrNo   NUMERIC(6,0);
    DECLARE @PrDate DATE;

    SELECT TOP 1
        @PrNo   = h.prno,
        @PrDate = CAST(h.prdate AS DATE)
    FROM dbo.PO_PRH h
    WHERE h.divcode = @DivCode
      AND CAST(h.prdate AS DATE) BETWEEN @FDate AND @LDate
      AND ISNULL(h.cancelflag, '') = ''
    ORDER BY h.prdate DESC, h.prno DESC;

    IF @PrNo IS NULL
    BEGIN
        -- No records found — return empty sets with matching columns
        SELECT
            NULL AS DivCode, NULL AS PrNo,   NULL AS PrDate,
            NULL AS DepCode, NULL AS DepName, NULL AS ReqName, NULL AS ReqEmpName,
            NULL AS Section, NULL AS IType,   NULL AS IDesc,   NULL AS RefNo,
            NULL AS PoGrp,   NULL AS AppFlg,  NULL AS PrStatus,
            NULL AS CreatedBy, NULL AS CreatedDt, NULL AS UserId
        WHERE 1 = 0;

        SELECT
            NULL AS PrSno,   NULL AS ItemCode,          NULL AS ItemName, NULL AS Uom,
            NULL AS MacNo,   NULL AS QtyInd,             NULL AS ReqdDate, NULL AS Rate,
            NULL AS LpoRate, NULL AS LpoDate,            NULL AS LpoFrom,
            NULL AS RateSource, NULL AS RateJustification,
            NULL AS CurStock, NULL AS CcCode,
            NULL AS CatCode, NULL AS BgrpCode, NULL AS AppCost, NULL AS Remarks,
            NULL AS Sample,  NULL AS LineStatus
        WHERE 1 = 0;

        RETURN;
    END

    -- Header result set
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
        RTRIM(ISNULL(NULLIF(RTRIM(h.refno), '0'), ''))          AS RefNo,
        RTRIM(ISNULL(h.PO_GRP,  ''))                            AS PoGrp,
        ISNULL(h.APPFLG, 'N')                                   AS AppFlg,
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
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby, '')))   AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                          AS CreatedDt,
        RTRIM(ISNULL(h.userId,    ''))                          AS UserId
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PR_EMP e
        ON CAST(e.empno AS VARCHAR(10)) = h.REQNAME
    LEFT JOIN dbo.PO_INDENTTYPE it
        ON it.ITYPE = h.ITYPE
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(h.createdby)
                   AND RTRIM(divcode) = RTRIM(h.divcode))       pwd
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND CAST(h.prdate AS DATE) = @PrDate;

    -- Lines result set
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
    LEFT JOIN dbo.IN_ITEM i
        ON i.itemcode = l.itemcode
    WHERE l.divcode = @DivCode
      AND l.prno    = @PrNo
      AND CAST(l.prdate AS DATE) = @PrDate
      AND ISNULL(l.AmdFlg, '') <> 'Y'
    ORDER BY l.prsno;
END;
GO
