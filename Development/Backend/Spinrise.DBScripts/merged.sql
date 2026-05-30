-- ============================================================
-- Spinrise ERP V2 â€” Merged Stored Procedures
-- Database: JAT
-- Deploy: Execute this entire file in SSMS against JAT
-- Rule: NEVER run individual SP files in production â€” use this file
-- NOTE: ksp_PR_Save uses OPENJSON â€” requires compat level >= 130.
--       Run first if needed: ALTER DATABASE JAT SET COMPATIBILITY_LEVEL = 130;
-- ============================================================

USE JAT;
GO

-- Ensure OPENJSON is available (required by ksp_PR_Save)
ALTER DATABASE JAT SET COMPATIBILITY_LEVEL = 130;
GO

-- â”€â”€ Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        p.divcode                            AS DivCode,
        p.user_id                            AS UserId,
        p.user_name                          AS UserName,
        p.alevel                             AS ALevel,
        RTRIM(ISNULL(d.DIVNAME, ''))         AS DivName
    FROM dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE p.divcode   = @DivCode
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
        p.divcode                        AS DivCode,
        p.user_id                        AS UserId,
        p.user_name                      AS UserName,
        p.alevel                         AS ALevel,
        RTRIM(ISNULL(d.DIVNAME, ''))     AS DivName
    FROM dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE p.user_id  = @UserId
      AND p.divcode  = @DivCode
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
GO

-- â”€â”€ M01 Purchase Requisition â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        NULL                            AS DefaultPrType,
        'N'                             AS MultiSelectLookup
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

    -- PO_DOC_PARA only has TC and STDOCNO columns
    IF EXISTS (SELECT 1 FROM dbo.PO_DOC_PARA WHERE TC = 'PURCHASE REQUISITION')
        SET @DocParaExists = 1;

    -- IN_PARA is a single-row config table â€” no divcode column
    SELECT TOP 1 @BackDateFlag = ISNULL(UPPER(RTRIM(ip.BACKDATE)), 'Y')
    FROM dbo.IN_PARA ip;

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
       OR ISNULL(t.active, 'Y') = 'Y'
    ORDER BY t.ITYPE;
END;
GO

-- ksp_PR_GetItems
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItems
(
    @DivCode       VARCHAR(2),
    @Search        VARCHAR(50) = NULL,
    @ItemGrpCode   VARCHAR(10) = NULL,
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
        i.ITEMIMAGE                    AS ItemImage,
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
            SELECT TOP 1 CAST(ph.porddt AS DATE)
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
            OR RTRIM(i.sgrpcode) = @ItemGrpCode
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
-- NOTE: CurrentStock uses IN_ITEM.CURSTK (direct).
--       FY-based conservative stock calc will be restored
--       once IN_IDET/IN_TRNTAIL column names are confirmed.
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

    -- Result set 1: Item master
    SELECT
        RTRIM(i.itemcode)             AS ItemCode,
        RTRIM(i.itemname)             AS ItemName,
        RTRIM(i.uom)                  AS Uom,
        ISNULL(i.minlevel, 0)         AS MinLevel,
        ISNULL(i.maxlevel, 0)         AS MaxLevel,
        i.ITEMIMAGE                   AS ItemImage,
        RTRIM(ISNULL(i.ImagePath,'')) AS ImagePath
    FROM dbo.IN_ITEM i
    WHERE i.itemcode = @ItemCode
      AND ISNULL(i.IsItemActive, 1) = 1;

    -- Result set 2: Stock + rates
    DECLARE @CurrentStock NUMERIC(12,3) = 0;
    SELECT @CurrentStock = ISNULL(CURSTK, 0) FROM dbo.IN_ITEM WHERE itemcode = @ItemCode;

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

    SELECT
        @CurrentStock AS CurrentStock,
        @LpoRate      AS LpoRate,
        @LpoDate      AS LpoDate,
        NULL          AS AvgRate;
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
        CASE
            WHEN ISNULL(h.cancelflag, '') <> ''
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='O' AND ISNULL(lx.qtyord,0)>0)
                THEN 'ORDERED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='O')
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='E')
                THEN 'ENQUIRED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='C')
                THEN 'RECEIVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            ELSE 'REQUESTED'
        END                                                     AS PrStatus,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby, '')))   AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                          AS CreatedDt,
        RTRIM(ISNULL(h.userId,    ''))                          AS UserId
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d  ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PR_EMP e  ON CAST(e.empno AS VARCHAR(10)) = h.REQNAME
    LEFT JOIN dbo.PO_INDENTTYPE it ON it.ITYPE = h.ITYPE
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(h.createdby)
                   AND RTRIM(divcode) = RTRIM(h.divcode))       pwd
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND CAST(h.prdate AS DATE) = @PrDate;

    SELECT
        l.prsno                             AS PrSno,
        RTRIM(l.itemcode)                   AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))       AS ItemName,
        RTRIM(ISNULL(i.uom,      ''))       AS Uom,
        RTRIM(ISNULL(l.macno,    ''))       AS MacNo,
        ISNULL(l.qtyind,         0)         AS QtyInd,
        CAST(l.reqddate AS DATE)            AS ReqdDate,
        ISNULL(l.RATE,           0)         AS Rate,
        ISNULL(l.LPO_RATE,       0)         AS LpoRate,
        CAST(l.LPO_DATE AS DATE)            AS LpoDate,
        RTRIM(ISNULL(l.PUR_FROM, ''))       AS LpoFrom,
        'LPO'                               AS RateSource,
        ''                                  AS RateJustification,
        ISNULL(l.curstock,       0)         AS CurStock,
        l.CCCODE                            AS CcCode,
        RTRIM(ISNULL(scc.SCCNAME, ''))      AS CcName,
        RTRIM(ISNULL(l.CATCODE,  ''))       AS CatCode,
        RTRIM(ISNULL(l.BGRPCODE, ''))       AS BgrpCode,
        ISNULL(l.APPCOST,        0)         AS AppCost,
        RTRIM(ISNULL(l.remarks,  ''))       AS Remarks,
        ISNULL(l.Sample,         'N')       AS Sample,
        ISNULL(l.prstatus,       '')        AS LineStatus
    FROM dbo.PO_PRL l
    LEFT JOIN dbo.IN_ITEM i  ON i.itemcode  = l.itemcode
    LEFT JOIN dbo.In_Scc scc ON scc.SCCCODE = l.CCCODE AND scc.Divcode = l.divcode
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
    @PrDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    IF @PrDate IS NULL RETURN;

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
        ISNULL(h.cancelflag, '')                                AS CancelFlag,
        ISNULL(h.amendno, 0)                                    AS AmendNo,
        CASE
            WHEN ISNULL(h.cancelflag, '') <> ''
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='O' AND ISNULL(lx.qtyord,0)>0)
                THEN 'ORDERED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='O')
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='E')
                THEN 'ENQUIRED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='C')
                THEN 'RECEIVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            ELSE 'REQUESTED'
        END                                                     AS PrStatus,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby, '')))   AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                          AS CreatedDt,
        RTRIM(ISNULL(h.userId,    ''))                          AS UserId
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d  ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PR_EMP e  ON CAST(e.empno AS VARCHAR(10)) = h.REQNAME
    LEFT JOIN dbo.PO_INDENTTYPE it ON it.ITYPE = h.ITYPE
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(h.createdby)
                   AND RTRIM(divcode) = RTRIM(h.divcode))       pwd
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND CAST(h.prdate AS DATE) = @PrDate;

    SELECT
        l.prsno                             AS PrSno,
        RTRIM(l.itemcode)                   AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))       AS ItemName,
        RTRIM(ISNULL(i.uom,      ''))       AS Uom,
        RTRIM(ISNULL(l.macno,    ''))       AS MacNo,
        ISNULL(l.qtyind,         0)         AS QtyInd,
        CAST(l.reqddate AS DATE)            AS ReqdDate,
        ISNULL(l.RATE,           0)         AS Rate,
        ISNULL(l.LPO_RATE,       0)         AS LpoRate,
        CAST(l.LPO_DATE AS DATE)            AS LpoDate,
        RTRIM(ISNULL(l.PUR_FROM, ''))       AS LpoFrom,
        'LPO'                               AS RateSource,
        ''                                  AS RateJustification,
        ISNULL(l.curstock,       0)         AS CurStock,
        l.CCCODE                            AS CcCode,
        RTRIM(ISNULL(scc.SCCNAME, ''))      AS CcName,
        RTRIM(ISNULL(l.CATCODE,  ''))       AS CatCode,
        RTRIM(ISNULL(l.BGRPCODE, ''))       AS BgrpCode,
        ISNULL(l.APPCOST,        0)         AS AppCost,
        RTRIM(ISNULL(l.remarks,  ''))       AS Remarks,
        ISNULL(l.Sample,         'N')       AS Sample,
        ISNULL(l.prstatus,       '')        AS LineStatus
    FROM dbo.PO_PRL l
    LEFT JOIN dbo.IN_ITEM i  ON i.itemcode  = l.itemcode
    LEFT JOIN dbo.In_Scc scc ON scc.SCCCODE = l.CCCODE AND scc.Divcode = l.divcode
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
        RTRIM(ISNULL(
            (SELECT TOP 1 e2.ename FROM dbo.PR_EMP e2
             WHERE CAST(e2.empno AS VARCHAR(10)) = h.REQNAME),
        ''))                            AS ReqEmpName,
        RTRIM(ISNULL(h.ITYPE,  ''))     AS IType,
        RTRIM(ISNULL(it.IDESC, ''))     AS IDesc,
        RTRIM(ISNULL(h.PO_GRP,''))      AS PoGrp,
        ISNULL(h.APPFLG, 'N')           AS AppFlg,
        CASE
            WHEN ISNULL(h.cancelflag, '') <> ''
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='O' AND ISNULL(lx.qtyord,0)>0)
                THEN 'ORDERED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='O')
                THEN 'ORDER CANCELLED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='E')
                THEN 'ENQUIRED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.prstatus='C')
                THEN 'RECEIVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.DirectApp='Y')
                THEN 'FINAL LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.ThirdApp='Y')
                THEN 'THIRD LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.SecondApp='Y')
                THEN 'SECOND LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            ELSE 'REQUESTED'
        END                             AS PrStatus,
        (SELECT COUNT(*) FROM dbo.PO_PRL lc
         WHERE lc.divcode=h.divcode AND lc.prno=h.prno AND lc.prdate=h.prdate
           AND ISNULL(lc.AmdFlg,'') <> 'Y') AS TotalLines
    FROM dbo.PO_PRH h
    LEFT JOIN dbo.IN_DEP d  ON d.divcode = h.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.PO_INDENTTYPE it ON it.ITYPE = h.ITYPE
    WHERE h.divcode = @DivCode
      AND CAST(h.prdate AS DATE) BETWEEN @FDate AND @LDate
      AND ISNULL(h.amendno, 0) = 0   -- never show amendment records in list (all modes)
      AND (@Mode = 'FIND'
           OR (
               ISNULL(h.APPFLG,      'N') <> 'Y'
           AND ISNULL(h.cancelflag,  '')  = ''
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
    @ReqName        VARCHAR(10)     = NULL,
    @Section        VARCHAR(20)     = NULL,
    @IType          CHAR(1)         = NULL,
    @RefNo          VARCHAR(20)     = NULL,
    @PoGrp          VARCHAR(5)      = NULL,
    @UserId         VARCHAR(50),
    @HostName       VARCHAR(100)    = NULL,
    @IpAddress      VARCHAR(50)     = NULL,
    @ExistingPrNo   NUMERIC(6,0)    = NULL,
    @ExistingPrDate DATE            = NULL,
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

        -- â”€â”€ 0. Validate min / max order level per line â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        DECLARE @LevelError NVARCHAR(500);

        SELECT TOP 1 @LevelError =
            CASE
                WHEN ISNULL(i.minlevel, 0) > 0 AND j.QtyInd < ISNULL(i.minlevel, 0)
                    THEN 'Required Quantity for ' + RTRIM(j.ItemCode)
                         + ' cannot be less than Minimum Order Quantity ('
                         + LTRIM(STR(ISNULL(i.minlevel, 0), 12, 3)) + ').'
                WHEN ISNULL(i.maxlevel, 0) > 0 AND j.QtyInd > ISNULL(i.maxlevel, 0)
                    THEN 'Required Quantity for ' + RTRIM(j.ItemCode)
                         + ' cannot exceed Maximum Order Level ('
                         + LTRIM(STR(ISNULL(i.maxlevel, 0), 12, 3)) + ').'
            END
        FROM OPENJSON(@LinesJson)
        WITH (
            ItemCode  VARCHAR(10)    '$.ItemCode',
            QtyInd    NUMERIC(12,3)  '$.QtyInd'
        ) j
        INNER JOIN dbo.IN_ITEM i ON RTRIM(i.itemcode) = RTRIM(j.ItemCode)
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> ''
          AND (
                (ISNULL(i.minlevel, 0) > 0 AND j.QtyInd < ISNULL(i.minlevel, 0))
             OR (ISNULL(i.maxlevel, 0) > 0 AND j.QtyInd > ISNULL(i.maxlevel, 0))
              );

        IF @LevelError IS NOT NULL
            RAISERROR(@LevelError, 16, 1);

        DECLARE @PrNo NUMERIC(6,0);

        IF @Mode = 'ADD'
        BEGIN
            DECLARE @StartDocNo NUMERIC(6,0) = 1;
            SELECT @StartDocNo = ISNULL(STDOCNO, 1)
            FROM dbo.PO_DOC_PARA
            WHERE TC = 'IND';

            SELECT @PrNo = ISNULL(MAX(prno), 0) + 1
            FROM dbo.PO_PRH
            WHERE divcode = @DivCode
              AND CAST(prdate AS DATE) BETWEEN @FDate AND @LDate;

            IF @PrNo < @StartDocNo
                SET @PrNo = @StartDocNo;
        END
        ELSE
        BEGIN
            SET @PrNo = @ExistingPrNo;
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
                NULLIF(RTRIM(@RefNo), ''),
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
                refno    = NULLIF(RTRIM(@RefNo), ''),
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
            curstock, CCCODE, CATCODE, BGRPCODE,
            APPCOST, remarks, Sample, Depcode,
            FirstAppQty, SecondAppQty, ThirdAppQty
        )
        SELECT
            @DivCode, @PrNo, @PrDate,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS prsno,
            RTRIM(j.ItemCode),
            NULLIF(RTRIM(j.MacNo),    ''),
            j.QtyInd,
            NULLIF(j.ReqdDate,        ''),
            j.Rate,
            j.LpoRate,
            NULLIF(j.LpoDate,         ''),
            NULLIF(RTRIM(j.LpoFrom),  ''),
            j.CurStock,
            NULLIF(j.CcCode,          0),
            NULLIF(RTRIM(j.CatCode),  ''),
            NULLIF(RTRIM(j.BgrpCode), ''),
            NULLIF(j.AppCost,         0),
            UPPER(LEFT(RTRIM(ISNULL(j.Remarks, '')), 50)),
            ISNULL(NULLIF(j.Sample, ''), 'N'),
            @DepCode,
            0, 0, 0
        FROM OPENJSON(@LinesJson)
        WITH (
            ItemCode    VARCHAR(10)     '$.ItemCode',
            MacNo       VARCHAR(5)      '$.MacNo',
            QtyInd      NUMERIC(12,3)   '$.QtyInd',
            ReqdDate    DATE            '$.ReqdDate',
            Rate        NUMERIC(13,4)   '$.Rate',
            LpoRate     NUMERIC(13,4)   '$.LpoRate',
            LpoDate     DATE            '$.LpoDate',
            LpoFrom     VARCHAR(40)     '$.LpoFrom',
            CurStock    NUMERIC(12,3)   '$.CurStock',
            CcCode      NUMERIC(4,0)    '$.CcCode',
            CatCode     VARCHAR(1)      '$.CatCode',
            BgrpCode    VARCHAR(4)      '$.BgrpCode',
            AppCost     NUMERIC(11,2)   '$.AppCost',
            Remarks     VARCHAR(100)    '$.Remarks',
            Sample      CHAR(1)         '$.Sample'
        ) j
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

        DECLARE @SrSno INT = 1;
        DECLARE @LogItemCode VARCHAR(10), @LogMacNo VARCHAR(5),
                @LogQty NUMERIC(15,0), @LogRate NUMERIC(13,4);

        DECLARE audit_cur CURSOR FAST_FORWARD FOR
            SELECT itemcode, macno,
                   CAST(qtyind AS NUMERIC(15,0)),
                   RATE
            FROM dbo.PO_PRL
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate
            ORDER BY prsno;

        OPEN audit_cur;
        FETCH NEXT FROM audit_cur INTO @LogItemCode, @LogMacNo, @LogQty, @LogRate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO dbo.LogDet_po
            (
                divcode, prno, prdate, prsno,
                itemcode, macno, quantity, RATE,
                Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
                Trans_UserId, Trans_date, moduleNo,
                reqname, createdby
            )
            VALUES
            (
                @DivCode, @PrNo, @PrDate, @SrSno,
                @LogItemCode, @LogMacNo, @LogQty, @LogRate,
                'Purchase Requisition', @Mode, @HostName, @IpAddress,
                @UserId, GETDATE(), 4,
                @ReqName, @UserId
            );

            SET @SrSno = @SrSno + 1;
            FETCH NEXT FROM audit_cur INTO @LogItemCode, @LogMacNo, @LogQty, @LogRate;
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
    @DeleteReason VARCHAR(100)  = NULL,
    @HostName     VARCHAR(100)  = NULL,
    @IpAddress    VARCHAR(50)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.PO_PRH
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate
              AND ISNULL(APPFLG,     'N') <> 'Y'
              AND ISNULL(cancelflag, '')   = ''
              AND ISNULL(amendno,     0)   = 0
        )
        BEGIN
            RAISERROR('PR cannot be deleted: it is approved, cancelled, or amended.', 16, 1);
            RETURN;
        END

        DECLARE @ReqName VARCHAR(10);
        SELECT @ReqName = REQNAME
        FROM dbo.PO_PRH
        WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate;

        IF @DeleteMode = 'FULL'
        BEGIN
            INSERT INTO dbo.LogDet_po
            (
                divcode, prno, prdate, prsno,
                itemcode, macno, quantity, RATE,
                Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
                Trans_UserId, Trans_date, moduleNo,
                reqname, createdby
            )
            SELECT
                @DivCode, @PrNo, @PrDate, prsno,
                itemcode, macno, CAST(qtyind AS NUMERIC(15,0)), RATE,
                'Purchase Requisition', 'DELETE', @HostName, @IpAddress,
                @UserId, GETDATE(), 4,
                @ReqName, @UserId
            FROM dbo.PO_PRL
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate;

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

            INSERT INTO dbo.LogDet_po
            (
                divcode, prno, prdate, prsno,
                itemcode, macno, quantity, RATE,
                Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
                Trans_UserId, Trans_date, moduleNo,
                reqname, createdby
            )
            SELECT
                @DivCode, @PrNo, @PrDate, prsno,
                itemcode, macno, CAST(qtyind AS NUMERIC(15,0)), RATE,
                'Purchase Requisition', 'DELETE', @HostName, @IpAddress,
                @UserId, GETDATE(), 4,
                @ReqName, @UserId
            FROM dbo.PO_PRL
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate AND prsno = @PrSno;

            UPDATE dbo.PO_PRL
            SET deletereason = @DeleteReason
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate AND prsno = @PrSno;

            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate AND prsno = @PrSno;

            WITH ranked AS (
                SELECT prsno,
                       ROW_NUMBER() OVER (ORDER BY prsno) AS NewSno
                FROM dbo.PO_PRL
                WHERE divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate
            )
            UPDATE l
            SET l.prsno = r.NewSno
            FROM dbo.PO_PRL l
            INNER JOIN ranked r
                ON r.prsno = l.prsno
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
        ON l.divcode = h.divcode AND l.pordno = h.pordno AND l.porddt = h.porddt
    WHERE h.divcode             = @DivCode
      AND ISNULL(h.CANFLG, 'N') = 'N'
      AND ISNULL(l.FClosed, 'N') <> 'Y'
      AND l.DepCode              = @DepCode
      AND l.ITEMCODE             = @ItemCode
      AND CAST(l.PRDATE AS DATE) BETWEEN @FDate AND @LDate
    HAVING SUM(ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0)) > 0;
END;
GO

-- â”€â”€ ksp_PR_GetUserPermissions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetUserPermissions
(
    @UserId  VARCHAR(50),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @ULevel DECIMAL;

        SELECT @ULevel = alevel
        FROM dbo.PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(@UserId)
          AND RTRIM(divcode)  = RTRIM(@DivCode)
          AND UPPER(ISNULL(activeflg, 'N')) = 'Y';

        IF @ULevel IS NULL
        BEGIN
            SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
            RETURN;
        END;

        SELECT TOP 1
            CAST(CASE WHEN UPPER(ISNULL(ADD_FLG, 'Y')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanAdd,
            CAST(CASE WHEN UPPER(ISNULL(MOD_FLG, 'Y')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanModify,
            CAST(CASE WHEN UPPER(ISNULL(DEL_FLG, 'Y')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanDelete
        FROM dbo.USERLEVEL
        WHERE RTRIM(DIVCODE) = RTRIM(@DivCode)
          AND MODULE          = 4
          AND ULEVEL          = @ULevel;

        IF @@ROWCOUNT = 0
            SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
    END TRY
    BEGIN CATCH
        SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
    END CATCH
END;
GO


-- ============================================================
-- ksp_PR_GetMachineLookup
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetMachineLookup
(
    @DivCode   VARCHAR(2),
    @DepCode   VARCHAR(10),
    @Search    VARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(m.MAC_NO)      AS MacNo,
        RTRIM(m.DESCRIPTION) AS MacDesc,
        RTRIM(m.MODEL)       AS MacModel
    FROM dbo.MM_MACMAS m
    WHERE m.DIVCODE = @DivCode
      AND m.DEPCODE = @DepCode
      AND m.MACFLAG = 'M'
      AND ISNULL(m.IsActive, 'Y') = 'Y'
      AND (
            @Search IS NULL
            OR m.MAC_NO      LIKE '%' + @Search + '%'
            OR m.DESCRIPTION LIKE '%' + @Search + '%'
          )
    ORDER BY m.MAC_NO;
END;
GO


-- ============================================================
-- ksp_PR_GetCostCentreLookup
-- Returns Sub Cost Centres for the given division from In_Scc.
-- Only active records (Active = 'Y') are returned.
-- Supports type-ahead search by SCCCODE or SCCNAME.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetCostCentreLookup
(
    @DivCode   VARCHAR(2),
    @Search    VARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SCCCODE           AS CcCode,
        RTRIM(s.SCCNAME)    AS CcName
    FROM dbo.In_Scc s
    WHERE s.Divcode = @DivCode
      AND ISNULL(s.Active, '') = 'Y'
      AND (
            @Search IS NULL
            OR CAST(s.SCCCODE AS VARCHAR(10)) LIKE '%' + @Search + '%'
            OR s.SCCNAME LIKE '%' + @Search + '%'
          )
    ORDER BY s.SCCCODE;
END;
GO


-- ================================================================
-- ksp_PR_GetPrint  (CR v1.5: live CURSTK from IN_ITEM instead of saved l.curstock)
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetPrint
(
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    IF @PrDate IS NULL RETURN;

    SELECT
        -- Division letterhead (PP_DIVMAS actual column names â€” matching V1)
        dv.DIV_LOGO                                         AS DivLogo,
        RTRIM(ISNULL(dv.DIVNAME,         ''))               AS DivName,
        RTRIM(ISNULL(dv.div_printname,   ''))               AS DivPrintName,
        RTRIM(ISNULL(dv.div_unitname,    ''))               AS DivUnitName,
        RTRIM(ISNULL(dv.DIVISION_ADDR1,  ''))               AS DivAddress1,
        RTRIM(ISNULL(dv.DIVISION_ADDR2,  ''))               AS DivAddress2,
        RTRIM(ISNULL(dv.DIVISION_ADDR3,  ''))               AS DivAddress3,
        RTRIM(ISNULL(dv.PINCODE,         ''))               AS DivPinCode,
        RTRIM(ISNULL(dv.STATENAME,       ''))               AS DivState,
        RTRIM(ISNULL(dv.PHONE1,          ''))               AS DivPhone,
        RTRIM(ISNULL(dv.EMAIL,           ''))               AS DivEmail,

        -- PR Header
        RTRIM(h.divcode)                                    AS DivCode,
        h.prno                                              AS PrNo,
        CAST(h.prdate AS DATE)                              AS PrDate,
        RTRIM(ISNULL(h.depcode,  ''))                       AS DepCode,
        RTRIM(ISNULL(dep.depname,''))                       AS DepName,
        RTRIM(ISNULL(h.REQNAME,  ''))                       AS ReqName,
        RTRIM(ISNULL(emp.ename,  ''))                       AS ReqEmpName,
        RTRIM(ISNULL(h.SECTION,  ''))                       AS Section,
        RTRIM(ISNULL(NULLIF(RTRIM(h.refno), '0'), ''))      AS RefNo,
        RTRIM(ISNULL(h.PO_GRP,   ''))                       AS PoGrp,
        RTRIM(ISNULL(it.IDESC,   ''))                       AS IDesc,
        RTRIM(ISNULL(h.APPFLG,   'N'))                      AS AppFlg,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby,''))) AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                      AS CreatedDt,

        -- PR Line
        l.prsno                                             AS PrSno,
        RTRIM(ISNULL(l.itemcode, ''))                       AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                       AS ItemName,
        RTRIM(ISNULL(i.uom,      ''))                       AS Uom,
        RTRIM(ISNULL(i.CATLNO,   ''))                       AS CatNo,
        RTRIM(ISNULL(i.DRAWNO,   ''))                       AS DrawNo,
        RTRIM(ISNULL(l.macno,    ''))                       AS MacNo,
        RTRIM(ISNULL(m.MODEL,    ''))                       AS MacModel,
        RTRIM(ISNULL(m.MacMake,  ''))                       AS MacMake,
        ISNULL(l.qtyind,          0)                        AS QtyInd,
        CAST(l.reqddate AS DATE)                            AS ReqdDate,
        ISNULL(l.LPO_RATE,        0)                        AS LastPoRate,
        CAST(l.LPO_DATE AS DATE)                            AS LastPoDate,
        ISNULL(i.CURSTK,          0)                        AS CurrentStock,
        ISNULL(l.APPCOST,         0)                        AS AppCost,
        RTRIM(ISNULL(l.remarks,  ''))                       AS Remarks,

        -- Approval flags
        ISNULL(l.FirstApp,  'N')                            AS FirstApp,
        ISNULL(l.SecondApp, 'N')                            AS SecondApp,
        ISNULL(l.ThirdApp,  'N')                            AS ThirdApp,
        ISNULL(l.DirectApp, 'N')                            AS DirectApp,

        -- Approver names (FirstappUser has lowercase 'a' in the actual DB column)
        RTRIM(ISNULL(l.FirstappUser,  ''))                  AS FirstAppUser,
        RTRIM(ISNULL(l.SecondAppUser, ''))                  AS SecondAppUser,
        RTRIM(ISNULL(l.ThirdAppUser,  ''))                  AS ThirdAppUser,
        RTRIM(ISNULL(l.FinalAppUser,  ''))                  AS FinalAppUser,

        -- Only DirectAppDate exists; APP1/2/3DATE do not exist in this schema
        CASE WHEN l.DirectAppDate IS NOT NULL
             THEN CONVERT(VARCHAR(12), CAST(l.DirectAppDate AS DATE), 103)
             ELSE '' END                                     AS PresidentAppDate,

        -- CR-PR-12: user-selected rate (LPO/Average/Manual)
        ISNULL(l.RATE, 0)                                   AS Rate

    FROM  dbo.PO_PRH h
    INNER JOIN dbo.PO_PRL l
           ON  l.divcode              = h.divcode
           AND l.prno                 = h.prno
           AND CAST(l.prdate AS DATE) = CAST(h.prdate AS DATE)
    LEFT  JOIN dbo.PP_DIVMAS     dv  ON dv.DIVCODE = h.divcode
    LEFT  JOIN dbo.IN_DEP       dep  ON dep.divcode = h.divcode AND dep.depcode = h.depcode
    OUTER APPLY (SELECT TOP 1 ename FROM dbo.PR_EMP
                 WHERE CAST(empno AS VARCHAR(10)) = h.REQNAME)            emp
    OUTER APPLY (SELECT TOP 1 IDESC FROM dbo.PO_INDENTTYPE
                 WHERE ITYPE = h.ITYPE)                                   it
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(h.createdby)
                   AND RTRIM(divcode) = RTRIM(h.divcode))                 pwd
    LEFT  JOIN dbo.IN_ITEM        i  ON i.itemcode = l.itemcode
    LEFT  JOIN dbo.MM_MACMAS      m  ON m.DIVCODE  = l.divcode
                                    AND m.MAC_NO   = l.macno
                                    AND m.DEPCODE  = h.depcode
                                    AND m.MACFLAG  = 'M'
    WHERE h.divcode              = @DivCode
      AND h.prno                 = @PrNo
      AND CAST(h.prdate AS DATE) = @PrDate
      AND ISNULL(l.AmdFlg, '')  <> 'Y'
    ORDER BY l.prsno;
END;
GO


-- ============================================================
-- ksp_PR_GetItemImagePath
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItemImagePath
(
    @ItemCode VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RTRIM(ISNULL(ImagePath, '')) AS ImagePath
    FROM   dbo.IN_ITEM
    WHERE  itemcode = @ItemCode;
END;
GO


-- ============================================================
-- usp_GetNextAmendNo.sql
-- ============================================================

-- ============================================================
-- usp_GetNextAmendNo
-- Generates next amendment number atomically.
-- SERIALIZABLE isolation + UPDLOCK + HOLDLOCK prevents race
-- condition on concurrent amendment entry.
-- Number derived from MAX(amendno)+1 in PO_APRH for the FY.
-- SP name CONFIRMED by Sasi (Stage 2, 23-May-2026).
-- FSD: M01 PR Amendment Entry v2.3 | AF-04
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[usp_GetNextAmendNo]
    @DivCode    VARCHAR(10),
    @FDate      DATE,
    @LDate      DATE,
    @NewDocNo   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        SELECT @NewDocNo = ISNULL(MAX(amendno), 0) + 1
        FROM   dbo.PO_APRH WITH (UPDLOCK, HOLDLOCK)
        WHERE  divcode  = @DivCode
          AND  CAST(amenddate AS DATE) BETWEEN @FDate AND @LDate;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @NewDocNo = -1;
        THROW;
    END CATCH
END;
GO


-- ============================================================
-- AMENDMENT MODULE — FSD v2.3 (run migration first, then SPs)
-- ============================================================

-- ============================================================
-- migration_PrAmendment.sql
-- ============================================================

-- ============================================================
-- Migration: M01 PR Amendment Entry
-- Adds columns required by the Amendment SPs.
-- Safe to re-run (IF NOT EXISTS guards on every ALTER).
-- Run BEFORE executing the amendment stored procedures.
-- Target: SpinRiseSaranya
-- ============================================================

-- PO_APRH: concurrency token
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'row_version')
    ALTER TABLE dbo.PO_APRH ADD row_version ROWVERSION;
GO

-- PO_APRH: audit trail for who created each amendment
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'createdby')
    ALTER TABLE dbo.PO_APRH ADD createdby VARCHAR(50) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'createddt')
    ALTER TABLE dbo.PO_APRH ADD createddt VARCHAR(25) NULL;
GO

-- PO_APRH: header snapshot for 2nd+ amendments (PO_PRH deleted after first)
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'depcode')
    ALTER TABLE dbo.PO_APRH ADD depcode VARCHAR(3) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'REQNAME')
    ALTER TABLE dbo.PO_APRH ADD REQNAME VARCHAR(25) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'SECTION')
    ALTER TABLE dbo.PO_APRH ADD SECTION VARCHAR(20) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'ITYPE')
    ALTER TABLE dbo.PO_APRH ADD ITYPE CHAR(1) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'PLACEOFISS')
    ALTER TABLE dbo.PO_APRH ADD PLACEOFISS VARCHAR(30) NULL;
GO

-- PO_APRL: rate origin tracking (ORIGINAL / MANUAL)
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'RATE_SOURCE')
    ALTER TABLE dbo.PO_APRL ADD RATE_SOURCE VARCHAR(20) NULL;
GO

-- PO_APRL: justification required when RATE_SOURCE = 'MANUAL'
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'RATE_JUSTIFICATION')
    ALTER TABLE dbo.PO_APRL ADD RATE_JUSTIFICATION VARCHAR(200) NULL;
GO

-- PO_APRL: stock snapshot at time of amendment
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'curstock')
    ALTER TABLE dbo.PO_APRL ADD curstock NUMERIC(12,3) NULL;
GO

-- PO_APRL: FSD v2.3 additional line fields
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'CATCODE')
    ALTER TABLE dbo.PO_APRL ADD CATCODE VARCHAR(1) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'BGRPCODE')
    ALTER TABLE dbo.PO_APRL ADD BGRPCODE VARCHAR(4) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'PLACE')
    ALTER TABLE dbo.PO_APRL ADD PLACE VARCHAR(40) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'APPCOST')
    ALTER TABLE dbo.PO_APRL ADD APPCOST NUMERIC(11,2) NULL;
GO

-- ============================================================
-- ksp_PR_GetAmendmentList.sql
-- ============================================================

-- ============================================================
-- ksp_PR_GetAmendmentList
-- Returns amendments for a division within a date range.
-- PO_PRH is deleted after the first amendment â€” LEFT JOIN used;
-- depcode/REQNAME fall back to PO_APRH columns stored on ADD.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentList]
    @DivCode    VARCHAR(10),
    @FDate      DATE,
    @LDate      DATE,
    @PrNo       NUMERIC(6,0)    = NULL,
    @Search     NVARCHAR(100)   = NULL,
    @PageNumber INT             = 1,
    @PageSize   INT             = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.divcode,
        a.prno,
        CONVERT(VARCHAR(10), CONVERT(DATE, a.prdate,    103), 103)   AS prDate,
        CAST(a.amendno AS INT)                                       AS amendno,
        CONVERT(VARCHAR(10), CONVERT(DATE, a.amenddate, 103), 103)   AS amendDate,
        ISNULL(a.amendreason,  '')                                   AS amendmentReason,
        ISNULL(a.refno,        '')                                   AS refNo,
        ISNULL(a.depcode,    ISNULL(h.depcode,    ''))               AS depCode,
        ISNULL(d.Depname, ISNULL(a.depcode, h.depcode))              AS depName,
        ISNULL(a.REQNAME,    ISNULL(h.REQNAME,    ''))               AS reqName,
        ISNULL(a.createdby, ISNULL(h.createdby, ''))                 AS createdby,
        (
            SELECT COUNT(*) FROM dbo.PO_APRL l2
            WHERE l2.divcode                          = a.divcode
              AND l2.prno                             = a.prno
              AND CONVERT(DATE, l2.prdate, 103)       = CONVERT(DATE, a.prdate, 103)
              AND l2.amendno                          = a.amendno
        )                                                            AS totalLines
    FROM   dbo.PO_APRH a
    LEFT JOIN dbo.PO_PRH h  ON  h.divcode                        = a.divcode
                            AND h.prno                           = a.prno
                            AND CAST(h.prdate AS DATE)           = CONVERT(DATE, a.prdate, 103)
    LEFT JOIN dbo.IN_DEP d  ON  d.divcode = a.divcode
                            AND d.depcode = ISNULL(a.depcode, h.depcode)
    WHERE  a.divcode = @DivCode
      AND  CONVERT(DATE, a.amenddate, 103) BETWEEN @FDate AND @LDate
      AND  (@PrNo   IS NULL OR a.prno = @PrNo)
      AND  (
               @Search IS NULL
            OR RTRIM(CAST(a.prno AS VARCHAR)) LIKE '%' + @Search + '%'
            OR ISNULL(a.amendreason, '')     LIKE '%' + @Search + '%'
            OR ISNULL(d.Depname,     '')     LIKE '%' + @Search + '%'
           )
    ORDER BY a.amenddate DESC, a.amendno DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH  NEXT @PageSize ROWS ONLY;
END;
GO

-- ============================================================
-- ksp_PR_GetAmendmentForNew.sql
-- ============================================================

-- ============================================================
-- ksp_PR_GetAmendmentForNew
-- Returns PR header + lines to pre-populate a new amendment form.
-- FSD: M01 PR Amendment Entry v2.3
-- First amendment:  reads header from PO_PRH, lines from PO_PRL.
-- 2nd+ amendment:   PO_PRH/PO_PRL deleted â€” falls back to latest
--                   PO_APRH / PO_APRL (ORDER BY amendno DESC / MAX).
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentForNew]
    @DivCode    VARCHAR(10),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- â”€â”€ 1. Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    IF EXISTS (
        SELECT 1 FROM dbo.PO_PRH
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
    )
    BEGIN
        -- First amendment â€” read from PO_PRH
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
        -- 2nd+ amendment â€” PO_PRH deleted; read from latest PO_APRH
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

    -- â”€â”€ 2. Lines â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    IF EXISTS (
        SELECT 1 FROM dbo.PO_PRL
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
    )
    BEGIN
        -- First amendment â€” read from PO_PRL
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
            ISNULL(l.prstatus, '')                  AS lineStatus
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
        -- 2nd+ amendment â€” PO_PRL deleted; read from latest PO_APRL
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
            ''                                      AS lineStatus
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

-- ============================================================
-- ksp_PR_GetAmendmentById.sql
-- ============================================================

-- ============================================================
-- ksp_PR_GetAmendmentById
-- Returns 2 result sets:
--   #1 â€” Amendment header (PO_APRH; LEFT JOIN PO_PRH as fallback)
--   #2 â€” Amendment lines (PO_APRL + IN_ITEM)
-- PO_PRH is deleted after the first amendment â€” all header field
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
    -- PO_APRH needed for depcode (used by machine lookup; PO_PRH may be deleted)
    JOIN   dbo.PO_APRH ah   ON ah.divcode              = l.divcode
                            AND ah.prno                = l.prno
                            AND CAST(ah.prdate AS DATE) = CAST(l.prdate AS DATE)
                            AND ah.amendno             = l.amendno
    LEFT JOIN dbo.PO_PRL p  ON  p.divcode              = l.divcode
                            AND p.prno                 = l.prno
                            AND CAST(p.prdate AS DATE) = CAST(l.prdate AS DATE)
                            AND p.prsno                = l.prsno
    LEFT JOIN dbo.MM_MACMAS m  ON m.MAC_NO  = l.macno AND m.DIVCODE = l.divcode AND m.DEPCODE = ah.depcode
    LEFT JOIN dbo.IN_CC     cc ON cc.cccode = l.CCCODE AND cc.divcode = l.divcode
    WHERE  l.divcode              = @DivCode
      AND  l.prno                 = @PrNo
      AND  CAST(l.prdate AS DATE) = @PrDate
      AND  l.amendno              = @AmendNo
    ORDER BY l.prsno;
END;
GO

-- ============================================================
-- ksp_PR_GetAmendmentPrint.sql
-- ============================================================

-- ============================================================
-- ksp_PR_GetAmendmentPrint
-- Returns 2 result sets for QuestPDF report generation:
--   #1 â€” Amendment header + PP_DIVMAS letterhead data
--   #2 â€” Amendment lines with item / machine / rate data
-- PO_PRH is deleted after the first amendment â€” LEFT JOIN used;
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

-- ============================================================
-- ksp_PR_SaveAmendment.sql
-- ============================================================

-- ============================================================
-- ksp_PR_SaveAmendment
-- FSD: M01 PR Amendment Entry v2.3  Â§4 Save Sequence
-- ADD:    capture header from PO_PRH â†’ INSERT PO_APRH + PO_APRL
--         â†’ DELETE PO_PRL â†’ DELETE PO_PRH â†’ LogDet_PO
-- MODIFY: UPDATE PO_APRH header, DELETE + re-INSERT PO_APRL, audit.
-- DELETE: DELETE PO_APRL + PO_APRH, audit.
-- Business rules:
--   FY guard via PP_Year (CLOSED <> 'Y')
--   AmendDate defaults to GETDATE() at time of amendment creation
--   RATE_JUSTIFICATION mandatory when RATE_SOURCE = 'MANUAL'
--   row_version concurrency on MODIFY / DELETE
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_SaveAmendment]
    @Mode               VARCHAR(6),         -- 'ADD' | 'MODIFY' | 'DELETE'
    @DivCode            VARCHAR(10),
    @PrNo               NUMERIC(6,0),
    @PrDate             DATE,
    @AmendDate          DATE,
    @AmendmentReason    VARCHAR(1000),
    @RefNo              VARCHAR(6)      = NULL,
    @UserId             VARCHAR(50),
    @HostName           VARCHAR(100)    = NULL,
    @IpAddress          VARCHAR(50)     = NULL,
    @FDate              DATE,
    @LDate              DATE,
    @AmendNo            INT             = NULL,
    @RowVersion         VARBINARY(8)    = NULL,
    @LinesJson          NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- â”€â”€ 1. FY Guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        --    @FDate / @LDate are the open-FY bounds computed by the caller.
        --    Check AmendDate falls within them instead of re-querying PP_Year
        --    (avoids CLOSED = NULL false-negative in some PP_Year configurations).
        IF @AmendDate < @FDate OR @AmendDate > @LDate
            RAISERROR('Amendment Date is outside the open financial year.', 16, 1);

        -- â”€â”€ 3. Validate RATE_JUSTIFICATION when RATE_SOURCE = MANUAL â”€â”€â”€â”€â”€â”€â”€â”€
        IF @Mode <> 'DELETE' AND @LinesJson IS NOT NULL
        BEGIN
            DECLARE @BadItem VARCHAR(10);
            SELECT TOP 1 @BadItem = j.ItemCode
            FROM OPENJSON(@LinesJson)
            WITH (
                ItemCode           VARCHAR(10)  '$.ItemCode',
                RateSource         VARCHAR(20)  '$.RateSource',
                RateJustification  VARCHAR(200) '$.RateJustification'
            ) j
            WHERE UPPER(ISNULL(j.RateSource, '')) = 'MANUAL'
              AND NULLIF(RTRIM(ISNULL(j.RateJustification, '')), '') IS NULL;

            IF @BadItem IS NOT NULL
                RAISERROR('Rate justification is required for item %s when rate is manually overridden.', 16, 1, @BadItem);
        END

        -- â”€â”€ 4. Concurrency check (MODIFY / DELETE) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        IF @Mode IN ('MODIFY', 'DELETE')
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM dbo.PO_APRH
                WHERE  divcode              = @DivCode
                  AND  prno                 = @PrNo
                  AND  CAST(prdate AS DATE) = @PrDate
                  AND  amendno              = @AmendNo
                  AND  row_version          = @RowVersion
            )
                RAISERROR('Record has been modified by another user. Please reload.', 16, 1);
        END

        -- â”€â”€ 5. Resolve AmendNo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        DECLARE @ResolvedAmendNo INT;

        IF @Mode = 'ADD'
        BEGIN
            EXEC usp_GetNextAmendNo
                @DivCode  = @DivCode,
                @FDate    = @FDate,
                @LDate    = @LDate,
                @NewDocNo = @ResolvedAmendNo OUTPUT;

            IF @ResolvedAmendNo = -1
                RAISERROR('Could not generate amendment number. Check PO_DOC_PARA configuration.', 16, 1);
        END
        ELSE
            SET @ResolvedAmendNo = @AmendNo;

        -- â”€â”€ 6. DELETE path â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        IF @Mode = 'DELETE'
        BEGIN
            DELETE FROM dbo.PO_APRL
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
              AND  amendno              = @ResolvedAmendNo;

            DELETE FROM dbo.PO_APRH
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
              AND  amendno              = @ResolvedAmendNo;

            INSERT INTO dbo.LogDet_po
                (divcode, prno, prdate, prsno, itemcode,
                 Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
                 Trans_UserId, Trans_date, moduleNo)
            VALUES
                (@DivCode, @PrNo, @PrDate, @ResolvedAmendNo, '',
                 'PR Amendment', 'D', @HostName, @IpAddress,
                 @UserId, GETDATE(), 4);

            COMMIT TRANSACTION;
            SELECT @ResolvedAmendNo AS AmendNo;
            RETURN;
        END

        -- â”€â”€ 7. ADD: capture header fields from PO_PRH (or latest PO_APRH) â”€â”€â”€â”€
        --         PO_PRH may already be deleted on a 2nd+ amendment
        DECLARE @DepCode    VARCHAR(3);
        DECLARE @ReqName    VARCHAR(25);
        DECLARE @Section    VARCHAR(20);
        DECLARE @IType      CHAR(1);
        DECLARE @PlaceOfIss VARCHAR(30);

        IF @Mode = 'ADD'
        BEGIN
            IF EXISTS (
                SELECT 1 FROM dbo.PO_PRH
                WHERE  divcode              = @DivCode
                  AND  prno                 = @PrNo
                  AND  CAST(prdate AS DATE) = @PrDate
            )
            BEGIN
                SELECT @DepCode = depcode, @ReqName = REQNAME,
                       @Section = SECTION, @IType = ITYPE, @PlaceOfIss = PLACEOFISS
                FROM   dbo.PO_PRH
                WHERE  divcode              = @DivCode
                  AND  prno                 = @PrNo
                  AND  CAST(prdate AS DATE) = @PrDate;
            END
            ELSE
            BEGIN
                -- PO_PRH already deleted (2nd+ amendment) â€” read from latest PO_APRH
                SELECT TOP 1
                       @DepCode = depcode, @ReqName = REQNAME,
                       @Section = SECTION, @IType = ITYPE, @PlaceOfIss = PLACEOFISS
                FROM   dbo.PO_APRH
                WHERE  divcode              = @DivCode
                  AND  prno                 = @PrNo
                  AND  CAST(prdate AS DATE) = @PrDate
                ORDER BY amendno DESC;
            END
        END

        -- â”€â”€ 8. ADD: insert header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        DECLARE @CreatedDt VARCHAR(25) =
            CONVERT(VARCHAR(10), GETDATE(), 103) + ' ' +
            CONVERT(VARCHAR(8),  GETDATE(), 108);

        IF @Mode = 'ADD'
        BEGIN
            INSERT INTO dbo.PO_APRH
                (divcode, prno, prdate, amendno, amenddate,
                 amendreason, refno, createdby, createddt,
                 depcode, REQNAME, SECTION, ITYPE, PLACEOFISS)
            VALUES
                (@DivCode, @PrNo, @PrDate, @ResolvedAmendNo, @AmendDate,
                 NULLIF(RTRIM(@AmendmentReason), ''),
                 NULLIF(RTRIM(ISNULL(@RefNo, '')), ''),
                 @UserId, @CreatedDt,
                 @DepCode, @ReqName, @Section, @IType, @PlaceOfIss);
        END

        -- â”€â”€ 9. MODIFY: update header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        ELSE
        BEGIN
            UPDATE dbo.PO_APRH
            SET    amendreason = NULLIF(RTRIM(@AmendmentReason), ''),
                   refno       = NULLIF(RTRIM(ISNULL(@RefNo, '')), '')
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
              AND  amendno              = @ResolvedAmendNo;

            DELETE FROM dbo.PO_APRL
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
              AND  amendno              = @ResolvedAmendNo;
        END

        -- â”€â”€ 10. Insert lines (ADD and MODIFY) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        INSERT INTO dbo.PO_APRL
            (divcode, prno, prdate, amendno, prsno,
             itemcode, macno, qtyind, reqddate, RATE,
             RATE_SOURCE, RATE_JUSTIFICATION,
             curstock, CCCODE, CATCODE, BGRPCODE,
             PLACE, APPCOST, remarks)
        SELECT
            @DivCode,
            @PrNo,
            @PrDate,
            @ResolvedAmendNo,
            j.PrSno,
            RTRIM(j.ItemCode),
            NULLIF(RTRIM(ISNULL(j.MacNo, '')), ''),
            j.QtyInd,
            TRY_CONVERT(DATE, NULLIF(j.ReqdDate, ''), 103),
            j.Rate,
            ISNULL(NULLIF(RTRIM(j.RateSource), ''), 'ORIGINAL'),
            NULLIF(RTRIM(ISNULL(j.RateJustification, '')), ''),
            ISNULL(j.CurStock, 0),
            NULLIF(j.CcCode, 0),
            NULLIF(RTRIM(ISNULL(j.CatCode, '')), ''),
            NULLIF(RTRIM(ISNULL(j.BgrpCode, '')), ''),
            NULLIF(RTRIM(ISNULL(j.Place, '')), ''),
            NULLIF(j.AppCost, 0),
            NULLIF(UPPER(LEFT(RTRIM(ISNULL(j.Remarks, '')), 50)), '')
        FROM OPENJSON(@LinesJson)
        WITH (
            PrSno              INT             '$.PrSno',
            ItemCode           VARCHAR(10)     '$.ItemCode',
            MacNo              VARCHAR(5)      '$.MacNo',
            QtyInd             NUMERIC(12,3)   '$.QtyInd',
            ReqdDate           VARCHAR(10)     '$.ReqdDate',
            Rate               NUMERIC(13,4)   '$.Rate',
            RateSource         VARCHAR(20)     '$.RateSource',
            RateJustification  VARCHAR(200)    '$.RateJustification',
            CurStock           NUMERIC(12,3)   '$.CurStock',
            CcCode             NUMERIC(4,0)    '$.CcCode',
            CatCode            VARCHAR(1)      '$.CatCode',
            BgrpCode           VARCHAR(4)      '$.BgrpCode',
            Place              VARCHAR(40)     '$.Place',
            AppCost            NUMERIC(11,2)   '$.AppCost',
            Remarks            VARCHAR(50)     '$.Remarks'
        ) j
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

        -- â”€â”€ 11. ADD: DELETE original PR lines then header (FSD Â§4 Steps 6-7) â”€â”€
        IF @Mode = 'ADD'
        BEGIN
            DELETE FROM dbo.PO_PRL
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate;

            DELETE FROM dbo.PO_PRH
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate;
        END

        -- â”€â”€ 12. Audit log â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        INSERT INTO dbo.LogDet_po
            (divcode, prno, prdate, prsno, itemcode, macno, quantity, RATE,
             Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
             Trans_UserId, Trans_date, moduleNo, reqname, createdby)
        SELECT
            @DivCode, @PrNo, @PrDate, l.prsno, l.itemcode, l.macno,
            CAST(l.qtyind AS NUMERIC(15,0)), l.RATE,
            'PR Amendment', @Mode, @HostName, @IpAddress,
            @UserId, GETDATE(), 4, '', @UserId
        FROM dbo.PO_APRL l
        WHERE  l.divcode              = @DivCode
          AND  l.prno                 = @PrNo
          AND  CAST(l.prdate AS DATE) = @PrDate
          AND  l.amendno              = @ResolvedAmendNo;

        COMMIT TRANSACTION;
        SELECT @ResolvedAmendNo AS AmendNo;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Sev INT            = ERROR_SEVERITY();
        RAISERROR(@Msg, @Sev, 1);
    END CATCH
END;
GO

-- ============================================================
-- PR Foreclosure & Cancellation SPs  (updated 28 May 2026)
-- ============================================================

GO
CREATE OR ALTER PROCEDURE ksp_PR_GetOpenForForeclosure
    @divcode      varchar(10),
    @fdate        date,
    @ldate        date,
    @prno_filter  varchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            a.prno                                        AS PrNo,
            -- PO_PRH.prdate may be NULL on legacy records; fall back to PO_PRL.prdate
            ISNULL(CONVERT(varchar(12), ISNULL(a.prdate, b.prdate), 106), '') AS PRDate,
            RTRIM(ISNULL(c.Depname, ''))                  AS Department,
            RTRIM(ISNULL(a.depcode, ''))                  AS DepCode,
            CAST(ISNULL(b.prsno, 0) AS INT)               AS PrSno,
            RTRIM(b.itemcode)                             AS ItemCode,
            RTRIM(ISNULL(d.Itemname, ''))                 AS ItemName,
            RTRIM(ISNULL(d.UOM, ''))                      AS UOM,
            ISNULL(b.QTYREQD, 0)                         AS PrQty,
            ISNULL(b.QTYORD,  0)                         AS OrdQty,
            ISNULL(b.QTYREQD, 0)
                - ISNULL(b.QTYORD,  0)
                - ISNULL(b.enq_qty, 0)                    AS Balance,
            RTRIM(ISNULL(e.MAC_NO, ''))                   AS SccCode,
            -- Convert raw PRSTATUS char to readable label matching the HTML prototype badges
            CASE RTRIM(ISNULL(b.PRSTATUS, ''))
                WHEN 'E' THEN 'Enquired'
                WHEN 'C' THEN 'Received'
                WHEN 'X' THEN 'Cancelled'
                WHEN 'Z' THEN 'Force Closed'
                WHEN 'O' THEN
                    CASE WHEN ISNULL(b.QTYORD, 0) > 0 THEN 'Ordered' ELSE 'Order Cancelled' END
                ELSE 'Requested'
            END                                           AS PrevStatus
        FROM  PO_PRH   a
        INNER JOIN PO_PRL    b ON b.prno    = a.prno
                               AND b.divcode = a.divcode
        INNER JOIN In_dep    c ON c.depcode  = a.depcode
                               AND c.divcode  = a.divcode
        INNER JOIN in_item   d ON d.itemcode  = b.itemcode
        LEFT  JOIN MM_MACMAS e ON e.MACFLAG  = 'M'
                               AND e.DIVCODE  = b.divcode
                               AND e.DEPCODE  = b.depcode
                               AND e.MAC_NO   = b.macno
        WHERE a.divcode = @divcode
          AND CAST(ISNULL(a.prdate, b.prdate) AS DATE) BETWEEN @fdate AND @ldate
          AND ISNULL(a.cancelflag, '') <> 'Y'          -- fix: was 'IS NULL', live DB stores 'N'
          AND ISNULL(b.FClosed, 'N') <> 'Y'
          AND RTRIM(ISNULL(b.prstatus, '')) <> 'X'   -- FC-BR-04: exclude individually-cancelled lines
          AND RTRIM(ISNULL(b.prstatus, '')) <> 'C'   -- FC-EX-09/BR-03: exclude Received-status lines
          AND (ISNULL(b.QTYREQD, 0) - ISNULL(b.QTYORD, 0) - ISNULL(b.enq_qty, 0)) > 0
          AND (ISNULL(b.QTYORD, 0) - ISNULL(b.qtyrec, 0)) >= 0
          AND (@prno_filter IS NULL
               OR CAST(a.prno AS varchar(20)) LIKE @prno_filter + '%')
        ORDER BY a.prdate, a.prno, b.prsno;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;

GO
CREATE OR ALTER PROCEDURE ksp_PR_GetCancellablePRs
    @divcode varchar(10),
    @yfdate  datetime,
    @yldate  datetime
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            a.prno                                        AS PrNo,
            ISNULL(CONVERT(varchar(12), a.prdate, 106),'') AS PRDate,
            RTRIM(ISNULL(a.depcode, ''))                  AS DepCode,
            RTRIM(ISNULL(c.Depname, ''))                  AS Department,
            RTRIM(ISNULL(a.reqname, ''))                  AS Requester,
            (SELECT COUNT(*)
               FROM PO_PRL x
              WHERE x.prno    = a.prno
                AND x.prdate  = a.prdate
                AND x.divcode = a.divcode)                 AS ItemCount,
            RTRIM(ISNULL(a.refno,   ''))                  AS RefNo,
            RTRIM(ISNULL(t.idesc, ISNULL(a.ITYPE, '')))   AS PRType,
            RTRIM(ISNULL(a.section, ''))                  AS Section,
            RTRIM(ISNULL(a.reqname, ''))                  AS CreatedBy,
            RTRIM(ISNULL(
                (SELECT TOP 1 PRSTATUS
                   FROM PO_PRL x
                  WHERE x.prno    = a.prno
                    AND x.prdate  = a.prdate
                    AND x.divcode = a.divcode
                  ORDER BY x.prsno),
            ''))                                           AS Status
        FROM  PO_PRH a
        INNER JOIN In_dep        c ON c.depcode = a.depcode
                                   AND c.divcode = a.divcode
        LEFT  JOIN PO_INDENTTYPE t ON t.itype   = a.ITYPE
        WHERE a.divcode = @divcode
          AND ISNULL(a.cancelflag, '') <> 'Y'            -- fix: was 'IS NULL', live DB stores 'N'
          AND ISNULL(a.APPFLG, 'N') <> 'Y'              -- only un-approved PRs can be cancelled
          AND a.prdate BETWEEN @yfdate AND @yldate
          AND NOT EXISTS (
              SELECT 1 FROM PO_ENQL x
               WHERE x.prno    = a.prno
                 AND x.prdate  = a.prdate
                 AND x.divcode = a.divcode)
          -- PO_ORD check: confirm actual PO order table name before enabling
          -- AND NOT EXISTS (SELECT 1 FROM <po_order_table> x WHERE x.prno=a.prno AND x.divcode=a.divcode)
          AND NOT EXISTS (
              SELECT 1 FROM PO_PRL x
               WHERE x.prno    = a.prno
                 AND x.prdate  = a.prdate
                 AND x.divcode = a.divcode
                 AND ISNULL(x.QTYORD, 0) > 0)
        ORDER BY a.prdate DESC, a.prno DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;

GO
-- Add pre_cancel_status to PO_PRH if it does not already exist (BR-UNDO-01)
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.PO_PRH')
       AND name = N'pre_cancel_status'
)
BEGIN
    ALTER TABLE dbo.PO_PRH ADD pre_cancel_status char(1) NULL;
END;
GO

CREATE OR ALTER PROCEDURE ksp_PR_GetCancelledPRsForUndo
    @divcode varchar(10),
    @yfdate  datetime,
    @yldate  datetime
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            a.prno,
            CONVERT(varchar(12), a.prdate,   106) AS PRDate,
            a.depcode                             AS DepCode,
            c.Depname                             AS Department,
            ISNULL(a.reqname, '')                 AS RequestedBy,
            CONVERT(varchar(12), a.canceldt, 106) AS CancelledOn,
            ISNULL(a.pre_cancel_status, '')        AS PrevStatus
        FROM  PO_PRH a
        INNER JOIN In_dep c ON c.depcode  = a.depcode
                            AND c.divcode  = a.divcode
        WHERE a.divcode    = @divcode
          AND a.cancelflag = 'Y'
          AND a.prdate BETWEEN @yfdate AND @yldate
        ORDER BY a.canceldt DESC, a.prno DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;


GO

-- ============================================================
-- ksp_PR_GetForCancellation
-- Returns two result sets for a PR under cancellation review.
--   Result Set 1 : PR header (single row)
--   Result Set 2 : PR line items (ordered by prsno)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetForCancellation
(
    @DivCode    VARCHAR(2),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE,
    @DepCode    VARCHAR(3)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Result Set 1: Header
    SELECT
        a.prno                                              AS PrNo,
        CONVERT(VARCHAR(12), a.prdate, 106)                 AS PRDate,
        a.depcode                                           AS DepCode,
        c.Depname                                           AS Department,
        ISNULL(a.section,  '')                              AS Section,
        ISNULL(a.reqname,  '')                              AS RequestedBy,
        ISNULL(t.idesc, ISNULL(a.ITYPE,''))                 AS PRType,
        ISNULL(a.refno,    '')                              AS RefNo,
        ISNULL(a.reqname,  '')                              AS CreatedBy,
        ISNULL((SELECT TOP 1 PRSTATUS FROM PO_PRL
                 WHERE prno = a.prno AND divcode = a.divcode
                 ORDER BY prsno), '')                       AS Status
    FROM  PO_PRH a
    INNER JOIN In_dep        c ON c.depcode = a.depcode AND c.divcode = a.divcode
    LEFT  JOIN PO_INDENTTYPE t ON t.itype   = a.ITYPE
    WHERE a.divcode = @DivCode
      AND a.prno    = @PrNo
      AND a.prdate  = @PrDate
      AND a.depcode = @DepCode;

    -- Result Set 2: Line items
    SELECT
        CAST(ISNULL(b.prsno, 0) AS INT)                        AS Sno,
        b.itemcode                                             AS ItemCode,
        ISNULL(d.Itemname, '')                                 AS ItemName,
        ISNULL(d.UOM, '')                                      AS UOM,
        ISNULL(b.QTYIND,  0)                                   AS QtyRequired,
        ISNULL(b.QTYREQD, 0)                                   AS QtyApproved,
        ISNULL(b.QTYord,  0)                                   AS QtyOrdered,
        ISNULL(b.qtyrec,  0)                                   AS QtyReceived,
        ISNULL(d.curstk,  0)                                   AS CurrentStock,
        ISNULL(d.RATE,    0)                                   AS Rate,
        ISNULL(b.appcost, 0)                                   AS ApproxCost,
        ISNULL(CONVERT(VARCHAR(12), b.reqddate, 106), '')      AS ReqdDate,
        ISNULL(e.Description, '')                              AS Machine,
        ISNULL(b.place,   '')                                  AS PlaceOfIssue,
        ISNULL(b.remarks, '')                                  AS Remarks,
        CAST(CASE WHEN ISNULL(b.sample,'N')='Y' THEN 1 ELSE 0 END AS BIT) AS IsSample
    FROM  PO_PRL   b
    INNER JOIN in_item   d ON d.itemcode = b.itemcode
    LEFT  JOIN MM_MACMAS e ON e.MACFLAG  = 'M'
                           AND e.DIVCODE  = b.divcode
                           AND e.DEPCODE  = b.depcode
                           AND e.MAC_NO   = b.macno
    WHERE b.divcode = @DivCode
      AND b.prno    = @PrNo
      AND b.prdate  = @PrDate
    ORDER BY b.prsno;
END;

GO

-- ============================================================
-- ksp_PR_Cancel
-- Cancels a PR:
--   1. Captures current line PRSTATUS as pre_cancel_status
--      (BR-UNDO-01 â€” read BEFORE the transaction begins)
--   2. Sets cancelflag='Y', stores cancel reason and pre-status
--      on the PR header
--   3. Sets PRSTATUS='X' on all PR lines
--   4. Writes audit log entry (Trans_Mod='ADD')
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_Cancel
(
    @DivCode      VARCHAR(2),
    @PrNo         NUMERIC(6,0),
    @PrDate       DATE,
    @DepCode      VARCHAR(3),
    @CancelReason VARCHAR(200),
    @UserId       VARCHAR(50),
    @HostName     VARCHAR(100) = NULL,
    @IpAddress    VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- BR-UNDO-01: Capture pre_cancel_status before the transaction
    DECLARE @PreStatus VARCHAR(5);
    SELECT TOP 1 @PreStatus = ISNULL(PRSTATUS, '')
    FROM PO_PRL
    WHERE divcode = @DivCode AND prno = @PrNo AND prdate = @PrDate
    ORDER BY prsno;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Update PR header with cancellation details
        UPDATE PO_PRH
        SET    cancelflag        = 'Y',
               canceldt          = GETDATE(),
               canreason         = UPPER(@CancelReason),
               pre_cancel_status = @PreStatus
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate
          AND  depcode = @DepCode;

        -- Step 2: Mark all PR lines as cancelled
        UPDATE PO_PRL
        SET    PRSTATUS = 'X'
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate;

        -- Step 3: Audit log
        INSERT INTO LogDet_PO
            (divcode, prno, prdate, depcode,
             username, Trans_date, Trans_UserId,
             Trans_Name, Trans_Mod,
             Trans_IPADD, Trans_Host)
        VALUES
            (@DivCode, @PrNo, @PrDate, @DepCode,
             @UserId, GETDATE(), @UserId,
             'Purchase Requisition Cancellation', 'ADD',
             @IpAddress, @HostName);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

-- ============================================================
-- ksp_PR_UndoCancellation
-- Reverses a PR cancellation:
--   1. Reads pre_cancel_status from PO_PRH header
--      (BR-UNDO-01 â€” read BEFORE the transaction begins)
--   2. Clears all cancel columns on the header
--   3. Restores PO_PRL PRSTATUS to the pre-cancel value
--   4. Writes audit log entry (Trans_Mod='DELETE')
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_UndoCancellation
(
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATE,
    @DepCode   VARCHAR(3),
    @UserId    VARCHAR(50),
    @HostName  VARCHAR(100) = NULL,
    @IpAddress VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- BR-UNDO-01: Read pre_cancel_status before clearing it
    DECLARE @PreStatus VARCHAR(5);
    SELECT @PreStatus = ISNULL(pre_cancel_status, '')
    FROM PO_PRH
    WHERE divcode = @DivCode AND prno = @PrNo AND prdate = @PrDate;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Clear all cancel columns from the header
        UPDATE PO_PRH
        SET    cancelflag        = NULL,
               canceldt          = NULL,
               canreason         = NULL,
               pre_cancel_status = NULL
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate
          AND  depcode = @DepCode;

        -- Step 2: Restore PR lines to pre-cancel status (BR-UNDO-01)
        UPDATE PO_PRL
        SET    PRSTATUS = CASE WHEN @PreStatus = '' THEN NULL ELSE @PreStatus END
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate;

        -- Step 3: Audit log â€” Trans_Mod='DELETE' for undo
        INSERT INTO LogDet_PO
            (divcode, prno, prdate, depcode,
             username, Trans_date, Trans_UserId,
             Trans_Name, Trans_Mod,
             Trans_IPADD, Trans_Host)
        VALUES
            (@DivCode, @PrNo, @PrDate, @DepCode,
             @UserId, GETDATE(), @UserId,
             'Purchase Requisition Cancellation', 'DELETE',
             @IpAddress, @HostName);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

GO

-- ============================================================
-- ksp_PR_SaveForeclosureLine
-- Force-closes a single PR line:
--   1. Sets prstatus='Z', FClosed='Y', FCloseddt=GETDATE() on PO_PRL
--   2. Resolves depcode from PO_PRH
--   3. Writes audit log entry (Trans_Mod='ADD')
-- NOTE: PO_PRH has NO prstatus column — Step 4 (header status promotion)
-- removed. Foreclosure status tracked via PO_PRL.prstatus only.
-- Called once per line from C#, which wraps all calls in an
-- outer UnitOfWork transaction covering the full save batch.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_SaveForeclosureLine
(
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATE,
    @PrSno     INT,
    @ItemCode  VARCHAR(15),
    @Balance   NUMERIC(10,3),
    @UserId    VARCHAR(50),
    @HostName  VARCHAR(100) = NULL,
    @IpAddress VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Force-close the line (@PrSno=0 targets all lines for the item)
    UPDATE PO_PRL
    SET    prstatus  = 'Z',
           FClosed   = 'Y',
           FCloseddt = GETDATE()
    WHERE  divcode  = @DivCode
      AND  prno     = @PrNo
      AND  prdate   = @PrDate
      AND  itemcode = @ItemCode
      AND  (@PrSno = 0 OR prsno = @PrSno)
      AND  prstatus <> 'C';   -- FC-EX-09/BR-03: never force-close a Received line

    -- Step 2: Resolve depcode from header
    DECLARE @DepCode VARCHAR(3);
    SELECT TOP 1 @DepCode = depcode
    FROM PO_PRH
    WHERE divcode = @DivCode AND prno = @PrNo AND prdate = @PrDate;

    -- Step 3: Audit log
    INSERT INTO LogDet_po
        (divcode, prno, prdate, depcode,
         Trans_UserId, prsno, itemcode, Quantity,
         username, Trans_date,
         Trans_Name, Trans_Mod,
         Trans_IPADD, Trans_Host)
    VALUES
        (@DivCode, @PrNo, @PrDate, @DepCode,
         @UserId, @PrSno, @ItemCode, @Balance,
         @UserId, GETDATE(),
         'Purchase Requisition Foreclosure', 'ADD',
         @IpAddress, @HostName);

    -- Step 4 REMOVED: PO_PRH has no prstatus column.
    -- Foreclosure completion is determined by checking PO_PRL.prstatus
    -- on all lines — handled in the application layer if needed.
END;

GO


-- ── PR First Level Approval (schema-verified 2026-05-29) ──────────────────────────
-- ksp_PR_GetPoParaForApproval
CREATE OR ALTER PROCEDURE ksp_PR_GetPoParaForApproval
    @DivCode VARCHAR(2)
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_PARA columns: divcode varchar(2), APPUSERLEVEL1 numeric(5,0),
    --   AppUserLevel2 numeric(5,0), AppUserLevel3 numeric(5,0),
    --   AppUserLabel1 varchar(35), AppUserLabel2 varchar(35), AppUserLabel3 varchar(35)
    SELECT TOP 1
        divcode         AS DivCode,
        APPUSERLEVEL1   AS AppUserLevel1,
        AppUserLevel2   AS AppUserLevel2,
        AppUserLevel3   AS AppUserLevel3,
        AppUserLabel1   AS AppUserLabel1,
        AppUserLabel2   AS AppUserLabel2,
        AppUserLabel3   AS AppUserLabel3
    FROM PO_PARA
    WHERE divcode = @DivCode;
END;

GO

-- ksp_PR_GetDeptForUser
CREATE OR ALTER PROCEDURE ksp_PR_GetDeptForUser
    @DivCode VARCHAR(2),
    @UserId  VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_IndentAppUser.UserID is varchar(6) — no PP_PASSWD join needed
    SELECT DISTINCT
        d.DEPCODE AS DepCode,
        d.DEPNAME AS DepName
    FROM PO_IndentAppUser u
    INNER JOIN IN_DEP d
        ON  d.DEPCODE  = u.Depcode
        AND d.divcode  = u.Divcode
    WHERE u.Divcode = @DivCode
      AND u.UserID  = @UserId
    ORDER BY d.DEPNAME;
END;

GO

-- ksp_PR_GetFirstApprovalHeader
CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovalHeader
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- IN_SCC: SCCCODE numeric(6,0), SCCNAME varchar(40), Divcode varchar(2), DEPCODE varchar(5)
    -- PR_EMP: ename varchar(30), empno decimal(5,0)  — NOT empname
    -- PO_PRH.REQNAME varchar(10) stores empno as string; use TRY_CAST for the join
    SELECT
        h.divcode                               AS DivCode,
        h.prno                                  AS PrNo,
        h.prdate                                AS PrDate,
        h.depcode                               AS DepCode,
        d.DEPNAME                               AS DepName,
        h.refno                                 AS RefNo,
        h.SECTION                               AS Section,
        h.SubCost                               AS SubCost,
        s.SCCNAME                               AS SccName,
        h.APP1                                  AS App1,
        h.APP2                                  AS App2,
        h.APP3                                  AS App3,
        h.APPFLG                                AS AppFlg,
        h.APP1DATE                              AS App1Date,
        ISNULL(e.ename, h.REQNAME)              AS ReqName
    FROM PO_PRH h
    LEFT JOIN IN_DEP  d ON d.DEPCODE  = h.depcode
                       AND d.divcode  = h.divcode
    LEFT JOIN IN_SCC  s ON s.SCCCODE  = h.SubCost
                       AND s.Divcode  = h.divcode
                       AND s.DEPCODE  = h.depcode
    LEFT JOIN PR_EMP  e ON TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno
                       AND e.divcode  = h.divcode
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND h.prdate  = @PrDate;
END;

GO

-- ksp_PR_GetFirstApprovalLines
CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovalLines
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_PRL: macno varchar(5)  — NOT mac_no
    -- mm_MACmas: MAC_NO varchar(5), DESCRIPTION varchar(30)  — MAC_NO uppercase
    SELECT
        l.prsno                                   AS PrSno,
        l.itemcode                                AS ItemCode,
        i.ITEMNAME                                AS ItemName,
        i.CUOM                                    AS Uom,
        m.DESCRIPTION                             AS Machine,
        ISNULL(i.CURSTK, 0)                       AS CurStock,
        ISNULL(l.qtyind,  0)                      AS QtyInd,
        ISNULL(l.qtyreqd, 0)                      AS QtyReqd,
        ISNULL(l.FirstAppQty, 0)                  AS FirstAppQty,
        ISNULL(l.SecondAppQty, 0)                 AS SecondAppQty,
        ISNULL(l.ThirdAppQty, 0)                  AS ThirdAppQty,
        ISNULL(l.qtyord, 0)                       AS QtyOrd,
        ISNULL(l.qtyrec, 0)                       AS QtyRec,
        ISNULL(l.RATE, ISNULL(i.RATE, 0))         AS Rate,
        ISNULL(l.VALUE, 0)                        AS Value,
        l.reqddate                                AS ReqdDate,
        l.FirstApp                                AS FirstApp,
        l.prstatus                                AS PrStatus,
        l.PLACE                                   AS Place,
        ISNULL(l.APPCOST, 0)                      AS AppCost,
        l.remarks                                 AS Remarks,
        l.BGRPCODE                                AS BgrpCode,
        l.macno                                   AS MacNo
    FROM PO_PRL l
    INNER JOIN IN_ITEM   i ON i.ITEMCODE  = l.itemcode
    LEFT  JOIN mm_MACmas m ON m.MAC_NO    = l.macno
                          AND m.DEPCODE   = l.Depcode
                          AND m.DIVCODE   = l.divcode
    WHERE l.divcode = @DivCode
      AND l.prno    = @PrNo
      AND l.prdate  = @PrDate
    ORDER BY l.prsno;
END;

GO

-- ksp_PR_SaveFirstApproval
CREATE OR ALTER PROCEDURE ksp_PR_SaveFirstApproval
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATETIME,
    @AppDate   DATETIME,
    @UserId    VARCHAR(50),
    @UserName  VARCHAR(50),
    @IpAddress VARCHAR(50),
    @HostName  VARCHAR(50),
    @ModuleNo  INT,
    @LinesJson NVARCHAR(MAX)       -- JSON array of approved lines
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Update PO_PRH header ──────────────────────────────────────────
        -- APP1TIME is datetime — use GETDATE(), not a varchar string
        UPDATE PO_PRH
        SET APPFLG   = 'Y',
            APP1     = @UserId,
            APP1DATE = @AppDate,
            APP1TIME = GETDATE()
        WHERE divcode = @DivCode
          AND prno    = @PrNo
          AND prdate  = @PrDate;

        -- ── 2. Parse JSON lines ──────────────────────────────────────────────
        DECLARE @Lines TABLE (
            PrSno       NUMERIC(5,0),
            ItemCode    VARCHAR(10),
            DepCode     VARCHAR(3),
            QtyReqd     NUMERIC(12,3),
            FirstAppQty NUMERIC(12,3),
            Rate        NUMERIC(13,4),
            MacNo       VARCHAR(5),
            SubCost     NUMERIC(5,0),
            Uom         VARCHAR(3)
        );

        INSERT INTO @Lines (PrSno, ItemCode, DepCode, QtyReqd, FirstAppQty, Rate, MacNo, SubCost, Uom)
        SELECT
            CAST(j.PrSno        AS NUMERIC(5,0)),
            j.ItemCode,
            j.DepCode,
            CAST(j.QtyReqd      AS NUMERIC(12,3)),
            CAST(j.FirstAppQty  AS NUMERIC(12,3)),
            CAST(j.Rate         AS NUMERIC(13,4)),
            j.MacNo,
            TRY_CAST(j.SubCost  AS NUMERIC(5,0)),
            j.Uom
        FROM OPENJSON(@LinesJson) WITH (
            PrSno       NVARCHAR(20) '$.prSno',
            ItemCode    VARCHAR(10)  '$.itemCode',
            DepCode     VARCHAR(3)   '$.depCode',
            QtyReqd     NVARCHAR(20) '$.qtyReqd',
            FirstAppQty NVARCHAR(20) '$.firstAppQty',
            Rate        NVARCHAR(20) '$.rate',
            MacNo       VARCHAR(5)   '$.macNo',
            SubCost     NVARCHAR(20) '$.subCost',
            Uom         VARCHAR(3)   '$.uom'
        ) j;

        -- ── 3. Update PO_PRL lines ───────────────────────────────────────────
        -- PO_PRL columns: qtyreqd, FirstAppQty, FirstApp, RATE, VALUE, prstatus
        UPDATE l
        SET l.qtyreqd     = ln.QtyReqd,
            l.FirstAppQty = ln.FirstAppQty,
            l.FirstApp    = 'Y',
            l.RATE        = ln.Rate,
            l.VALUE       = ln.QtyReqd * ln.Rate,
            l.prstatus    = 'F',
            l.FirstappUser= @UserId
        FROM PO_PRL l
        INNER JOIN @Lines ln
            ON  ln.PrSno    = l.prsno
            AND ln.ItemCode = l.itemcode
        WHERE l.divcode = @DivCode
          AND l.prno    = @PrNo
          AND l.prdate  = @PrDate;

        -- ── 4. Audit log per line ────────────────────────────────────────────
        -- LogDet_po columns verified from live schema
        INSERT INTO LogDet_po (
            divcode, prno, prdate, itemcode, depcode,
            Trans_UserId, prsno, Quantity, username,
            Trans_date, Trans_Name, Trans_Mod,
            Trans_IPADD, Trans_Host,
            UOM, RATE, macno, SubCost, moduleNo,
            docno, docdt,
            FirstappUser, AppUser, Appdate, Appqty
        )
        SELECT
            @DivCode, @PrNo, @PrDate, ln.ItemCode, ln.DepCode,
            @UserId, ln.PrSno, ln.QtyReqd, @UserName,
            GETDATE(), 'Purchase Requisition Approval', 'ADD',
            @IpAddress, @HostName,
            ln.Uom, ln.Rate, ln.MacNo, ln.SubCost, @ModuleNo,
            @PrNo, @PrDate,
            @UserId, @UserId, @AppDate, ln.FirstAppQty
        FROM @Lines ln;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

-- ksp_PR_DeleteFirstApproval
-- OI-07 HELD: Header-level reset (all lines). Per-line scope pending CEO confirmation.
CREATE OR ALTER PROCEDURE ksp_PR_DeleteFirstApproval
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATETIME,
    @UserId    VARCHAR(50),
    @UserName  VARCHAR(50),
    @IpAddress VARCHAR(50),
    @HostName  VARCHAR(50),
    @ModuleNo  INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Reset PO_PRH header ───────────────────────────────────────────
        -- PO_PRH has NO PRSTATUS column — do not update it here
        UPDATE PO_PRH
        SET APPFLG   = 'N',
            APP1     = NULL,
            APP1DATE = NULL,
            APP1TIME = NULL
        WHERE divcode = @DivCode
          AND prno    = @PrNo
          AND prdate  = @PrDate;

        -- ── 2. Reset PO_PRL lines (where DirectApp IS NULL) ──────────────────
        UPDATE PO_PRL
        SET qtyreqd     = NULL,
            FirstAppQty = 0,
            FirstApp    = NULL,
            prstatus    = NULL,
            FirstappUser= NULL
        WHERE divcode   = @DivCode
          AND prno      = @PrNo
          AND prdate    = @PrDate
          AND (DirectApp IS NULL OR DirectApp <> 'Y');

        -- ── 3. Audit log per affected line ───────────────────────────────────
        INSERT INTO LogDet_po (
            divcode, prno, prdate, itemcode, depcode,
            Trans_UserId, prsno, Quantity, username,
            Trans_date, Trans_Name, Trans_Mod,
            Trans_IPADD, Trans_Host,
            UOM, RATE, macno, moduleNo,
            docno, docdt
        )
        SELECT
            @DivCode, @PrNo, @PrDate, l.itemcode, l.Depcode,
            @UserId, l.prsno, ISNULL(l.qtyind, 0), @UserName,
            GETDATE(), 'Purchase Requisition Approval', 'DELETE',
            @IpAddress, @HostName,
            i.CUOM, ISNULL(l.RATE, 0), l.macno, @ModuleNo,
            @PrNo, @PrDate
        FROM PO_PRL l
        INNER JOIN IN_ITEM i ON i.ITEMCODE = l.itemcode
        WHERE l.divcode  = @DivCode
          AND l.prno     = @PrNo
          AND l.prdate   = @PrDate
          AND (l.DirectApp IS NULL OR l.DirectApp <> 'Y');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

-- ksp_PR_GetFirstApprovalReport
CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovalReport
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Header + division letterhead
    SELECT
        -- Division letterhead (PP_DIVMAS — same columns as ksp_PR_GetPrint)
        dv.DIV_LOGO                                          AS DivLogo,
        RTRIM(ISNULL(dv.DIVNAME,        ''))                 AS DivName,
        RTRIM(ISNULL(dv.div_printname,  ''))                 AS DivPrintName,
        RTRIM(ISNULL(dv.div_unitname,   ''))                 AS DivUnitName,
        RTRIM(ISNULL(dv.DIVISION_ADDR1, ''))                 AS DivAddress1,
        RTRIM(ISNULL(dv.DIVISION_ADDR2, ''))                 AS DivAddress2,
        RTRIM(ISNULL(dv.DIVISION_ADDR3, ''))                 AS DivAddress3,
        RTRIM(ISNULL(dv.PINCODE,        ''))                 AS DivPinCode,
        RTRIM(ISNULL(dv.STATENAME,      ''))                 AS DivState,
        RTRIM(ISNULL(dv.PHONE1,         ''))                 AS DivPhone,
        RTRIM(ISNULL(dv.EMAIL,          ''))                 AS DivEmail,

        -- PR header
        h.divcode                                            AS DivCode,
        h.prno                                               AS PrNo,
        h.prdate                                             AS PrDate,
        RTRIM(ISNULL(h.depcode, ''))                         AS DepCode,
        RTRIM(ISNULL(d.DEPNAME, ''))                         AS DepName,
        RTRIM(ISNULL(NULLIF(RTRIM(h.refno), '0'), ''))       AS RefNo,
        RTRIM(ISNULL(h.SECTION, ''))                         AS Section,
        h.APP1DATE                                           AS App1Date,
        RTRIM(ISNULL(e.ename, h.REQNAME))                    AS ReqName,
        RTRIM(ISNULL(h.APP1, ''))                            AS ApproverUserId,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby,''))) AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                       AS CreatedDt

    FROM PO_PRH h
    LEFT JOIN PP_DIVMAS dv ON dv.DIVCODE = h.divcode
    LEFT JOIN IN_DEP    d  ON d.DEPCODE  = h.depcode AND d.divcode = h.divcode
    LEFT JOIN PR_EMP    e  ON TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno
                          AND e.divcode = h.divcode
    OUTER APPLY (
        SELECT TOP 1 user_name FROM PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(h.createdby)
          AND RTRIM(divcode)  = RTRIM(h.divcode)
    ) pwd
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND h.prdate  = @PrDate;

    -- Result set 2: Lines (FirstApp = 'Y' only)
    SELECT
        l.prsno                      AS PrSno,
        RTRIM(l.itemcode)            AS ItemCode,
        RTRIM(ISNULL(i.ITEMNAME,'')) AS ItemName,
        RTRIM(ISNULL(i.CUOM,    '')) AS Uom,
        ISNULL(l.qtyind, 0)          AS QtyInd,
        ISNULL(l.FirstAppQty, 0)     AS FirstAppQty,
        ISNULL(l.RATE, 0)            AS Rate,
        RTRIM(ISNULL(l.remarks,''))  AS Remarks
    FROM PO_PRL l
    INNER JOIN IN_ITEM i ON i.ITEMCODE = l.itemcode
    WHERE l.divcode  = @DivCode
      AND l.prno     = @PrNo
      AND l.prdate   = @PrDate
      AND l.FirstApp = 'Y'
    ORDER BY l.prsno;
END;

GO

-- ksp_PR_CheckUserApprovalLevel
CREATE OR ALTER PROCEDURE ksp_PR_CheckUserApprovalLevel
    @DivCode VARCHAR(2),
    @UserId  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- PP_PASSWD: user_id varchar(5), alevel decimal(3,0) — NOT USERID / ULEVEL
    -- PO_PARA:   APPUSERLEVEL1 numeric(5,0)
    SELECT
        p.alevel            AS UserLevel,
        pa.APPUSERLEVEL1    AS AppUserLevel1,
        pa.AppUserLevel2    AS AppUserLevel2,
        pa.AppUserLevel3    AS AppUserLevel3,
        pa.AppUserLabel1    AS AppUserLabel1,
        pa.AppUserLabel2    AS AppUserLabel2,
        pa.AppUserLabel3    AS AppUserLabel3
    FROM PP_PASSWD p
    CROSS JOIN PO_PARA pa
    WHERE p.divcode  = @DivCode
      AND p.user_id  = @UserId
      AND pa.divcode = @DivCode;
END;

GO



-- ksp_PR_GetPendingFirstApproval
CREATE OR ALTER PROCEDURE ksp_PR_GetPendingFirstApproval
    @DivCode VARCHAR(2),
    @Dep     VARCHAR(3)       -- specific depcode from PO_IndentAppUser for logged-in user
AS
BEGIN
    SET NOCOUNT ON;

    -- No year guard — no @yfdate / @yldate parameters (confirmed FSD OI-02 closed)
    --
    -- Eligible PR = header not cancelled + at least one line where:
    --   FirstApp IS NULL AND SecondApp IS NULL AND ThirdApp IS NULL
    --   AND DirectApp IS NULL AND line not force-closed (FClosed IS NULL or <> 'Y')
    --
    -- FClosed exists on PO_PRL (col 57), NOT on PO_PRH — checked via EXISTS subquery.
    -- cancelflag exists on PO_PRH (col 22).

    SELECT DISTINCT
        h.prno              AS PrNo,
        h.prdate            AS PrDate,
        h.depcode           AS DepCode,
        ISNULL(d.DEPNAME, h.depcode) AS DepName,
        ISNULL(h.refno, '') AS RefNo,
        ISNULL(h.SECTION,'') AS Section
    FROM PO_PRH h
    LEFT JOIN IN_DEP d
        ON  d.DEPCODE = h.depcode
        AND d.divcode = h.divcode
    WHERE h.divcode = @DivCode
      AND h.depcode = @Dep
      AND ISNULL(h.cancelflag, 'N') <> 'Y'
      AND EXISTS (
            SELECT 1
            FROM   PO_PRL l
            WHERE  l.divcode   = h.divcode
              AND  l.prno      = h.prno
              AND  l.prdate    = h.prdate
              AND  l.FirstApp  IS NULL
              AND  l.SecondApp IS NULL
              AND  l.ThirdApp  IS NULL
              AND  l.DirectApp IS NULL
              AND  ISNULL(l.FClosed, 'N') <> 'Y'
          )
    ORDER BY h.prdate DESC, h.prno DESC;
END;

GO

-- ksp_PR_GetFirstApprovedForDeletion
CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovedForDeletion
    @DivCode VARCHAR(2)
AS
BEGIN
    SET NOCOUNT ON;

    -- No year guard — no @yfdate / @yldate parameters (confirmed FSD OI-02 closed)
    --
    -- Used for both Delete-Approval listing AND Find (re-uses same result set).
    --
    -- Eligible PR = header not cancelled + at least one line where:
    --   FirstApp IS NOT NULL (first level done) AND DirectApp IS NULL (not final-level)
    -- cancelflag on PO_PRH; FClosed on PO_PRL — both checked correctly.

    SELECT DISTINCT
        h.prno              AS PrNo,
        h.prdate            AS PrDate,
        h.depcode           AS DepCode,
        ISNULL(d.DEPNAME, h.depcode) AS DepName,
        ISNULL(h.refno, '') AS RefNo,
        ISNULL(h.SECTION,'') AS Section
    FROM PO_PRH h
    LEFT JOIN IN_DEP d
        ON  d.DEPCODE = h.depcode
        AND d.divcode = h.divcode
    WHERE h.divcode = @DivCode
      AND ISNULL(h.cancelflag, 'N') <> 'Y'
      AND EXISTS (
            SELECT 1
            FROM   PO_PRL l
            WHERE  l.divcode   = h.divcode
              AND  l.prno      = h.prno
              AND  l.prdate    = h.prdate
              AND  l.FirstApp  IS NOT NULL
              AND  l.DirectApp IS NULL
              AND  ISNULL(l.FClosed, 'N') <> 'Y'
          )
    ORDER BY h.prdate DESC, h.prno DESC;
END;

GO
