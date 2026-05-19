-- ============================================================
-- Spinrise ERP V2 — Merged Stored Procedures
-- Database: JAT
-- Deploy: Execute this entire file in SSMS against JAT
-- Rule: NEVER run individual SP files in production — use this file
-- ============================================================

USE JAT;
GO

-- ── Auth ─────────────────────────────────────────────────────
-- ksp_Auth_ValidateUser
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_ValidateUser
(
    @DivCode  VARCHAR(2),
    @UserName VARCHAR(100),
    @Password VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.divcode  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.divcode  = @DivCode
      AND p.user_name = @UserName
      AND dbo.DecryptString(p.password) = @Password
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
GO

-- ksp_Auth_GetActiveDivisions
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetActiveDivisions
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(d.DIVCODE) AS DivCode,
        RTRIM(d.DIVNAME) AS DivName
    FROM dbo.pp_divmas d
    ORDER BY d.DIVCODE;
END;
GO

-- ksp_Auth_GetUserById
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetUserById
(
    @UserId  VARCHAR(100),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.divcode  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.user_id  = @UserId
      AND p.divcode = @DivCode
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
GO

-- ── M01 — Purchase Requisition ────────────────────────────────

-- ksp_PR_GetParameters
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetParameters
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(p.Manual_IndNo,     'N') AS ManualIndNo,
        ISNULL(p.BudgetQty,        'N') AS BudgetQty,
        ISNULL(p.PendingOrderPara, 'N') AS PendingOrderPara,
        ISNULL(p.Penpodetails,     'N') AS Penpodetails,
        ISNULL(p.InditemGrp,       'N') AS InditemGrp,
        ISNULL(p.purtypeflg,        0 ) AS PurTypeFlg,
        ISNULL(p.EmpMasterComm,    'N') AS EmpMasterComm,
        ISNULL(p.PDFExportFlag,    'N') AS PdfExportFlag,
        ISNULL(p.PRSMSSendFlg,     'N') AS PrSmsSendFlg,
        ISNULL(p.PRSMSStatusFlg,   'N') AS PrSmsStatusFlg,
        ISNULL(p.Pr_ILevel,        'N') AS PrILevel,
        ISNULL(p.Pr_FLevel,        'N') AS PrFLevel,
        p.DefaultPRType                 AS DefaultPrType,
        ISNULL(p.MultiSelectLookup,'N') AS MultiSelectLookup
    FROM dbo.PO_PARA p
    WHERE p.divcode = @DivCode;
END;
GO

-- ksp_PR_PreAddChecks
CREATE OR ALTER PROCEDURE dbo.ksp_PR_PreAddChecks
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemExists    BIT = 0;
    DECLARE @DeptExists    BIT = 0;
    DECLARE @DocParaExists BIT = 0;
    DECLARE @BackDateFlag  CHAR(1) = 'Y';
    DECLARE @MaxPrDate     DATE = NULL;

    IF EXISTS (SELECT 1 FROM dbo.IN_ITEM)
        SET @ItemExists = 1;

    IF EXISTS (SELECT 1 FROM dbo.IN_DEP WHERE divcode = @DivCode)
        SET @DeptExists = 1;

    IF EXISTS (
        SELECT 1 FROM dbo.PO_DOC_PARA
        WHERE UPPER(RTRIM(DOCNAME)) = 'PURCHASE REQUISITION'
          AND divcode = @DivCode
    )
        SET @DocParaExists = 1;

    SELECT @BackDateFlag = ISNULL(UPPER(RTRIM(ip.BACKDATE)), 'Y')
    FROM dbo.IN_PARA ip
    WHERE ip.divcode = @DivCode;

    SELECT @MaxPrDate = CAST(MAX(h.prdate) AS DATE)
    FROM dbo.PO_PRH h
    WHERE h.divcode = @DivCode;

    SELECT
        @ItemExists    AS ItemMasterExists,
        @DeptExists    AS DeptMasterExists,
        @DocParaExists AS DocParaExists,
        @BackDateFlag  AS BackDateFlag,
        @MaxPrDate     AS MaxPrDate;
END;
GO

-- ksp_PR_GetDepartments
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetDepartments
(
    @DivCode   VARCHAR(2),
    @Search    VARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(d.depcode)  AS DepCode,
        RTRIM(d.depname)  AS DepName
    FROM dbo.IN_DEP d
    WHERE d.divcode = @DivCode
      AND (
            @Search IS NULL
            OR d.depcode  LIKE '%' + @Search + '%'
            OR d.depname  LIKE '%' + @Search + '%'
          )
    ORDER BY d.depcode;
END;
GO

-- ksp_PR_GetEmployees
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetEmployees
(
    @DivCode    VARCHAR(2),
    @EmpCommon  CHAR(1)     = 'N',
    @Search     VARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(e.empno AS VARCHAR(10)) AS EmpNo,
        RTRIM(e.ename)               AS EmpName
    FROM dbo.PR_EMP e
    WHERE (
            @EmpCommon = 'Y'
            OR e.divcode = @DivCode
          )
      AND (
            @Search IS NULL
            OR CAST(e.empno AS VARCHAR(10)) LIKE '%' + @Search + '%'
            OR e.ename                      LIKE '%' + @Search + '%'
          )
    ORDER BY e.ename;
END;
GO

-- ksp_PR_GetPrTypes
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetPrTypes
(
    @ActiveOnly BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.ITYPE)  AS IType,
        RTRIM(t.IDESC)  AS IDesc
    FROM dbo.PO_INDENTTYPE t
    WHERE @ActiveOnly = 0
       OR ISNULL(t.ACTIVEFLAG, 'Y') = 'Y'
    ORDER BY t.ITYPE;
END;
GO

-- ksp_PR_GetItems
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItems
(
    @DivCode       VARCHAR(2),
    @Search        VARCHAR(50) = NULL,
    @ItemGrpCode   VARCHAR(3)  = NULL,
    @PageNumber    INT         = 1,
    @PageSize      INT         = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(i.itemcode)              AS ItemCode,
        RTRIM(i.itemname)              AS ItemName,
        RTRIM(i.uom)                   AS Uom,
        ISNULL(i.minlevel,   0)        AS MinLevel,
        ISNULL(i.maxlevel,   0)        AS MaxLevel,
        i.IMAGE                        AS ItemImage,
        (
            SELECT TOP 1 pl.RATE
            FROM dbo.PO_ORDL pl
            INNER JOIN dbo.PO_ORDH ph
                ON ph.divcode = pl.divcode
               AND ph.pordno  = pl.pordno
               AND ph.porddt  = pl.porddt
            WHERE pl.itemcode = i.itemcode
              AND pl.divcode  = @DivCode
              AND ISNULL(ph.CANFLG, 'N') = 'N'
            ORDER BY ph.porddt DESC
        ) AS LpoRate,
        (
            SELECT TOP 1 ph.porddt
            FROM dbo.PO_ORDL pl
            INNER JOIN dbo.PO_ORDH ph
                ON ph.divcode = pl.divcode
               AND ph.pordno  = pl.pordno
               AND ph.porddt  = pl.porddt
            WHERE pl.itemcode = i.itemcode
              AND pl.divcode  = @DivCode
              AND ISNULL(ph.CANFLG, 'N') = 'N'
            ORDER BY ph.porddt DESC
        ) AS LpoDate
    FROM dbo.IN_ITEM i
    WHERE ISNULL(i.IsItemActive, 1) = 1
      AND (
            @ItemGrpCode IS NULL
            OR RTRIM(i.itemgrpcode) = @ItemGrpCode
          )
      AND (
            @Search IS NULL
            OR i.itemcode LIKE '%' + @Search + '%'
            OR i.itemname LIKE '%' + @Search + '%'
          )
    ORDER BY i.itemcode
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ksp_PR_GetItemDetail
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItemDetail
(
    @DivCode   VARCHAR(2),
    @ItemCode  VARCHAR(10),
    @FDate     DATE,
    @LDate     DATE,
    @PDate     DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(i.itemcode)      AS ItemCode,
        RTRIM(i.itemname)      AS ItemName,
        RTRIM(i.uom)           AS Uom,
        ISNULL(i.minlevel, 0)  AS MinLevel,
        i.IMAGE                AS ItemImage
    FROM dbo.IN_ITEM i
    WHERE i.itemcode = @ItemCode
      AND ISNULL(i.IsItemActive, 1) = 1;

    DECLARE @Stkchk1 NUMERIC(12,3) = 0;
    SELECT @Stkchk1 = ISNULL(SUM(
        CASE
            WHEN t.TC IN (1,3,5,7,9,12) THEN  ISNULL(t.qty, 0)
            WHEN t.TC IN (2,4,6,8,11)   THEN -ISNULL(t.qty, 0)
            WHEN t.TC = 0               THEN  ISNULL(t.qty, 0)
            ELSE 0
        END
    ), 0)
    FROM (
        SELECT TC = 0, qty = ISNULL(d.OPQTY, 0)
        FROM dbo.IN_IDET d
        WHERE d.itemcode = @ItemCode
          AND d.divcode  = @DivCode
          AND d.yearmonth LIKE CONVERT(VARCHAR(4), YEAR(@FDate)) + '%'
        UNION ALL
        SELECT t.TC, t.qty
        FROM dbo.IN_TRNTAIL t
        INNER JOIN dbo.IN_TRNHEAD h
            ON h.divcode = t.divcode
           AND h.docno   = t.docno
           AND h.docdt   = t.docdt
        WHERE t.itemcode = @ItemCode
          AND t.divcode  = @DivCode
          AND CAST(h.docdt AS DATE) BETWEEN @FDate AND @PDate
          AND t.TC IN (1,2,3,4,5,6,7,8,9,11,12)
    ) t;

    DECLARE @Stkchk2 NUMERIC(12,3) = 0;
    SELECT @Stkchk2 = ISNULL(SUM(
        CASE
            WHEN t.TC IN (1,3,5,7,9)  THEN  ISNULL(t.qty, 0)
            WHEN t.TC IN (2,4,6,8,11) THEN -ISNULL(t.qty, 0)
            WHEN t.TC = 0             THEN  ISNULL(t.qty, 0)
            ELSE 0
        END
    ), 0)
    FROM (
        SELECT TC = 0, qty = ISNULL(d.OPQTY, 0)
        FROM dbo.IN_IDET d
        WHERE d.itemcode = @ItemCode
          AND d.divcode  = @DivCode
          AND d.yearmonth LIKE CONVERT(VARCHAR(4), YEAR(@FDate)) + '%'
        UNION ALL
        SELECT t.TC, t.qty
        FROM dbo.IN_TRNTAIL t
        INNER JOIN dbo.IN_TRNHEAD h
            ON h.divcode = t.divcode
           AND h.docno   = t.docno
           AND h.docdt   = t.docdt
        WHERE t.itemcode = @ItemCode
          AND t.divcode  = @DivCode
          AND CAST(h.docdt AS DATE) BETWEEN @FDate AND @LDate
          AND t.TC IN (1,2,3,4,5,6,7,8,9,11)
    ) t;

    DECLARE @CurrentStock NUMERIC(12,3) =
        CASE WHEN @Stkchk1 <= @Stkchk2 THEN @Stkchk1 ELSE @Stkchk2 END;

    DECLARE @LpoRate NUMERIC(13,4) = NULL;
    DECLARE @LpoDate DATE = NULL;
    SELECT TOP 1
        @LpoRate = pl.RATE,
        @LpoDate = CAST(ph.porddt AS DATE)
    FROM dbo.PO_ORDL pl
    INNER JOIN dbo.PO_ORDH ph
        ON ph.divcode = pl.divcode
       AND ph.pordno  = pl.pordno
       AND ph.porddt  = pl.porddt
    WHERE pl.itemcode = @ItemCode
      AND pl.divcode  = @DivCode
      AND ISNULL(ph.CANFLG, 'N') = 'N'
    ORDER BY ph.porddt DESC;

    DECLARE @AvgRate NUMERIC(13,4) = NULL;
    SELECT @AvgRate = AVG(t.rate)
    FROM dbo.IN_TRNTAIL t
    INNER JOIN dbo.IN_TRNHEAD h
        ON h.divcode = t.divcode
       AND h.docno   = t.docno
       AND h.docdt   = t.docdt
    WHERE t.itemcode = @ItemCode
      AND t.divcode  = @DivCode
      AND t.TC = 1
      AND CAST(h.docdt AS DATE) BETWEEN @FDate AND @LDate;

    SELECT
        @CurrentStock AS CurrentStock,
        @LpoRate      AS LpoRate,
        @LpoDate      AS LpoDate,
        @AvgRate      AS AvgRate;
END;
GO

-- ksp_PR_GetLastRecord
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetLastRecord
(
    @DivCode VARCHAR(2),
    @FDate   DATE,
    @LDate   DATE
)
AS
BEGIN
    SET NOCOUNT ON;

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
        SELECT TOP 0
            CAST(NULL AS VARCHAR(2))   AS DivCode,
            CAST(NULL AS NUMERIC(6,0)) AS PrNo,
            CAST(NULL AS DATE)         AS PrDate,
            CAST(NULL AS VARCHAR(3))   AS DepCode,
            CAST(NULL AS VARCHAR(100)) AS DepName,
            CAST(NULL AS VARCHAR(10))  AS ReqName,
            CAST(NULL AS VARCHAR(100)) AS ReqEmpName,
            CAST(NULL AS VARCHAR(20))  AS Section,
            CAST(NULL AS CHAR(1))      AS IType,
            CAST(NULL AS VARCHAR(100)) AS IDesc,
            CAST(NULL AS VARCHAR(20))  AS RefNo,
            CAST(NULL AS VARCHAR(5))   AS PoGrp,
            CAST(NULL AS CHAR(1))      AS AppFlg,
            CAST(NULL AS VARCHAR(30))  AS PrStatus,
            CAST(NULL AS VARCHAR(50))  AS CreatedBy,
            CAST(NULL AS VARCHAR(25))  AS CreatedDt,
            CAST(NULL AS VARCHAR(50))  AS UserId;

        SELECT TOP 0
            CAST(NULL AS NUMERIC(5,0)) AS PrSno,
            CAST(NULL AS VARCHAR(10))  AS ItemCode,
            CAST(NULL AS VARCHAR(200)) AS ItemName,
            CAST(NULL AS VARCHAR(10))  AS Uom,
            CAST(NULL AS VARCHAR(5))   AS MacNo,
            CAST(NULL AS NUMERIC(12,3))AS QtyInd,
            CAST(NULL AS DATE)         AS ReqdDate,
            CAST(NULL AS NUMERIC(13,4))AS Rate,
            CAST(NULL AS NUMERIC(13,4))AS LpoRate,
            CAST(NULL AS DATE)         AS LpoDate,
            CAST(NULL AS VARCHAR(40))  AS LpoFrom,
            CAST(NULL AS VARCHAR(6))   AS RateSource,
            CAST(NULL AS VARCHAR(200)) AS RateJustification,
            CAST(NULL AS NUMERIC(12,3))AS CurStock,
            CAST(NULL AS NUMERIC(4,0)) AS CcCode,
            CAST(NULL AS VARCHAR(1))   AS CatCode,
            CAST(NULL AS VARCHAR(4))   AS BgrpCode,
            CAST(NULL AS NUMERIC(11,2))AS AppCost,
            CAST(NULL AS VARCHAR(50))  AS Remarks,
            CAST(NULL AS CHAR(1))      AS Sample,
            CAST(NULL AS CHAR(1))      AS LineStatus;
        RETURN;
    END

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

-- ksp_PR_GetById
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetById
(
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

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

-- ksp_PR_GetList
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetList
(
    @DivCode       VARCHAR(2),
    @FDate         DATE,
    @LDate         DATE,
    @Mode          VARCHAR(10) = 'FIND',
    @StatusFilter  VARCHAR(30) = NULL,
    @DepCode       VARCHAR(3)  = NULL,
    @ReqName       VARCHAR(10) = NULL,
    @PoGrp         VARCHAR(5)  = NULL,
    @PageNumber    INT         = 1,
    @PageSize      INT         = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(h.divcode)                AS DivCode,
        h.prno                          AS PrNo,
        CAST(h.prdate AS DATE)          AS PrDate,
        RTRIM(ISNULL(h.depcode,''))     AS DepCode,
        RTRIM(ISNULL(d.depname,''))     AS DepName,
        RTRIM(ISNULL(h.REQNAME,''))     AS ReqName,
        RTRIM(ISNULL(e.ename,  ''))     AS ReqEmpName,
        RTRIM(ISNULL(h.ITYPE,  ''))     AS IType,
        RTRIM(ISNULL(it.IDESC, ''))     AS IDesc,
        RTRIM(ISNULL(h.PO_GRP,''))      AS PoGrp,
        ISNULL(h.APPFLG, 'N')           AS AppFlg,
        CASE
            WHEN h.PRSTATUS = 'O' AND ISNULL(
                (SELECT SUM(l.qtyord) FROM dbo.PO_PRL l
                 WHERE l.divcode=h.divcode AND l.prno=h.prno AND l.prdate=h.prdate), 0) > 0
                THEN 'ORDERED'
            WHEN h.PRSTATUS = 'O'   THEN 'ORDER CANCELLED'
            WHEN h.PRSTATUS = 'E'   THEN 'ENQUIRED'
            WHEN h.PRSTATUS = 'C'   THEN 'RECEIVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN h.PRSTATUS IS NULL AND EXISTS(
                SELECT 1 FROM dbo.PO_PRL lx
                WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            ELSE 'REQUESTED'
        END                             AS PrStatus,
        (SELECT COUNT(*) FROM dbo.PO_PRL lc
         WHERE lc.divcode=h.divcode AND lc.prno=h.prno AND lc.prdate=h.prdate
           AND ISNULL(lc.AmdFlg,'') <> 'Y') AS TotalLines
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PR_EMP e
        ON CAST(e.empno AS VARCHAR(10)) = h.REQNAME
    LEFT JOIN dbo.PO_INDENTTYPE it
        ON it.ITYPE = h.ITYPE
    WHERE h.divcode = @DivCode
      AND CAST(h.prdate AS DATE) BETWEEN @FDate AND @LDate
      AND (@Mode = 'FIND'
           OR (
               ISNULL(h.APPFLG,     'N') <> 'Y'
           AND ISNULL(h.cancelflag, '')   = ''
           AND ISNULL(h.amendno,     0)   = 0
           AND ISNULL(
               (SELECT TOP 1 l2.AmdFlg FROM dbo.PO_PRL l2
                WHERE l2.divcode=h.divcode AND l2.prno=h.prno AND l2.prdate=h.prdate), 'N') <> 'Y'
           ))
      AND (@DepCode  IS NULL OR h.depcode  = @DepCode)
      AND (@ReqName  IS NULL OR h.REQNAME  = @ReqName)
      AND (@PoGrp    IS NULL OR h.PO_GRP   = @PoGrp)
    ORDER BY h.prdate DESC, h.prno DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ksp_PR_Save
CREATE OR ALTER PROCEDURE dbo.ksp_PR_Save
(
    @Mode           VARCHAR(6),
    @DivCode        VARCHAR(2),
    @PrDate         DATE,
    @DepCode        VARCHAR(3),
    @ReqName        VARCHAR(10)  = NULL,
    @Section        VARCHAR(20)  = NULL,
    @IType          CHAR(1)      = NULL,
    @RefNo          VARCHAR(20)  = NULL,
    @PoGrp          VARCHAR(5)   = NULL,
    @UserId         VARCHAR(50),
    @HostName       VARCHAR(100) = NULL,
    @IpAddress      VARCHAR(50)  = NULL,
    @ExistingPrNo   NUMERIC(6,0) = NULL,
    @ExistingPrDate DATE         = NULL,
    @LinesJson      NVARCHAR(MAX),
    @FDate          DATE,
    @LDate          DATE
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @PrNo NUMERIC(6,0);

        IF @Mode = 'ADD'
        BEGIN
            DECLARE @StartDocNo NUMERIC(6,0) = 1;
            SELECT @StartDocNo = ISNULL(STDOCNO, 1)
            FROM dbo.PO_DOC_PARA
            WHERE divcode = @DivCode
              AND UPPER(RTRIM(DOCNAME)) = 'PURCHASE REQUISITION';

            SELECT @PrNo = ISNULL(MAX(prno), 0) + 1
            FROM dbo.PO_PRH
            WHERE divcode = @DivCode
              AND CAST(prdate AS DATE) BETWEEN @FDate AND @LDate;

            IF @PrNo < @StartDocNo
                SET @PrNo = @StartDocNo;
        END
        ELSE
        BEGIN
            SET @PrNo   = @ExistingPrNo;
            SET @PrDate = @ExistingPrDate;
        END

        IF @Mode = 'ADD'
        BEGIN
            DECLARE @CreatedDt VARCHAR(25) =
                CONVERT(VARCHAR(10), GETDATE(), 103) + ' ' +
                CONVERT(VARCHAR(8),  GETDATE(), 108) + ' ' +
                RIGHT(CONVERT(VARCHAR(20), GETDATE(), 109), 2);

            INSERT INTO dbo.PO_PRH
            (
                divcode, prno, prdate, depcode, refno,
                ITYPE, SECTION, PO_GRP, REQNAME,
                APPFLG, amendno, planno,
                alert_raised, userId, createdby, createddt,
                scopecode, SubCost
            )
            VALUES
            (
                @DivCode, @PrNo, @PrDate, @DepCode,
                ISNULL(NULLIF(RTRIM(@RefNo),''), '0'),
                @IType, @Section, @PoGrp, @ReqName,
                'N', 0, 0,
                'N', @UserId, @UserId, @CreatedDt,
                NULL, NULL
            );
        END
        ELSE
        BEGIN
            UPDATE dbo.PO_PRH
            SET
                depcode  = @DepCode,
                refno    = ISNULL(NULLIF(RTRIM(@RefNo),''), '0'),
                ITYPE    = @IType,
                SECTION  = @Section,
                PO_GRP   = @PoGrp,
                REQNAME  = @ReqName
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate;

            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate;
        END

        INSERT INTO dbo.PO_PRL
        (
            divcode, prno, prdate, prsno,
            itemcode, macno, qtyind, reqddate,
            RATE, LPO_RATE, LPO_DATE, PUR_FROM,
            RATE_SOURCE, RATE_JUSTIFICATION,
            curstock, CCCODE, CATCODE, BGRPCODE,
            APPCOST, remarks, Sample, Depcode,
            FirstAppQty, SecondAppQty, ThirdAppQty
        )
        SELECT
            @DivCode,
            @PrNo,
            @PrDate,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            RTRIM(j.ItemCode),
            NULLIF(RTRIM(j.MacNo),    ''),
            j.QtyInd,
            NULLIF(CAST(j.ReqdDate AS VARCHAR(10)), ''),
            j.Rate,
            j.LpoRate,
            j.LpoDate,
            NULLIF(RTRIM(j.LpoFrom),  ''),
            ISNULL(NULLIF(RTRIM(j.RateSource), ''), 'LPO'),
            NULLIF(RTRIM(j.RateJustification), ''),
            j.CurStock,
            NULLIF(j.CcCode, 0),
            NULLIF(RTRIM(j.CatCode),  ''),
            NULLIF(RTRIM(j.BgrpCode), ''),
            NULLIF(j.AppCost,         0),
            UPPER(LEFT(RTRIM(ISNULL(j.Remarks, '')), 50)),
            ISNULL(NULLIF(j.Sample, ''), 'N'),
            @DepCode,
            0, 0, 0
        FROM OPENJSON(@LinesJson)
        WITH (
            ItemCode            VARCHAR(10)     '$.ItemCode',
            MacNo               VARCHAR(5)      '$.MacNo',
            QtyInd              NUMERIC(12,3)   '$.QtyInd',
            ReqdDate            DATE            '$.ReqdDate',
            Rate                NUMERIC(13,4)   '$.Rate',
            LpoRate             NUMERIC(13,4)   '$.LpoRate',
            LpoDate             DATE            '$.LpoDate',
            LpoFrom             VARCHAR(40)     '$.LpoFrom',
            RateSource          VARCHAR(6)      '$.RateSource',
            RateJustification   VARCHAR(200)    '$.RateJustification',
            CurStock            NUMERIC(12,3)   '$.CurStock',
            CcCode              NUMERIC(4,0)    '$.CcCode',
            CatCode             VARCHAR(1)      '$.CatCode',
            BgrpCode            VARCHAR(4)      '$.BgrpCode',
            AppCost             NUMERIC(11,2)   '$.AppCost',
            Remarks             VARCHAR(100)    '$.Remarks',
            Sample              CHAR(1)         '$.Sample'
        ) j
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

        DECLARE @SrSno INT = 1;
        DECLARE @LogItemCode VARCHAR(10), @LogMacNo VARCHAR(5),
                @LogQty NUMERIC(15,0), @LogRate NUMERIC(13,4),
                @LogLpoRate NUMERIC(13,4), @LogLpoDate DATE;

        DECLARE audit_cur CURSOR FAST_FORWARD FOR
            SELECT itemcode, macno,
                   CAST(qtyind AS NUMERIC(15,0)),
                   RATE, LPO_RATE, LPO_DATE
            FROM dbo.PO_PRL
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate
            ORDER BY prsno;

        OPEN audit_cur;
        FETCH NEXT FROM audit_cur INTO
            @LogItemCode, @LogMacNo, @LogQty, @LogRate, @LogLpoRate, @LogLpoDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO dbo.LogDet_po
            (
                divcode, prno, prdate, prsno,
                itemcode, macno, quantity, RATE, LPO_RATE, LPO_DATE,
                Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
                Trans_UserId, Trans_date, moduleNo,
                reqname, createdby
            )
            VALUES
            (
                @DivCode, @PrNo, @PrDate, @SrSno,
                @LogItemCode, @LogMacNo, @LogQty, @LogRate, @LogLpoRate, @LogLpoDate,
                'Purchase Requisition', @Mode, @HostName, @IpAddress,
                @UserId, GETDATE(), 4,
                @ReqName, @UserId
            );

            SET @SrSno = @SrSno + 1;
            FETCH NEXT FROM audit_cur INTO
                @LogItemCode, @LogMacNo, @LogQty, @LogRate, @LogLpoRate, @LogLpoDate;
        END

        CLOSE audit_cur;
        DEALLOCATE audit_cur;

        COMMIT TRANSACTION;
        SELECT @PrNo AS PrNo;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev INT            = ERROR_SEVERITY();
        RAISERROR(@ErrMsg, @ErrSev, 1);
    END CATCH
END;
GO

-- ksp_PR_Delete
CREATE OR ALTER PROCEDURE dbo.ksp_PR_Delete
(
    @DivCode      VARCHAR(2),
    @PrNo         NUMERIC(6,0),
    @PrDate       DATE,
    @DeleteMode   VARCHAR(10),
    @PrSno        NUMERIC(5,0)  = NULL,
    @UserId       VARCHAR(50),
    @DeleteReason VARCHAR(100)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.PO_PRH
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate
              AND ISNULL(APPFLG,     'N') <> 'Y'
              AND ISNULL(cancelflag, '')   = ''
              AND ISNULL(amendno,     0)   = 0
        )
        BEGIN
            RAISERROR('PR cannot be deleted: it is approved, cancelled, or amended.', 16, 1);
            RETURN;
        END

        IF @DeleteMode = 'FULL'
        BEGIN
            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate;

            DELETE FROM dbo.PO_PRH
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate;
        END
        ELSE IF @DeleteMode = 'LINE'
        BEGIN
            IF @PrSno IS NULL
            BEGIN
                RAISERROR('PrSno is required for LINE delete mode.', 16, 1);
                RETURN;
            END

            UPDATE dbo.PO_PRL
            SET deletereason = @DeleteReason
            WHERE divcode = @DivCode AND prno = @PrNo
              AND CAST(prdate AS DATE) = @PrDate AND prsno = @PrSno;

            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode AND prno = @PrNo
              AND CAST(prdate AS DATE) = @PrDate AND prsno = @PrSno;

            WITH ranked AS (
                SELECT prsno,
                       ROW_NUMBER() OVER (ORDER BY prsno) AS NewSno
                FROM dbo.PO_PRL
                WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate
            )
            UPDATE l SET l.prsno = r.NewSno
            FROM dbo.PO_PRL l
            INNER JOIN ranked r ON r.prsno = l.prsno
               AND l.divcode = @DivCode AND l.prno = @PrNo AND CAST(l.prdate AS DATE) = @PrDate;
        END

        COMMIT TRANSACTION;
        SELECT 1 AS Success;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev INT            = ERROR_SEVERITY();
        RAISERROR(@ErrMsg, @ErrSev, 1);
    END CATCH
END;
GO

-- ksp_PR_CheckPendingOrder
CREATE OR ALTER PROCEDURE dbo.ksp_PR_CheckPendingOrder
(
    @DivCode  VARCHAR(2),
    @FDate    DATE,
    @LDate    DATE,
    @DepCode  VARCHAR(3),
    @ItemCode VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SUM(ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0)) AS PendingQty
    FROM dbo.PO_ORDH h
    INNER JOIN dbo.PO_ORDL l
        ON l.divcode = h.divcode
       AND l.pordno  = h.pordno
       AND l.porddt  = h.porddt
    WHERE h.divcode              = @DivCode
      AND ISNULL(h.CANFLG, 'N') = 'N'
      AND ISNULL(l.FClosed,'N') <> 'Y'
      AND l.DepCode              = @DepCode
      AND l.ITEMCODE             = @ItemCode
      AND CAST(l.PRDATE AS DATE) BETWEEN @FDate AND @LDate
    HAVING SUM(ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0)) > 0;
END;
GO
