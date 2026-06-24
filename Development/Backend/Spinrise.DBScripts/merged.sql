-- ============================================================
-- Spinrise ERP V2 â€” Merged Stored Procedures
-- Database: JAT
-- Deploy: Execute this entire file in SSMS against JAT
-- Rule: NEVER run individual SP files in production â€” use this file
-- NOTE: ksp_PR_Save uses OPENJSON â€” requires compat level >= 130.
--       Run first if needed: ALTER DATABASE JAT SET COMPATIBILITY_LEVEL = 130;
-- ============================================================

-- ksp_GetDatabases (master — lists all user databases for login screen)
USE master;
GO

CREATE OR ALTER PROCEDURE dbo.ksp_GetDatabases
AS
BEGIN
    SET NOCOUNT ON;

    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master','tempdb','msdb','model','ReportServer','ReportServerTempDB','pubs','Northwind')
    ORDER BY name;
END
GO

USE JAT;
GO

-- Ensure OPENJSON is available (required by ksp_PR_Save)
ALTER DATABASE JAT SET COMPATIBILITY_LEVEL = 130;
GO


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

    -- A user can have multiple PP_PASSWD rows (one per module).
    -- TOP 1 anchors divcode/user_id/alevel; the subquery aggregates ALL active modules.
    SELECT TOP 1
        p.divcode                            AS DivCode,
        p.user_id                            AS UserId,
        p.user_name                          AS UserName,
        p.alevel                             AS ALevel,
        ISNULL(
            STUFF(
                (SELECT ',' + CAST(p2.module AS VARCHAR(10))
                 FROM   dbo.PP_PASSWD p2
                 WHERE  p2.user_id  = p.user_id
                   AND  p2.divcode  = p.divcode
                   AND  UPPER(ISNULL(p2.activeflg, 'N')) = 'Y'
                 ORDER BY p2.module
                 FOR XML PATH('')),
                1, 1, ''),
            '')                              AS Modules,
        RTRIM(ISNULL(d.DIVNAME, ''))         AS DivName
    FROM   dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE  p.divcode   = @DivCode
      AND  p.user_name = @UserName
      AND  dbo.DecryptString(p.password) = @Password
      AND  UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
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

    SELECT TOP 1
        p.divcode                        AS DivCode,
        p.user_id                        AS UserId,
        p.user_name                      AS UserName,
        p.alevel                         AS ALevel,
        ISNULL(
            STUFF(
                (SELECT ',' + CAST(p2.module AS VARCHAR(10))
                 FROM   dbo.PP_PASSWD p2
                 WHERE  p2.user_id  = p.user_id
                   AND  p2.divcode  = p.divcode
                   AND  UPPER(ISNULL(p2.activeflg, 'N')) = 'Y'
                 ORDER BY p2.module
                 FOR XML PATH('')),
                1, 1, ''),
            '')                          AS Modules,
        RTRIM(ISNULL(d.DIVNAME, ''))     AS DivName
    FROM   dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE  p.user_id  = @UserId
      AND  p.divcode  = @DivCode
      AND  UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
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
-- CurrentStock formula (ported from VB6 stkchk1):
--   Opening balance from IN_IDET (YEARMONTH = YYYYoo, TC = 0)
--   + FY receipts up to @PDate from IN_TRNTAIL (TCTYPE 1/3/5/7/9/12)
--   - FY issues  up to @PDate from IN_TRNTAIL (TCTYPE 2/4/6/8/11)
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
    -- oym: opening year-month key — e.g. FY start 01-Apr-2025 → '202500'
    DECLARE @OYM          VARCHAR(6)     = CAST(YEAR(@FDate) AS VARCHAR(4)) + '00';
    DECLARE @CurrentStock NUMERIC(12,3)  = 0;

    SELECT @CurrentStock = ISNULL(SUM(ALLREC) - SUM(ALLISS), 0)
    FROM (
        -- 1. Opening balance: IN_IDET opening record (TC = 0)
        SELECT ISNULL(SUM(QUANTITY), 0)   AS ALLREC,
               CAST(0 AS NUMERIC(12,3))   AS ALLISS
        FROM   dbo.IN_IDET
        WHERE  DIVCODE   = @DivCode
          AND  ITEMCODE  = @ItemCode
          AND  YEARMONTH = @OYM
          AND  TC        = 0

        UNION ALL

        -- 2. FY receipts up to @PDate (TCTYPE = 1,3,5,7,9,12)
        SELECT ISNULL(SUM(A.QUANTITY), 0) AS ALLREC,
               CAST(0 AS NUMERIC(12,3))   AS ALLISS
        FROM   dbo.IN_TRNTAIL A
        INNER JOIN dbo.IN_TC  T ON T.TC = A.TC
        WHERE  A.DIVCODE  = @DivCode
          AND  A.ITEMCODE = @ItemCode
          AND  T.TCTYPE   IN (1, 3, 5, 7, 9, 12)
          AND  A.DOCDT   >= @FDate
          AND  A.DOCDT   <= @PDate

        UNION ALL

        -- 3. FY issues up to @PDate (TCTYPE = 2,4,6,8,11)
        SELECT CAST(0 AS NUMERIC(12,3))          AS ALLREC,
               ISNULL(SUM(ABS(A.QUANTITY)), 0)   AS ALLISS
        FROM   dbo.IN_TRNTAIL A
        INNER JOIN dbo.IN_TC  T ON T.TC = A.TC
        WHERE  A.DIVCODE  = @DivCode
          AND  A.ITEMCODE = @ItemCode
          AND  T.TCTYPE   IN (2, 4, 6, 8, 11)
          AND  A.DOCDT   >= @FDate
          AND  A.DOCDT   <= @PDate
    ) S;

    DECLARE @LpoRate NUMERIC(13,4) = NULL;
    DECLARE @LpoDate DATE          = NULL;
    SELECT TOP 1
        @LpoRate = pl.RATE,
        @LpoDate = CAST(ph.porddt AS DATE)
    FROM dbo.PO_ORDL pl
    INNER JOIN dbo.PO_ORDH ph
        ON  ph.divcode = pl.divcode
        AND ph.pordno  = pl.pordno
        AND ph.porddt  = pl.porddt
    WHERE pl.itemcode = @ItemCode
      AND pl.divcode  = @DivCode
      AND ISNULL(ph.CANFLG, 'N') = 'N'
    ORDER BY ph.porddt DESC;

    SELECT
        @CurrentStock                    AS CurrentStock,
        CAST(@LpoRate  AS NUMERIC(13,4)) AS LpoRate,
        CAST(@LpoDate  AS DATE)          AS LpoDate,
        CAST(NULL      AS NUMERIC(13,4)) AS AvgRate;
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
            NULL AS PoGrp,   NULL AS AppFlg,
            NULL AS CancelFlag, NULL AS CancelReason, NULL AS AmendNo,
            NULL AS PrStatus,
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
        ISNULL(h.cancelflag, '')                                AS CancelFlag,
        RTRIM(ISNULL(h.CANREASON, ''))                          AS CancelReason,
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
        RTRIM(ISNULL(h.CANREASON, ''))                          AS CancelReason,
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
    @PageNumber    INT          = 1,
    @PageSize      INT          = 50,
    @Search        VARCHAR(100) = NULL   -- free-text: matches prno, dept name, employee name
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
            WHEN ISNULL(h.APPFLG, 'N') = 'Y'
                AND EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.FirstApp='Y')
                THEN 'FIRST LEVEL APPROVED'
            WHEN EXISTS(SELECT 1 FROM dbo.PO_PRL lx WHERE lx.divcode=h.divcode AND lx.prno=h.prno AND lx.prdate=h.prdate AND lx.FirstApp='Y')
                THEN 'PARTIALLY APPROVED'
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
      AND (@Search   IS NULL OR
           CAST(h.prno AS VARCHAR(20)) LIKE '%' + @Search + '%' OR
           d.depname                   LIKE '%' + @Search + '%' OR
           EXISTS (SELECT 1 FROM dbo.PR_EMP e3
                   WHERE CAST(e3.empno AS VARCHAR(10)) = h.REQNAME
                     AND e3.ename LIKE '%' + @Search + '%'))
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

        -- ── 0a. FY Guard ──────────────────────────────────────────────────────
        --    CR-PR-05: PR Date must fall within the currently open financial year.
        --    @FDate / @LDate are the open-FY bounds supplied by the caller.
        --    Guard applies to ADD only — MODIFY locks @PrDate to the stored date.
        IF @Mode = 'ADD' AND (@PrDate < @FDate OR @PrDate > @LDate)
            RAISERROR('PR Date is outside the open financial year. Please select a date within the current financial year.', 16, 1);

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
        RTRIM(ISNULL(fau.user_name, ISNULL(l.FirstappUser, '')))  AS FirstAppUser,
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
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(l.FirstappUser)
                   AND RTRIM(divcode) = RTRIM(h.divcode))                 fau
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

-- PO_PRINT_LOG: audit trail for amendment print events (FSD §6 DB Migration)
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = 'PO_PRINT_LOG' AND type = 'U')
BEGIN
    CREATE TABLE dbo.PO_PRINT_LOG (
        id           INT IDENTITY(1,1)  PRIMARY KEY,
        divcode      VARCHAR(10)        NOT NULL,
        prno         NUMERIC(6,0)       NOT NULL,
        amendno      INT                NOT NULL,
        amenddate    DATE               NOT NULL,
        printed_by   VARCHAR(50)        NOT NULL,
        printed_on   DATETIME           NOT NULL DEFAULT GETDATE(),
        reprint_flag CHAR(1)            NOT NULL DEFAULT 'N'
    );
END
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
    ORDER BY a.amendno ASC
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
-- FSD: M01 PR Amendment Entry v2.3 / CR-M01-AM-001
-- BR-AMD-03: PR eligibility guard added (02-Jun-2026)
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
                            AND p.itemcode             = l.itemcode
    LEFT JOIN dbo.MM_MACMAS m  ON m.MAC_NO  = l.macno AND m.DIVCODE = l.divcode AND m.DEPCODE = ah.depcode
    LEFT JOIN dbo.IN_CC     cc ON cc.cccode = l.CCCODE AND cc.divcode = l.divcode
    WHERE  l.divcode              = @DivCode
      AND  l.prno                 = @PrNo
      AND  CAST(l.prdate AS DATE) = @PrDate
      AND  l.amendno              = @AmendNo
    ORDER BY l.amendslno;
END;
GO

-- ============================================================
-- ksp_PR_GetAmendmentPrint.sql
-- ============================================================

-- ============================================================
-- ksp_PR_GetAmendmentPrint
-- Returns 2 result sets for QuestPDF report generation:
--   #1 — Amendment header + PP_DIVMAS letterhead data
--   #2 — Amendment lines with item / machine / rate data
-- PO_PRH is deleted after the first amendment — LEFT JOIN used;
-- header fields fall back to PO_APRH columns stored on ADD.
-- FSD: M01 PR Amendment Entry v2.3
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
    @AmendNo    INT,
    @UserId     VARCHAR(50) = NULL
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
    -- PO_APRH anchored to @AmendNo for depcode; do not join on l.amendno
    -- (PO_APRL has no amendno in PK — newer amendments overwrite existing rows)
    JOIN   dbo.PO_APRH ah   ON  ah.divcode              = @DivCode
                            AND ah.prno                 = @PrNo
                            AND CAST(ah.prdate AS DATE) = @PrDate
                            AND ah.amendno              = @AmendNo
    JOIN   dbo.IN_ITEM i    ON  i.itemcode  = l.itemcode
    LEFT JOIN dbo.PO_PRL p  ON  p.divcode              = l.divcode
                            AND p.prno                 = l.prno
                            AND CAST(p.prdate AS DATE) = CAST(l.prdate AS DATE)
                            AND p.itemcode             = l.itemcode
    WHERE  l.divcode              = @DivCode
      AND  l.prno                 = @PrNo
      AND  CAST(l.prdate AS DATE) = @PrDate
      AND  l.amendno              = @AmendNo
    ORDER BY l.amendslno;

    -- Log print event to PO_PRINT_LOG (FSD §4 BR — all prints logged; reprint_flag='Y' if not first print)
    IF OBJECT_ID('dbo.PO_PRINT_LOG', 'U') IS NOT NULL AND @UserId IS NOT NULL
    BEGIN
        DECLARE @ReprintFlag CHAR(1) = 'N';
        IF EXISTS (
            SELECT 1 FROM dbo.PO_PRINT_LOG
            WHERE divcode = @DivCode AND prno = @PrNo AND amendno = @AmendNo
        )
            SET @ReprintFlag = 'Y';

        INSERT INTO dbo.PO_PRINT_LOG (divcode, prno, amendno, amenddate, printed_by, printed_on, reprint_flag)
        SELECT @DivCode, @PrNo, @AmendNo, CAST(a.amenddate AS DATE), @UserId, GETDATE(), @ReprintFlag
        FROM   dbo.PO_APRH a
        WHERE  a.divcode              = @DivCode
          AND  a.prno                 = @PrNo
          AND  CAST(a.prdate AS DATE) = @PrDate
          AND  a.amendno              = @AmendNo;
    END
END;
GO

-- ============================================================
-- ksp_PR_SaveAmendment.sql
-- ============================================================

-- ============================================================
-- ksp_PR_SaveAmendment
-- FSD: M01 PR Amendment Entry v2.3  §4 Save Sequence
-- CR:  CR-M01-AM-001 — QA/CEO approved 31-May-2026 (T. Mani)
--
-- ADD: INSERT PO_APRH + PO_APRL snapshot (append-only history);
--      UPDATE PO_PRH header fields;
--      delta-update PO_PRL — PATH A (UPDATE) / PATH B (INSERT) / PATH C (DELETE)
--
-- Business rules enforced:
--   BR-AMD-01: AmendDate must equal @PDate (processing date)
--   BR-AMD-03: PR eligibility checked in ksp_PR_GetAmendmentForNew
--   BR-AMD-04: Duplicate item codes rejected
--   Required Date >= pdate
--   Qty < approved qty rejected
--   PATH C: guard PRSTATUS NOT IN ('O','E','C','Z','X')
--   PATH A: row_version concurrency per line; approval flags preserved
--   PATH B: MAX(prsno)+1 with UPDLOCK
--   NF-01: zero submitted lines rejected
--   amdflg = 'Y' set on PO_APRL snapshot lines and PATH B new PO_PRL inserts (new items added). PATH A existing line updates do not set amdflg — CEO direction 08-Jun-2026.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_SaveAmendment]
    @Mode               VARCHAR(15),        -- 'ADD'
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
    @PDate              DATE,               -- processing date; enforces BR-AMD-01
    @AmendNo            INT             = NULL,
    @RowVersion         VARBINARY(8)    = NULL,
    @LinesJson          NVARCHAR(MAX)   = NULL,
    @IType              CHAR(1)         = NULL, -- editable PR Type; overrides PO_PRH snapshot
    @Result             INT             = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. FY Guard ──────────────────────────────────────────────────────
        IF @AmendDate < @FDate OR @AmendDate > @LDate
            RAISERROR('Amendment Date is outside the open financial year.', 16, 1);

        -- ── 2. BR-AMD-01: Amendment Date must equal processing date ──────────
        IF @AmendDate <> @PDate
            RAISERROR('Amendment Date must equal the current processing date.', 16, 1);

        -- ── 3. BR-AMD-04: Duplicate item codes ───────────────────────────────
        IF @LinesJson IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM OPENJSON(@LinesJson)
                WITH (ItemCode VARCHAR(10) '$.ItemCode')
                WHERE RTRIM(ISNULL(ItemCode, '')) <> ''
                GROUP BY ItemCode
                HAVING COUNT(*) > 1
            )
                RAISERROR('Duplicate item codes found. Each item may appear only once in an amendment.', 16, 1);
        END

        -- ── 4. Validate RATE_JUSTIFICATION when RATE_SOURCE = MANUAL ─────────
        IF @LinesJson IS NOT NULL
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

        -- ── 5. Generate amendment number ──────────────────────────────────────
        DECLARE @ResolvedAmendNo INT;

        EXEC usp_GetNextAmendNo
            @DivCode  = @DivCode,
            @FDate    = @FDate,
            @LDate    = @LDate,
            @NewDocNo = @ResolvedAmendNo OUTPUT;

        IF @ResolvedAmendNo = -1
            RAISERROR('Could not generate amendment number. Check PO_DOC_PARA configuration.', 16, 1);

        -- ── 6. Capture current header fields from PO_PRH ──────────────────────
        DECLARE @DepCode    VARCHAR(3);
        DECLARE @ReqName    VARCHAR(25);
        DECLARE @Section    VARCHAR(20);
        DECLARE @PlaceOfIss VARCHAR(30);

        IF EXISTS (
            SELECT 1 FROM dbo.PO_PRH
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
        )
        BEGIN
            DECLARE @CapturedIType CHAR(1);
            SELECT @DepCode = depcode, @ReqName = REQNAME,
                   @Section = SECTION, @CapturedIType = ITYPE, @PlaceOfIss = PLACEOFISS
            FROM   dbo.PO_PRH
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate;
            SET @IType = ISNULL(@IType, @CapturedIType);
        END
        ELSE
        BEGIN
            -- Legacy fallback: PO_PRH absent — read from latest PO_APRH
            DECLARE @CapturedIType2 CHAR(1);
            SELECT TOP 1
                   @DepCode = depcode, @ReqName = REQNAME,
                   @Section = SECTION, @CapturedIType2 = ITYPE, @PlaceOfIss = PLACEOFISS
            FROM   dbo.PO_APRH
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
            ORDER BY amendno DESC;
            SET @IType = ISNULL(@IType, @CapturedIType2);
        END

        -- ── 7. Insert amendment header snapshot ───────────────────────────────
        DECLARE @CreatedDt VARCHAR(25) =
            CONVERT(VARCHAR(10), GETDATE(), 103) + ' ' +
            CONVERT(VARCHAR(8),  GETDATE(), 108);

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

        -- ── 8. Append amendment lines snapshot ────────────────────────────────
        -- PO_APRL is an append-only history log (FSD §4 Architecture Note).
        -- prsno  = MAX(PO_APRL.prsno) + ROW_NUMBER() — globally sequential per PR.
        -- amendslno = ROW_NUMBER() — line position within this amendment (1, 2, 3...).

        DECLARE @MaxAprlSno INT;
        SELECT @MaxAprlSno = ISNULL(MAX(prsno), 0)
        FROM   dbo.PO_APRL WITH (UPDLOCK)
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate;

        INSERT INTO dbo.PO_APRL
            (divcode, prno, prdate, amendno, amenddate, prsno, amendslno,
             itemcode, macno, qtyind, reqddate, RATE,
             RATE_SOURCE, RATE_JUSTIFICATION,
             curstock, CCCODE, CATCODE, BGRPCODE,
             PLACE, APPCOST, remarks, amdflg)
        SELECT
            @DivCode, @PrNo, @PrDate, @ResolvedAmendNo, @AmendDate,
            @MaxAprlSno + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            RTRIM(j.ItemCode),
            NULLIF(RTRIM(ISNULL(j.MacNo, '')), ''),
            j.QtyInd,
            TRY_CONVERT(DATE, NULLIF(j.ReqdDate, '')),
            j.Rate,
            ISNULL(NULLIF(RTRIM(j.RateSource), ''), 'ORIGINAL'),
            NULLIF(RTRIM(ISNULL(j.RateJustification, '')), ''),
            ISNULL(j.CurStock, 0),
            NULLIF(j.CcCode, 0),
            NULLIF(RTRIM(ISNULL(j.CatCode, '')), ''),
            NULLIF(RTRIM(ISNULL(j.BgrpCode, '')), ''),
            NULLIF(RTRIM(ISNULL(j.Place, '')), ''),
            NULLIF(j.AppCost, 0),
            NULLIF(UPPER(LEFT(RTRIM(ISNULL(j.Remarks, '')), 50)), ''),
            'Y'
        FROM OPENJSON(@LinesJson)
        WITH (
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
        WHERE  RTRIM(ISNULL(j.ItemCode, '')) <> '';

        -- ── 9. Delta-update PO_PRH and PO_PRL (CR-M01-AM-001) ────────────────
        IF EXISTS (SELECT 1 FROM dbo.PO_PRH WHERE divcode=@DivCode AND prno=@PrNo AND CAST(prdate AS DATE)=@PrDate)
        BEGIN
            UPDATE dbo.PO_PRH
            SET    refno   = NULLIF(RTRIM(ISNULL(@RefNo, '')), ''),
                   ITYPE   = ISNULL(@IType, ITYPE),
                   depcode = @DepCode,
                   SECTION = @Section,
                   REQNAME = @ReqName
            WHERE  divcode=@DivCode AND prno=@PrNo AND CAST(prdate AS DATE)=@PrDate;
        END

        -- Parse submitted lines into work table (includes RowVersion for PATH A)
        DECLARE @LineWork TABLE (
            PrSno             INT,
            ItemCode          VARCHAR(10),
            MacNo             VARCHAR(5),
            QtyInd            NUMERIC(12,3),
            ReqdDate          VARCHAR(10),
            Rate              NUMERIC(13,4),
            RateSource        VARCHAR(20),
            RateJustification VARCHAR(200),
            CurStock          NUMERIC(12,3),
            CcCode            NUMERIC(4,0),
            CatCode           VARCHAR(1),
            BgrpCode          VARCHAR(4),
            Place             VARCHAR(40),
            AppCost           NUMERIC(11,2),
            Remarks           VARCHAR(50),
            RowVersion        VARBINARY(8)
        );

        INSERT INTO @LineWork
        SELECT
            j.PrSno,
            RTRIM(j.ItemCode),
            NULLIF(RTRIM(ISNULL(j.MacNo, '')), ''),
            j.QtyInd,
            j.ReqdDate,
            j.Rate,
            ISNULL(NULLIF(RTRIM(j.RateSource), ''), 'ORIGINAL'),
            NULLIF(RTRIM(ISNULL(j.RateJustification, '')), ''),
            ISNULL(j.CurStock, 0),
            NULLIF(j.CcCode, 0),
            NULLIF(RTRIM(ISNULL(j.CatCode, '')), ''),
            NULLIF(RTRIM(ISNULL(j.BgrpCode, '')), ''),
            NULLIF(RTRIM(ISNULL(j.Place, '')), ''),
            NULLIF(j.AppCost, 0),
            NULLIF(UPPER(LEFT(RTRIM(ISNULL(j.Remarks, '')), 50)), ''),
            TRY_CONVERT(VARBINARY(8), j.RowVersion, 1)
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
            Remarks            VARCHAR(50)     '$.Remarks',
            RowVersion         VARCHAR(20)     '$.RowVersion'
        ) j
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

        -- Required Date >= pdate
        IF EXISTS (
            SELECT 1 FROM @LineWork
            WHERE  ReqdDate IS NOT NULL
              AND  TRY_CONVERT(DATE, NULLIF(ReqdDate, '')) < @PrDate
        )
            RAISERROR('Required Date cannot be earlier than the PR date.', 16, 1);

        -- Qty cannot go below already-approved quantity
        IF EXISTS (
            SELECT 1 FROM @LineWork lw
            INNER JOIN dbo.PO_PRL p
                ON  p.divcode              = @DivCode
                AND p.prno                 = @PrNo
                AND CAST(p.prdate AS DATE) = @PrDate
                AND p.prsno                = lw.PrSno
            WHERE lw.QtyInd < ISNULL(p.qtyreqd, 0)
        )
            RAISERROR('Amended quantity cannot be less than the already-approved quantity.', 16, 1);

        -- PATH C guard: block if any removed line has a protected status
        IF EXISTS (
            SELECT 1 FROM dbo.PO_PRL p
            WHERE  p.divcode              = @DivCode
              AND  p.prno                 = @PrNo
              AND  CAST(p.prdate AS DATE) = @PrDate
              AND  p.prsno NOT IN (SELECT PrSno FROM @LineWork)
              AND  ISNULL(p.prstatus, '') IN ('O', 'E', 'C', 'Z', 'X')
        )
        BEGIN
            DECLARE @BlockedSno  INT;
            DECLARE @BlockedStat CHAR(1);
            SELECT TOP 1
                @BlockedSno  = p.prsno,
                @BlockedStat = p.prstatus
            FROM dbo.PO_PRL p
            WHERE  p.divcode              = @DivCode
              AND  p.prno                 = @PrNo
              AND  CAST(p.prdate AS DATE) = @PrDate
              AND  p.prsno NOT IN (SELECT PrSno FROM @LineWork)
              AND  ISNULL(p.prstatus, '') IN ('O', 'E', 'C', 'Z', 'X');
            RAISERROR('Line %d cannot be deleted — status ''%s'' is beyond amendment scope.', 16, 1, @BlockedSno, @BlockedStat);
        END

        -- NF-01: Guard — zero submitted lines would wipe all PO_PRL rows
        IF (SELECT COUNT(*) FROM @LineWork) = 0
            RAISERROR('At least one line must be submitted in an amendment.', 16, 1);

        -- PATH C: DELETE lines removed by the user
        DELETE FROM dbo.PO_PRL
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate
          AND  prsno NOT IN (SELECT PrSno FROM @LineWork);

        -- PATH A: UPDATE existing lines (approval flags preserved, rowversion enforced)
        DECLARE @PathAExpected INT;
        SELECT @PathAExpected = COUNT(*)
        FROM @LineWork lw
        INNER JOIN dbo.PO_PRL p
            ON  p.divcode              = @DivCode
            AND p.prno                 = @PrNo
            AND CAST(p.prdate AS DATE) = @PrDate
            AND p.prsno                = lw.PrSno;

        UPDATE p
        SET    p.qtyind   = lw.QtyInd,
               p.RATE     = lw.Rate,
               p.reqddate = TRY_CONVERT(DATE, NULLIF(lw.ReqdDate, '')),
               p.APPCOST  = lw.AppCost,
               p.remarks  = lw.Remarks,
               p.macno    = lw.MacNo,
               p.PLACE    = lw.Place,
               p.CCCODE   = lw.CcCode
               -- FirstApp, SecondApp, ThirdApp, PRSTATUS, DirectApp preserved
        FROM   dbo.PO_PRL p
        INNER JOIN @LineWork lw
            ON  p.divcode              = @DivCode
            AND p.prno                 = @PrNo
            AND CAST(p.prdate AS DATE) = @PrDate
            AND p.prsno                = lw.PrSno
            AND p.row_version          = lw.RowVersion;

        IF @@ROWCOUNT <> @PathAExpected
            RAISERROR('One or more lines were modified by another user. Please reload and try again.', 16, 1);

        -- PATH B: INSERT new lines (prsno not yet in PO_PRL)
        DECLARE @MaxPrSno INT;
        SELECT @MaxPrSno = ISNULL(MAX(prsno), 0)
        FROM   dbo.PO_PRL WITH (UPDLOCK)
        WHERE  divcode              = @DivCode
          AND  prno                 = @PrNo
          AND  CAST(prdate AS DATE) = @PrDate;

        INSERT INTO dbo.PO_PRL
            (divcode, prno, prdate, prsno,
             itemcode, macno, qtyind, reqddate, RATE,
             CCCODE, CATCODE, BGRPCODE, PLACE, APPCOST, remarks,
             amdflg, Depcode,
             FirstApp, SecondApp, ThirdApp, prstatus, DirectApp)
        SELECT
            @DivCode, @PrNo, @PrDate,
            @MaxPrSno + ROW_NUMBER() OVER (ORDER BY lw.PrSno),
            lw.ItemCode, lw.MacNo, lw.QtyInd,
            TRY_CONVERT(DATE, NULLIF(lw.ReqdDate, '')),
            lw.Rate, lw.CcCode, lw.CatCode, lw.BgrpCode,
            lw.Place, lw.AppCost, lw.Remarks,
            'Y', @DepCode,
            NULL, NULL, NULL, NULL, NULL
        FROM @LineWork lw
        WHERE lw.PrSno NOT IN (
            SELECT prsno FROM dbo.PO_PRL
            WHERE  divcode = @DivCode AND prno = @PrNo AND CAST(prdate AS DATE) = @PrDate
        );

        -- ── 10. Audit log ──────────────────────────────────────────────────────
        INSERT INTO dbo.LogDet_po
            (divcode, prno, prdate, prsno, itemcode, macno, quantity, RATE,
             Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
             Trans_UserId, Trans_date, moduleNo, reqname, createdby)
        SELECT
            @DivCode, @PrNo, @PrDate, l.prsno, l.itemcode, l.macno,
            CAST(l.qtyind AS NUMERIC(15,0)), l.RATE,
            'PR Amendment', 'ADD', @HostName, @IpAddress,
            @UserId, GETDATE(), 4, '', @UserId
        FROM dbo.PO_APRL l
        WHERE  l.divcode              = @DivCode
          AND  l.prno                 = @PrNo
          AND  CAST(l.prdate AS DATE) = @PrDate
          AND  l.amendno              = @ResolvedAmendNo;

        SET @Result = 0;
        COMMIT TRANSACTION;
        SELECT @ResolvedAmendNo AS AmendNo;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Result = CASE WHEN ERROR_SEVERITY() = 16 THEN 1 ELSE -1 END;
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
            RTRIM(ISNULL(e.DESCRIPTION, ISNULL(e.MAC_NO, ''))) AS SccName,
            -- Approval status: check higher-level flags first, then fall back to PRSTATUS char
            CASE
                WHEN ISNULL(b.DirectApp, 'N') = 'Y'          THEN 'Final Approved'
                WHEN ISNULL(b.ThirdApp,  'N') = 'Y'          THEN 'Third Approved'
                WHEN ISNULL(b.SecondApp, 'N') = 'Y'          THEN 'Second Approved'
                WHEN RTRIM(ISNULL(b.PRSTATUS, '')) = 'F'     THEN 'First Approved'
                WHEN RTRIM(ISNULL(b.PRSTATUS, '')) = 'E'     THEN 'Enquired'
                WHEN RTRIM(ISNULL(b.PRSTATUS, '')) = 'C'     THEN 'Received'
                WHEN RTRIM(ISNULL(b.PRSTATUS, '')) = 'X'     THEN 'Cancelled'
                WHEN RTRIM(ISNULL(b.PRSTATUS, '')) = 'Z'     THEN 'Force Closed'
                WHEN RTRIM(ISNULL(b.PRSTATUS, '')) = 'O'     THEN
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
          AND RTRIM(ISNULL(b.prstatus, '')) NOT IN ('O','E','C','Z','X')   -- FC-EX-09/BR-03: exclude Ordered/Enquired/Received/ForceClosed/Cancelled
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
            ISNULL(a.pre_cancel_status, '')        AS PrevStatus,
            a.row_version                          AS RowVersion,
            RTRIM(ISNULL(a.CANREASON, ''))         AS CancelReason
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
--      (BR-UNDO-01 -- read BEFORE the transaction begins)
--   2. Clears all cancel columns on the header
--      (SP-I1: row_version guard -- RAISERROR on conflict)
--   3. Restores PO_PRL PRSTATUS to NULL (BR-UNDO-01 Sprint 1)
--      Cancellation is only permitted pre-First Level approval
--      where PRSTATUS is always NULL. Undo therefore always
--      restores NULL. pre_cancel_status restore logic is
--      retained for Sprint 2 use -- PO_PRH.pre_cancel_status
--      column is preserved but not consumed in Sprint 1.
--   4. Writes audit log entry (Trans_Mod='DELETE')
--
-- SP-I2 DESIGN NOTE -- depcode Asymmetry (Intentional)
--   PO_PRH UPDATE: WHERE includes AND depcode = @DepCode
--   PO_PRL UPDATE: depcode is NOT in the WHERE clause
--   Reason: PO_PRL lines do not store depcode as a filter key.
--   All lines under the same divcode+prno+prdate belong to one
--   PR regardless of depcode. Filtering PO_PRL by depcode would
--   silently skip lines. This asymmetry is intentional design --
--   do NOT add depcode to the PO_PRL WHERE clause.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_UndoCancellation
(
    @DivCode    VARCHAR(2),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE,
    @DepCode    VARCHAR(3),
    @RowVersion BINARY(8),
    @UserId     VARCHAR(50),
    @HostName   VARCHAR(100) = NULL,
    @IpAddress  VARCHAR(50)  = NULL
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
        WHERE  divcode     = @DivCode
          AND  prno        = @PrNo
          AND  prdate      = @PrDate
          AND  depcode     = @DepCode
          AND  row_version = @RowVersion;   -- SP-I1: concurrency guard

        IF @@ROWCOUNT = 0
            RAISERROR('Concurrent update conflict — record has changed. Please refresh and retry.', 16, 1);

        -- Step 2: Restore PR lines to pre-cancel status (BR-UNDO-01)
        UPDATE PO_PRL
        SET    PRSTATUS = CASE WHEN @PreStatus = '' THEN NULL ELSE @PreStatus END
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate;

        -- Step 3: Audit log -- Trans_Mod='DELETE' for undo
        INSERT INTO LogDet_PO
            (divcode, prno, prdate, depcode,
             username, Trans_date, Trans_UserId,
             Trans_Name, Trans_Mod,
             Trans_IPADD, Trans_Host)
        VALUES
            (@DivCode, @PrNo, @PrDate, @DepCode,
             @UserId, GETDATE(), @UserId,
             'Purchase Requisition Undo Cancellation', 'DELETE',
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
      AND  prstatus NOT IN ('O','E','C','Z','X');   -- FC-EX-09/BR-03: never force-close Ordered/Enquired/Received/ForceClosed/Cancelled lines

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
        AppUserLabel3   AS AppUserLabel3,
        -- Financial year bounds computed server-side (April–March)
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()),     4, 1) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()) - 1, 4, 1) AS DATETIME)
        END AS YFDate,
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()) + 1, 3, 31) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()),     3, 31) AS DATETIME)
        END AS YLDate
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
    DECLARE @YFDate DATETIME =
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()),     4, 1) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()) - 1, 4, 1) AS DATETIME) END;

    DECLARE @YLDate DATETIME =
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()) + 1, 3, 31) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()),     3, 31) AS DATETIME) END;

    SELECT DISTINCT
        d.DEPCODE AS DepCode,
        d.DEPNAME AS DepName,
        (
            SELECT COUNT(DISTINCT h.prno)
            FROM   PO_PRH h
            WHERE  h.divcode = @DivCode
              AND  h.depcode = d.DEPCODE
              AND  h.prdate BETWEEN @YFDate AND @YLDate
              AND  ISNULL(h.cancelflag, 'N') <> 'Y'
              AND  EXISTS (
                       SELECT 1 FROM PO_PRL l
                       WHERE  l.divcode   = h.divcode
                         AND  l.prno      = h.prno
                         AND  l.prdate    = h.prdate
                         AND  l.FirstApp  IS NULL
                         AND  l.SecondApp IS NULL
                         AND  l.ThirdApp  IS NULL
                         AND  l.DirectApp IS NULL
                         AND  ISNULL(l.FClosed, 'N') <> 'Y'
                   )
        ) AS PendingCount
    FROM PO_IndentAppUser u
    INNER JOIN IN_DEP d
        ON  d.DEPCODE = u.Depcode
        AND d.divcode = u.Divcode
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

    SELECT
        h.divcode                                   AS DivCode,
        h.prno                                      AS PrNo,
        h.prdate                                    AS PrDate,
        h.depcode                                   AS DepCode,
        ISNULL(d.DEPNAME, '')                       AS DepName,
        h.refno                                     AS RefNo,
        h.SECTION                                   AS Section,
        CAST(h.SubCost AS VARCHAR(20))              AS SubCost,
        s.SCCNAME                                   AS SccName,
        h.APP1                                      AS App1,
        h.APP2                                      AS App2,
        h.APP3                                      AS App3,
        h.APPFLG                                    AS AppFlg,
        CAST(h.APP1DATE AS DATETIME)                AS App1Date,
        ISNULL(e.ename, h.REQNAME)                  AS ReqName
    FROM PO_PRH h
    LEFT JOIN IN_DEP  d ON d.DEPCODE = h.depcode
                       AND d.divcode = h.divcode
    LEFT JOIN IN_SCC  s ON s.SCCCODE = h.SubCost
                       AND s.Divcode = h.divcode
                       AND s.DEPCODE = h.depcode
    LEFT JOIN PR_EMP  e ON TRY_CAST(h.REQNAME AS DECIMAL(5,0)) = e.empno
                       AND e.divcode = h.divcode
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

        -- ── 1. Parse JSON lines ──────────────────────────────────────────────
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

        -- ── DEF-FA-01: server-side qty guard ─────────────────────────────────
        IF EXISTS (SELECT 1 FROM @Lines WHERE FirstAppQty > QtyReqd)
        BEGIN
            RAISERROR('First Approval Quantity exceeds Quantity Required on one or more lines.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- ── FA-ADD-09: reject zero or negative FirstAppQty ────────────────────
        IF EXISTS (SELECT 1 FROM @Lines WHERE FirstAppQty <= 0)
        BEGIN
            RAISERROR('First Approval Quantity must be greater than zero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- ── 2. Update PO_PRL lines ───────────────────────────────────────────
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

        -- ── 3. Update PO_PRH header — DEF-FA-03: only when ALL lines approved ─
        -- PO_PRH has NO PRSTATUS column. APPFLG tracks overall header approval.
        -- Only promote header to APPFLG='Y' when every PO_PRL line now has FirstApp='Y'.
        UPDATE PO_PRH
        SET APPFLG   = 'Y',
            APP1     = @UserId,
            APP1DATE = @AppDate,
            APP1TIME = GETDATE()
        WHERE divcode = @DivCode
          AND prno    = @PrNo
          AND prdate  = @PrDate
          AND NOT EXISTS (
              SELECT 1 FROM PO_PRL
              WHERE  divcode  = @DivCode
                AND  prno     = @PrNo
                AND  prdate   = @PrDate
                AND  ISNULL(FirstApp,  '') <> 'Y'
                AND  ISNULL(DirectApp, '') <> 'Y'           -- DirectApp lines bypass first-level
                AND  ISNULL(prstatus,  '') NOT IN ('X','Z') -- cancelled/foreclosed cannot be approved
          );

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
        -- qtyreqd is written during SaveFirstApproval so must be cleared on delete
        UPDATE PO_PRL
        SET qtyreqd      = NULL,
            FirstAppQty  = 0,
            FirstApp     = NULL,
            prstatus     = NULL,
            FirstappUser = NULL
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
            UOM, RATE, macno, SubCost, moduleNo,
            docno, docdt
        )
        SELECT
            @DivCode, @PrNo, @PrDate, l.itemcode, l.Depcode,
            @UserId, l.prsno, ISNULL(l.qtyind, 0), @UserName,
            GETDATE(), 'Purchase Requisition Approval', 'DELETE',
            @IpAddress, @HostName,
            i.CUOM, ISNULL(l.RATE, 0), l.macno, h.SubCost, @ModuleNo,
            @PrNo, @PrDate
        FROM PO_PRL l
        INNER JOIN IN_ITEM i ON i.ITEMCODE = l.itemcode
        LEFT  JOIN PO_PRH  h ON h.divcode = l.divcode
                             AND h.prno    = l.prno
                             AND h.prdate  = l.prdate
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
        RTRIM(ISNULL(apv.user_name, ISNULL(h.APP1, '')))    AS ApproverName,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby,''))) AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                       AS CreatedDt

    FROM PO_PRH h
    LEFT JOIN PP_DIVMAS dv ON dv.DIVCODE = h.divcode
    LEFT JOIN IN_DEP    d  ON d.DEPCODE  = h.depcode AND d.divcode = h.divcode
    LEFT JOIN PR_EMP    e  ON TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno
                          AND e.divcode = h.divcode
    OUTER APPLY (
        SELECT TOP 1 user_name FROM PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(h.APP1)
          AND RTRIM(divcode)  = RTRIM(h.divcode)
    ) apv
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
    @Dep     VARCHAR(3),       -- specific depcode from PO_IndentAppUser for logged-in user
    @YFDate  DATETIME,         -- financial year start (B13/B14: year guard required)
    @YLDate  DATETIME          -- financial year end
AS
BEGIN
    SET NOCOUNT ON;

    -- Year guard applied per prompt clarification B13/B14 (overrides OI-02).

    SELECT DISTINCT
        h.prno              AS PrNo,
        h.prdate            AS PrDate,
        h.depcode           AS DepCode,
        ISNULL(d.DEPNAME, h.depcode) AS DepName,
        ISNULL(h.refno, '')  AS RefNo,
        ISNULL(h.SECTION,'') AS Section
    FROM PO_PRH h
    LEFT JOIN IN_DEP d
        ON  d.DEPCODE = h.depcode
        AND d.divcode = h.divcode
    WHERE h.divcode = @DivCode
      AND h.depcode = @Dep
      AND h.prdate BETWEEN @YFDate AND @YLDate
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
    @DivCode VARCHAR(2),
    @YFDate  DATETIME,         -- financial year start (B13/B14: year guard required)
    @YLDate  DATETIME          -- financial year end
AS
BEGIN
    SET NOCOUNT ON;

    -- Year guard applied per prompt clarification B13/B14 (overrides OI-02).
    -- Used for Delete-Approval listing, Find, and Navigation.

    SELECT DISTINCT
        h.prno              AS PrNo,
        h.prdate            AS PrDate,
        h.depcode           AS DepCode,
        ISNULL(d.DEPNAME, h.depcode) AS DepName,
        ISNULL(h.refno, '')  AS RefNo,
        ISNULL(h.SECTION,'') AS Section
    FROM PO_PRH h
    LEFT JOIN IN_DEP d
        ON  d.DEPCODE = h.depcode
        AND d.divcode = h.divcode
    WHERE h.divcode = @DivCode
      AND h.prdate BETWEEN @YFDate AND @YLDate
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
-- ============================================================
-- SP: ksp_po_finalapproval  [COMPATIBILITY HOTFIX — 06 Jun 2026]
-- Supports Legacy VB6/ASP.NET + Spinrise V2 simultaneously.
-- See: Docs/Plans/HOTFIX_ksp_po_finalapproval_compatibility.md
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_finalapproval]
(
    -- Original VB6 parameters — exact original order and types
    @imode              int             = null,
    @divcode            varchar(2)      = null,
    @FinalAppUser       varchar(35)     = null,
    @FinalAppQty        numeric(12,3)   = null,
    @FinalLevel_Remarks varchar(20)     = null,
    @prno               numeric(6)      = null,
    @prdate             datetime        = null,
    @prsno              numeric(5)      = null,
    @logindate          datetime        = null,
    @Bypass             int             = null,
    -- Spinrise V2 parameters — NULL defaults so VB6 callers safely omit them
    @dbname             varchar(20)     = null,
    @row_version        binary(8)       = null,
    @Result             int             = null OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @phno        VARCHAR(50),
            @FinFromDate DATETIME,
            @ToFinYear   DATETIME;

    -- Financial year lookup (restored from original)
    SELECT @FinFromDate = py.AYFDATE,
           @ToFinYear   = GETDATE()
    FROM   PP_YEAR py
    WHERE  py.AYFDATE <= GETDATE()
      AND  py.AYLDATE  >= GETDATE();

    -- Phone lookup for SMS (restored to top-level from original)
    SET @phno = (
        SELECT DISTINCT TOP 1 ISNULL(CONVERT(varchar(50), phone), '')
        FROM (
            SELECT DISTINCT phone, ae.EmpNo FROM Al_Emp  ae WHERE phone <> ''
            UNION ALL
            SELECT DISTINCT phone, ae.EmpNo FROM PR_EMP  ae WHERE phone <> ''
        ) A
        WHERE A.EmpNo IN (
            SELECT pe.empno
            FROM   PO_PRH  pp
            INNER JOIN PR_EMP pe ON pe.divcode = pp.divcode
                                AND pp.REQNAME = CONVERT(varchar(10), pe.empno)
            WHERE  pp.prno   = @prno
              AND  pp.prdate = @prdate
        )
    );

    -- ── imode 2/3 — SELECT grid rows ─────────────────────────────────────────
    IF @imode IN (2, 3)
    BEGIN
        SELECT
            -- VB6 original columns in original order
            DB_NAME()                                                   AS CName,
            div.divcode,
            div.abbr,
            div.divname,
            hd.Prno,
            hd.Prdate,
            dt.prsno,
            dt.itemcode,
            itm.itemname,
            itm.uom,
            dep.Depname,
            ISNULL(S.SccName, '')                                       AS SccName,
            hd.depcode,
            ISNULL(hd.SubCost, 0)                                      AS SubCost,
            dt.qtyind,
            CASE
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.FirstAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0 THEN dt.qtyreqd
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0
                 AND dt.FirstAppQty > 0           THEN dt.FirstAppQty
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.SecondAppQty
                WHEN dt.ThirdAppQty  > 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.ThirdAppQty
                ELSE dt.qtyreqd
            END                                                         AS QTYREQD,
            dt.LPO_RATE                                                 AS rat,
            CONVERT(varchar, dt.LPO_DATE, 103)                         AS val,
            dt.remarks,
            hd.refno,
            dt.FirstApp,
            dt.SecondApp,
            dt.ThirdApp,
            CASE
                WHEN @imode = 2
                THEN (SELECT dbo.KSP_PRItemStock_FUN(
                        @divcode,
                        REPLACE(CONVERT(VARCHAR(15), GETDATE(),      102), '.', '-'),
                        dt.itemcode,
                        REPLACE(CONVERT(VARCHAR(15), @FinFromDate,   102), '.', '-'),
                        REPLACE(CONVERT(VARCHAR(15), @ToFinYear,     102), '.', '-')
                     ))
                ELSE (SELECT dbo.KSP_PRItemStock_FUN_WITH_DIV(
                        @divcode,
                        REPLACE(CONVERT(VARCHAR(15), hd.Prdate,      102), '.', '-'),
                        dt.itemcode,
                        REPLACE(CONVERT(VARCHAR(15), @FinFromDate,   102), '.', '-'),
                        REPLACE(CONVERT(VARCHAR(15), @ToFinYear,     102), '.', '-')
                     ))
            END                                                         AS Curstock,
            dt.DepCode                                                  AS Dep,
            dt.FinalLevel_Remarks                                       AS Fremark,
            CONVERT(varchar, hd.Prdate, 103)                            AS Prdate1,
            CASE ISNULL(dt.APPCOST, 0)
                WHEN 0    THEN NULL
                WHEN 0.00 THEN NULL
                ELSE dt.APPCOST
            END                                                         AS value,
            ISNULL(dt.remarks, '')                                      AS remarks,
            CASE ISNULL(dt.APPCOST, 0)
                WHEN 0    THEN NULL
                WHEN 0.00 THEN NULL
                ELSE dt.APPCOST
            END                                                         AS NetAmount,
            -- Spinrise V2 columns appended (Dapper maps by column name)
            dep.Depname                                                 AS department,
            CASE
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.FirstAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0 THEN dt.qtyreqd
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND ISNULL(dt.SecondAppQty, 0) = 0
                 AND dt.FirstAppQty > 0           THEN dt.FirstAppQty
                WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.SecondAppQty
                WHEN dt.ThirdAppQty  > 0
                 AND dt.SecondAppQty > 0
                 AND dt.FirstAppQty  > 0          THEN dt.ThirdAppQty
                ELSE dt.qtyreqd
            END                                                         AS qtyRequired,
            ISNULL(dt.FinalAppQty,
                CASE
                    WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                     AND ISNULL(dt.FirstAppQty,  0) = 0
                     AND ISNULL(dt.SecondAppQty, 0) = 0 THEN dt.qtyreqd
                    WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                     AND ISNULL(dt.SecondAppQty, 0) = 0
                     AND dt.FirstAppQty > 0           THEN dt.FirstAppQty
                    WHEN ISNULL(dt.ThirdAppQty,  0) = 0
                     AND dt.SecondAppQty > 0
                     AND dt.FirstAppQty  > 0          THEN dt.SecondAppQty
                    WHEN dt.ThirdAppQty  > 0
                     AND dt.SecondAppQty > 0
                     AND dt.FirstAppQty  > 0          THEN dt.ThirdAppQty
                    ELSE dt.qtyreqd
                END
            )                                                           AS qtyApproved,
            CASE WHEN ISNULL(TRY_CAST(dt.FinalLevel_Remarks AS int), 0) = 0
                 THEN 2
                 ELSE TRY_CAST(dt.FinalLevel_Remarks AS int)
            END                                                         AS disposition,
            dt.LPO_RATE                                                 AS lpoRate,
            CONVERT(varchar, dt.LPO_DATE, 103)                         AS lpoDate,
            CASE ISNULL(dt.APPCOST, 0)
                WHEN 0 THEN NULL
                ELSE dt.APPCOST
            END                                                         AS approxCost,
            CASE
                WHEN dt.ThirdApp  IS NOT NULL AND dt.ThirdApp  = 'Y' THEN 'final'
                WHEN dt.SecondApp IS NOT NULL AND dt.SecondApp = 'Y' THEN 'second'
                ELSE 'first'
            END                                                         AS approvalStatus,
            dt.row_version                                              AS rowVersion,
            ISNULL(dt.RATE, 0)                                         AS rate

        FROM   PO_PRH    hd
        LEFT JOIN PO_PRL    dt  ON  hd.divcode  = dt.divcode
                                AND hd.prno     = dt.prno
                                AND hd.prdate   = dt.prDate
        LEFT JOIN IN_DEP    dep ON  dep.divcode = hd.divcode
                                AND hd.depcode  = dep.depcode
        LEFT JOIN In_Scc    S   ON  hd.SubCost  = S.SccCode
                                AND hd.DepCode  = S.DepCode
                                AND hd.DivCOde  = S.DivCode
        LEFT JOIN IN_ITEM   itm ON  itm.itemcode = dt.itemcode
        LEFT JOIN PP_DIVMAS div ON  div.divcode  = hd.divcode

        WHERE  ISNULL(hd.cancelflag, '')  <> 'Y'
          AND  ISNULL(dt.Fclosed, 'N')   <> 'Y'
          AND  hd.divcode = div.divcode
          AND  ISNULL(dt.directApp, 'N') <> 'Y'
          AND  ISNULL(dt.QtyReqd, 0)      > 0
          AND  (dt.FirstApp IS NOT NULL AND dt.FirstApp <> '')
          AND  (
                @Bypass = 1
                OR (
                    (dt.SecondApp IS NOT NULL AND dt.SecondApp <> '')
                AND (dt.ThirdApp  IS NOT NULL AND dt.ThirdApp  <> '')
                )
               )
          AND  (@imode = 2 OR hd.divcode = @divcode)

        ORDER BY div.divcode, hd.Prdate, hd.Prno, dt.prsno;

        SET @Result = 0;
        RETURN;
    END

    -- ── imode=4 — SAVE ───────────────────────────────────────────────────────
    IF @imode = 4
    BEGIN
        BEGIN TRY
            BEGIN TRAN;

            UPDATE PO_PRL
            SET    FinalAppUser       = @FinalAppUser,
                   Prstatus           = 'D',
                   DirectApp          = 'Y',
                   FirstApp           = 'Y',
                   SecondApp          = 'Y',
                   ThirdApp           = 'Y',
                   DirectAppDate      = GETDATE(),
                   QtyReqd            = @FinalAppQty,
                   FinalAppQty        = @FinalAppQty,
                   FinalLevel_Remarks = @FinalLevel_Remarks,
                   FClosed            = CASE WHEN @FinalLevel_Remarks = '4' THEN 'Y'       ELSE FClosed   END,
                   FCloseddt          = CASE WHEN @FinalLevel_Remarks = '4' THEN GETDATE() ELSE FCloseddt END
            WHERE  prno    = @prno
              AND  prdate  = @prdate
              AND  prsno   = @prsno
              AND  divcode = @divcode
              AND  (@row_version IS NULL OR row_version = @row_version);

            -- Concurrency result (V2 only — VB6 passes @row_version=NULL, this block skipped)
            IF @@ROWCOUNT = 0 AND @row_version IS NOT NULL
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM PO_PRL
                    WHERE  divcode = @divcode AND prno  = @prno
                      AND  prdate  = @prdate  AND prsno = @prsno
                )
                    SET @Result = 3;
                ELSE
                    SET @Result = 4;
                ROLLBACK TRAN;
                RETURN;
            END

            UPDATE PO_PRH
            SET    appflg    = 'Y',
                   app1      = ISNULL(app1,     'DIR'),
                   APP1DATE  = ISNULL(APP1DATE,  GETDATE()),
                   APP1TIME  = ISNULL(APP1TIME,  GETDATE()),
                   app2      = ISNULL(app2,     'DIR'),
                   APP2DATE  = ISNULL(APP2DATE,  GETDATE()),
                   APP2TIME  = ISNULL(APP2TIME,  GETDATE()),
                   app3      = ISNULL(app3,     'DIR'),
                   APP3DATE  = ISNULL(APP3DATE,  GETDATE()),
                   APP3TIME  = ISNULL(APP3TIME,  GETDATE())
            WHERE  prno    = @prno
              AND  prdate  = @prdate
              AND  divcode = @divcode;

            UPDATE PO_Para SET PRSMSStatusFlg = 'Y' WHERE Divcode = @divcode;

            -- SMS notifications (original column list)
            IF @FinalLevel_Remarks = '1'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(15), @prdate) + ' Is PL Discuss',
                     @phno, 'N', 0, '', 0, GETDATE());

            ELSE IF @FinalLevel_Remarks = '3'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(15), @prdate) + ' Is Hold',
                     @phno, 'N', 0, '', 0, GETDATE());

            ELSE IF @FinalLevel_Remarks = '4'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(15), @prdate) + ' Declined',
                     @phno, 'N', 0, '', 0, GETDATE());

            ELSE IF @FinalLevel_Remarks = '5'
                INSERT INTO Al_SMSMessage
                    (Divcode, EntryDate, EntryUserID, SmsMsg, SmsMobileNo,
                     Sendflg, SendDate, SendStatus, NoofTry, NextTryTime)
                VALUES (@divcode, GETDATE(), @FinalAppUser,
                     'PR No :' + CONVERT(varchar(10), @prsno) + ' PR Date :' + CONVERT(varchar(10), @prdate) + ' Postponed',
                     @phno, 'N', 0, '', 0, GETDATE());

            -- Audit log (Spinrise V2 — transparent to VB6)
            INSERT INTO LogDet_po
                (divcode, prno, prdate, prsno,
                 prstatus, Trans_UserId, Trans_date, Trans_Name, Trans_Mod, Activity)
            VALUES
                (@divcode, @prno, @prdate, @prsno,
                 'D', @FinalAppUser, GETDATE(), 'Final Level PR Approval', 'FinalApp',
                 CASE @FinalLevel_Remarks
                     WHEN '1' THEN 'PL_DISCUSS'
                     WHEN '2' THEN 'APPROVED'
                     WHEN '3' THEN 'HOLD'
                     WHEN '4' THEN 'DECLINED'
                     WHEN '5' THEN 'POSTPONED'
                     ELSE          'APPROVED'
                 END);

            COMMIT TRAN;
            SET @Result = 0;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            SET @Result = 2;
            DECLARE @ErrMsg      nvarchar(4000) = ERROR_MESSAGE(),
                    @ErrSeverity int            = ERROR_SEVERITY();
            RAISERROR(@ErrMsg, @ErrSeverity, 1);
        END CATCH
    END

END;
GO
GO
GO

-- ============================================================
-- SP: ksp_po_GetFinalApprovalCompanies
-- Purpose: Company dropdown for Final Level PR Approval
-- TODO: Confirm pp_database column names with DBA
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_GetFinalApprovalCompanies]
AS
BEGIN
    SET NOCOUNT ON;
    -- Confirmed columns: Database_No, Database_Name
    SELECT
        d.Database_Name AS dbname,
        d.Database_Name AS companyName
    FROM dbo.pp_database d
    ORDER BY d.Database_No;
END;

GO

-- ============================================================
-- SP: ksp_po_GetFinalApprovalDivisions
-- Purpose: Division dropdown for Final Level PR Approval
-- TODO: Confirm pp_divmas column names with DBA
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_GetFinalApprovalDivisions]
    @DbName varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    -- Confirmed columns: DIVCODE, DIVNAME (from ksp_Auth_GetActiveDivisions)
    -- No company/dbname filter on pp_divmas — returns all divisions
    SELECT
        RTRIM(d.DIVCODE) AS divcode,
        RTRIM(d.DIVNAME) AS divisionName,
        RTRIM(d.DIVCODE) AS abbr
    FROM dbo.pp_divmas d
    ORDER BY d.DIVCODE;
END;

GO

-- ============================================================
-- SP: ksp_Auth_GetCompanies
-- Purpose: Populate Company dropdown on Login page
-- Source: PP_Compmas — columns: compcode, compname
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetCompanies
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(c.compcode) AS compCode,
        RTRIM(c.compname) AS compName
    FROM dbo.compmas c
    ORDER BY c.compcode;

END;

GO

-- Sasi: add Division_Flag to pp_divmas (safe to re-run)
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'pp_divmas' AND COLUMN_NAME = 'Division_Flag')
BEGIN
    ALTER TABLE pp_divmas ADD Division_Flag char(1)
END
GO



-- ============================================================
-- ksp_PO_GetParameters
-- Reads PO_PARA for the given division.
-- Returns: parameter columns that drive PO screen behaviour.
-- Called on screen load.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetParameters
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(p.PoFirstLevelApp, 'N') AS PoFirstLevelApp,
        ISNULL(p.poprintapp,       'N') AS PoPrintApp,
        ISNULL(p.Po_Confirm,       'N') AS PoConf,
        ISNULL(p.budGrp,           'N') AS BudGrp,
        ISNULL(p.BudgetQty,        'N') AS BudgetQty,
        ISNULL(p.BudgetControl,    'N') AS BudgetControl,
        ISNULL(p.CurrCode,         '')  AS CurrCode,
        ISNULL(ip.BACKDATE,        'Y') AS BackDate,
        ISNULL(p.PDFExportFlag,    'N') AS PdfExportFlag
    FROM dbo.PO_PARA p
    CROSS JOIN (SELECT TOP 1 ISNULL(UPPER(RTRIM(BACKDATE)), 'Y') AS BACKDATE FROM dbo.IN_PARA) ip
    WHERE p.divcode = @DivCode;
END;
GO



-- ============================================================
-- ksp_PO_GetUserLevel
-- Returns PO Entry permissions for the given user/division.
-- Deny-by-default (D-12): no USERLEVEL row → all false.
-- ⚠ VERIFY: MODULE = 5 for PO Entry — confirm in USERLEVEL table.
-- ⚠ VERIFY: PRINT_FLG column name — may be PRT_FLG or similar.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetUserLevel
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
            SELECT 0 AS CanAdd, 0 AS CanDelete, 0 AS CanPrint;
            RETURN;
        END;

        SELECT TOP 1
            CAST(CASE WHEN UPPER(ISNULL(ADD_FLG,   'N')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanAdd,
            CAST(CASE WHEN UPPER(ISNULL(DEL_FLG,   'N')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanDelete,
            CAST(CASE WHEN UPPER(ISNULL(ADD_FLG,   'N')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanPrint  -- no separate PRINT_FLG; CanPrint = CanAdd
        FROM dbo.USERLEVEL
        WHERE RTRIM(DIVCODE) = RTRIM(@DivCode)
          AND MODULE          = 5   -- ⚠ VERIFY: 5 = PO Entry module number
          AND ULEVEL          = @ULevel;

        IF @@ROWCOUNT = 0
            SELECT 0 AS CanAdd, 0 AS CanDelete, 0 AS CanPrint;
    END TRY
    BEGIN CATCH
        SELECT 0 AS CanAdd, 0 AS CanDelete, 0 AS CanPrint;
    END CATCH
END;
GO



-- ============================================================
-- ksp_PO_GetPreAddChecks
-- Gate checks before entering ADD mode.
-- Returns: flags for approved PR lines, doc para, backdate, max PO date.
-- ⚠ VERIFY: PO_DOC_PARA TC value for Purchase Order — may be 'PO' or 'PORDER'.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPreAddChecks
(
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ApprovedPrLinesExist BIT = 0;
    DECLARE @DocParaExists        BIT = 0;
    DECLARE @BackDateFlag         CHAR(1) = 'Y';
    DECLARE @MaxPoDate            DATE = NULL;

    -- Check 1: At least one approved PR line with balance > 0 (BR-02)
    IF EXISTS (
        SELECT 1
        FROM dbo.PO_PRL l
        INNER JOIN dbo.PO_PRH h
            ON h.divcode = l.divcode AND h.prno = l.prno
        WHERE l.divcode = @DivCode
          AND ISNULL(l.DirectApp, 'N') = 'Y'
          AND ISNULL(l.FClosed,   'N') <> 'Y'
          AND (ISNULL(l.QTYREQD, 0) - ISNULL(l.QTYORD, 0) - ISNULL(l.enq_qty, 0)) > 0
          AND RTRIM(ISNULL(l.prstatus, '')) NOT IN ('O','E','C','Z','X')
          AND ISNULL(h.cancelflag, '') = ''
    )
        SET @ApprovedPrLinesExist = 1;

    -- Check 2: PO doc series defined in PO_DOC_PARA
    -- ⚠ VERIFY: TC value for Purchase Order in this installation
    IF EXISTS (SELECT 1 FROM dbo.PO_DOC_PARA WHERE TC = 'PO')
        SET @DocParaExists = 1;

    -- Backdate flag
    SELECT TOP 1 @BackDateFlag = ISNULL(UPPER(RTRIM(BACKDATE)), 'Y')
    FROM dbo.IN_PARA;

    -- Max existing PO date for this division
    SELECT @MaxPoDate = CAST(MAX(PORDDT) AS DATE)
    FROM dbo.PO_ORDH
    WHERE divcode = @DivCode
      AND ISNULL(CANFLG, '') = '';

    SELECT
        @ApprovedPrLinesExist AS ApprovedPrLinesExist,
        @DocParaExists        AS DocParaExists,
        @BackDateFlag         AS BackDateFlag,
        @MaxPoDate            AS MaxPoDate;
END;
GO



-- ============================================================
-- ksp_PO_GetOrderTypes
-- Returns purchase order type lookup.
-- PO_TYPE columns: TYPE_CODE, TYPNAME, active (varchar)
-- ⚠ VERIFY: MODULE = 5 for PO Entry (confirm in USERLEVEL data).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetOrderTypes
(
    @ActiveOnly INT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.TYPE_CODE) AS PoGrp,
        RTRIM(t.TYPNAME)   AS TypName
    FROM dbo.PO_TYPE t
    WHERE @ActiveOnly = 0
       OR UPPER(ISNULL(t.active, 'Y')) = 'Y'
    ORDER BY t.TYPE_CODE;
END;
GO



-- ============================================================
-- ksp_PO_GetSuppliers
-- Returns supplier lookup for the Order Details tab (BR-12).
-- FA_SLMAS is company-wide (no divcode column).
-- Active filter: active = 'Y'.
-- GstStateName composed from gststatecode + state field.
-- ⚠ VERIFY: 'active' = 'Y' is the correct active supplier filter.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetSuppliers
(
    @DivCode VARCHAR(2),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 100
        RTRIM(s.slcode)                                         AS SlCode,
        RTRIM(ISNULL(s.slname, ''))                             AS SlName,
        RTRIM(ISNULL(s.gstinno, ''))                            AS GstinNo,
        RTRIM(ISNULL(s.gststatecode, ''))                       AS GstStateCode,
        RTRIM(ISNULL(s.gststatecode, '')) +
            CASE WHEN RTRIM(ISNULL(s.state, '')) <> ''
                 THEN ' - ' + RTRIM(s.state)
                 ELSE '' END                                    AS GstStateName
    FROM dbo.FA_SLMAS s
    WHERE UPPER(ISNULL(s.active, 'Y')) = 'Y'
      AND (@Search IS NULL
           OR RTRIM(s.slcode) LIKE @Search + '%'
           OR RTRIM(s.slname) LIKE '%' + @Search + '%')
    ORDER BY s.slname;
END;
GO



-- ============================================================
-- ksp_PO_GetCarriers
-- Returns carrier lookup for the Instructions tab.
-- Table: PO_CAR (confirmed JAT schema).
-- Columns: CARCODE, CARNAME, active.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetCarriers
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(c.CARCODE)              AS CarCode,
        RTRIM(ISNULL(c.CARNAME, '')) AS CarName
    FROM dbo.PO_CAR c
    WHERE UPPER(ISNULL(c.active, 'Y')) = 'Y'
      AND (@Search IS NULL
           OR RTRIM(c.CARCODE) LIKE @Search + '%'
           OR RTRIM(c.CARNAME) LIKE '%' + @Search + '%')
    ORDER BY c.CARNAME;
END;
GO



-- ============================================================
-- ksp_PO_GetBanks
-- Returns active bank list for the Payment tab (BR-15).
-- Table: pr_Bank (confirmed 15-Jun-2026)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetBanks
(
    @DivCode VARCHAR(2),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(b.Bank_Code) AS BankCode,
        RTRIM(b.bank_Name) AS BankName
    FROM dbo.pr_Bank b
    WHERE b.Active = 'Y'
      AND b.Divcode = @DivCode
      AND (
            @Search IS NULL OR @Search = ''
            OR b.Bank_Code LIKE '%' + @Search + '%'
            OR b.bank_Name LIKE '%' + @Search + '%'
          )
    ORDER BY b.bank_Name;
END;
GO



-- ============================================================
-- ksp_PO_GetFormTypes
-- Returns form type lookup for the Order Details tab.
-- Table: PO_FormType (confirmed JAT schema).
-- Columns: TypeCode → FormCode, Description → FormName, active.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetFormTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(f.TypeCode)                  AS FormCode,
        RTRIM(ISNULL(f.Description, ''))   AS FormName
    FROM dbo.PO_FormType f
    WHERE UPPER(ISNULL(f.active, 'Y')) = 'Y'
    ORDER BY f.TypeCode;
END;
GO



-- ============================================================
-- ksp_PO_GetGstTaxCodes
-- Returns GST tax code lookup for the GST modal (BR-09).
-- Only active codes returned (TAXSTATUS = 'Y').
-- IG_TAX columns: TAX_CODE, DESCRIPTION, ST_PER, TAXSTATUS.
-- CGST/SGST = ST_PER / 2 (intra-state split); IGST = ST_PER (inter-state).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetGstTaxCodes
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.TAX_CODE)                    AS TaxCode,
        RTRIM(ISNULL(t.DESCRIPTION, ''))     AS TaxDesc,
        ROUND(ISNULL(t.ST_PER, 0) / 2, 2)   AS CgstPer,
        ROUND(ISNULL(t.ST_PER, 0) / 2, 2)   AS SgstPer,
        ISNULL(t.ST_PER, 0)                  AS IgstPer,
        ISNULL(t.TAXSTATUS, 'Y')             AS TaxStatus
    FROM dbo.IG_TAX t
    WHERE UPPER(ISNULL(t.TAXSTATUS, 'Y')) = 'Y'
      AND (@Search IS NULL
           OR RTRIM(t.TAX_CODE)    LIKE @Search + '%'
           OR RTRIM(t.DESCRIPTION) LIKE '%' + @Search + '%')
    ORDER BY t.TAX_CODE;
END;
GO



-- ============================================================
-- ksp_PO_GetGSTRouting
-- Server-decides LOCAL vs IGST by comparing division state vs
-- supplier GST state code (§3.10: pp_divmas vs fa_slmas).
-- ⚠ VERIFY: pp_divmas column gststatecode — may differ.
-- ⚠ VERIFY: FA_SLMAS column for GST state code.
-- ⚠ VERIFY: table name pp_divmas — may be PO_DIVMAS or similar.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetGSTRouting
(
    @DivCode VARCHAR(2),
    @SlCode  VARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DivStateCode  VARCHAR(10) = '';
    DECLARE @SupStateCode  VARCHAR(10) = '';

    SELECT TOP 1 @DivStateCode = RTRIM(ISNULL(d.gststatecode, ''))  -- ⚠ VERIFY: column gststatecode on pp_divmas
    FROM dbo.pp_divmas d                                              -- ⚠ VERIFY: table name pp_divmas
    WHERE RTRIM(d.divcode) = RTRIM(@DivCode);

    SELECT TOP 1 @SupStateCode = RTRIM(ISNULL(s.gststatecode, ''))  -- ⚠ VERIFY: column gststatecode on FA_SLMAS
    FROM dbo.FA_SLMAS s
    WHERE RTRIM(s.SLCODE) = RTRIM(@SlCode);

    SELECT
        CASE WHEN @DivStateCode = @SupStateCode AND @DivStateCode <> '' THEN 'LOCAL' ELSE 'IGST' END AS Route,
        @DivStateCode AS DivStateCode,
        @SupStateCode AS SupStateCode;
END;
GO



-- ============================================================
-- ksp_PO_GetAddresses
-- Returns delivery or billing address lookup (Instructions tab).
-- @Kind = 'DELIVERY' → in_deladd | 'BILLING' → in_billadd
-- Source: indenttopo.frm L12877 / L12899
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAddresses
(
    @DivCode VARCHAR(2),
    @Kind    VARCHAR(20),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF UPPER(@Kind) = 'DELIVERY'
    BEGIN
        SELECT
            RTRIM(a.slcode) AS Code,
            RTRIM(a.slname) AS Name
        FROM dbo.in_deladd a
        WHERE RTRIM(a.divcode) = @DivCode
          AND ISNULL(a.Active, 'N') = 'Y'
          AND (@Search IS NULL
               OR RTRIM(a.slcode) LIKE @Search + '%'
               OR RTRIM(a.slname) LIKE '%' + @Search + '%')
        ORDER BY a.slname;
    END
    ELSE IF UPPER(@Kind) = 'BILLING'
    BEGIN
        SELECT
            RTRIM(a.slcode) AS Code,
            RTRIM(a.slname) AS Name
        FROM dbo.in_billadd a
        WHERE RTRIM(a.divcode) = @DivCode
          AND ISNULL(a.Active, 'N') = 'Y'
          AND (@Search IS NULL
               OR RTRIM(a.slcode) LIKE @Search + '%'
               OR RTRIM(a.slname) LIKE '%' + @Search + '%')
        ORDER BY a.slname;
    END
END;
GO



-- ============================================================
-- ksp_PO_GetCurrencies
-- Returns active currency list with latest conversion rate.
-- Source: indenttopo.frm L12975; rate from PO_ConvFactT L12962
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetCurrencies
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(c.currcode) AS CurrCode,
        RTRIM(c.currname) AS CurrName,
        ISNULL((
            SELECT TOP 1 r.ConvFact
            FROM dbo.PO_ConvFactT r
            WHERE r.CurrCode = c.currcode
            ORDER BY r.FromDate DESC
        ), 0) AS CurrRate
    FROM dbo.FA_CURRENCY c
    WHERE ISNULL(c.Active, 'N') = 'Y'
      AND (@Search IS NULL
           OR RTRIM(c.currcode) LIKE @Search + '%'
           OR RTRIM(c.currname) LIKE '%' + @Search + '%')
    ORDER BY c.currcode;
END;
GO



-- ============================================================
-- ksp_PO_GetPricingTerms
-- Returns pricing terms lookup for PO Instructions tab.
-- Source: indenttopo.frm L12344
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPricingTerms
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.SCode) AS Code,
        RTRIM(t.SName) AS Name
    FROM dbo.Ex_ShipTerm t
    WHERE (@Search IS NULL
           OR RTRIM(t.SCode) LIKE @Search + '%'
           OR RTRIM(t.SName) LIKE '%' + @Search + '%')
    ORDER BY t.SCode;
END;
GO



-- ksp_PO_GetPRLines
-- Returns eligible PR lines for the PO PR Picker (BR-02).
-- Filter: DirectApp='Y', Fclosed<>'Y', balance qty > 0,
--         prstatus NOT IN ('O','E','C','Z','X'), PR not cancelled.
-- Balance = QTYREQD - QTYORD - Enq_Qty
-- GST columns (CgstPer/SgstPer/IgstPer/GstTaxCode) sourced from IN_ITEM.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPRLines
(
    @DivCode    VARCHAR(2),
    @OrderType  VARCHAR(10) = NULL,
    @Search     VARCHAR(100) = NULL,
    @PageNumber INT          = 1,
    @PageSize   INT          = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        CAST(l.prno AS VARCHAR(20)) + '|' + CAST(l.prsno AS VARCHAR(10)) + '|' + RTRIM(l.itemcode) AS Id,
        l.prno                                                          AS PrNo,
        CONVERT(varchar(11), CAST(ISNULL(h.prdate, l.prdate) AS DATE), 106) AS PrDate,
        l.prsno                                                         AS PrSno,
        RTRIM(l.itemcode)                                               AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                                   AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                        AS Uom,
        ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0) - ISNULL(l.Enq_Qty, 0) AS BalanceQty,
        RTRIM(ISNULL(d.depname, ''))                                    AS Department,
        RTRIM(ISNULL(scc.SCCNAME, ''))                                  AS SubCostCentre,
        RTRIM(ISNULL(l.remarks, ''))                                    AS Remarks,
        RTRIM(ISNULL(i.hsncode, ''))                                    AS HsnCode,
        ISNULL(i.CGST_PER, 0)                                          AS CgstPer,
        ISNULL(i.SGST_PER, 0)                                          AS SgstPer,
        ISNULL(i.IGST_PER, 0)                                          AS IgstPer,
        RTRIM(ISNULL(i.GSTTAXCODE, ''))                                AS GstTaxCode,
        RTRIM(ISNULL(h.REQNAME, ''))                                    AS RequesterId,
        RTRIM(ISNULL(e.ename, ''))                                      AS RequesterName
    FROM dbo.PO_PRL l
    INNER JOIN dbo.PO_PRH h
        ON h.divcode = l.divcode AND h.prno = l.prno
       AND CAST(h.prdate AS DATE) = CAST(l.prdate AS DATE)
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.itemcode
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = l.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.In_Scc scc
        ON scc.SCCCODE = l.CCCODE AND scc.Divcode = l.divcode
    OUTER APPLY (
        SELECT TOP 1 e.ename
        FROM dbo.PR_EMP e
        WHERE TRY_CAST(h.REQNAME AS DECIMAL(5,0)) = e.empno
        ORDER BY CASE WHEN e.divcode = @DivCode THEN 0 ELSE 1 END, e.empno
    ) e
    WHERE l.divcode = @DivCode
      AND ISNULL(l.DirectApp, 'N') = 'Y'
      AND ISNULL(l.FClosed,   'N') <> 'Y'
      AND ISNULL(l.AmdFlg,    '') <> 'Y'
      AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0) - ISNULL(l.Enq_Qty, 0)) > 0
      AND RTRIM(ISNULL(l.prstatus, '')) NOT IN ('O','E','C','Z','X')
      AND ISNULL(h.cancelflag, '') = ''
      AND (@OrderType IS NULL OR RTRIM(ISNULL(h.PO_GRP, '')) = @OrderType)
      AND (@Search IS NULL
           OR RTRIM(l.itemcode) LIKE @Search + '%'
           OR RTRIM(i.itemname) LIKE '%' + @Search + '%'
           OR CAST(l.prno AS VARCHAR(20)) LIKE @Search + '%')
    ORDER BY h.prdate, l.prno, l.prsno
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO



-- ============================================================
-- ksp_PO_GetLastPO
-- Loads most recent PO for the division in the FY window.
-- Returns 3 result sets: (1) header, (2) lines, (3) delivery slots.
-- Called on screen load (View mode initial state).
-- Column mapping confirmed against live JAT PO_ORDH schema.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetLastPO
(
    @DivCode VARCHAR(2),
    @FDate   DATE,
    @LDate   DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PoNo   NUMERIC(10,0);
    DECLARE @PoDate DATE;

    SELECT TOP 1
        @PoNo   = PORDNO,
        @PoDate = CAST(PORDDT AS DATE)
    FROM dbo.PO_ORDH
    WHERE DIVCODE = @DivCode
      AND CAST(PORDDT AS DATE) BETWEEN @FDate AND @LDate
      AND ISNULL(CANFLG, '') = ''
    ORDER BY PORDDT DESC, PORDNO DESC;

    IF @PoNo IS NULL
    BEGIN
        SELECT NULL AS DivCode, NULL AS PoNo, NULL AS PoDate, NULL AS OrderType,
               NULL AS OrderTypeDesc, NULL AS Supplier, NULL AS SupplierName,
               NULL AS Gstin, NULL AS GstState, NULL AS Inspect,
               NULL AS RoundOff, NULL AS OrderValue, NULL AS FormType,
               NULL AS RefNo, NULL AS RefDate, NULL AS Currency, NULL AS CurrRate,
               NULL AS Remarks, NULL AS CgstPer, NULL AS SgstPer, NULL AS IgstPer,
               NULL AS TcsPer, NULL AS DiscPer, NULL AS CessPer, NULL AS AedPer,
               NULL AS FreightAmt, NULL AS PackPer, NULL AS InsurPer,
               NULL AS SurchargePer, NULL AS AddTaxPer, NULL AS FileNo,
               NULL AS FcaFob, NULL AS FreightType, NULL AS DiscApp,
               NULL AS PackApp, NULL AS CessApp, NULL AS PayMode,
               NULL AS DirectInstr, NULL AS BankCode, NULL AS PaymentTerms,
               NULL AS AdvPer, NULL AS AdvAmt, NULL AS ModeOfPayment,
               NULL AS PayRef, NULL AS PayRefDate, NULL AS ChequeNo,
               NULL AS ChequeDate, NULL AS CreditDays, NULL AS DeliveryDate,
               NULL AS DeliveryLocation, NULL AS BillingAddress,
               NULL AS SpecialInstr, NULL AS Despatch, NULL AS Purpose,
               NULL AS OtherLevies, NULL AS PricingTerms, NULL AS PackForwarding,
               NULL AS Insurance, NULL AS Freight, NULL AS Reminder, NULL AS Status,
               NULL AS Cancelled, NULL AS CancelDate, NULL AS CancelReason,
               NULL AS Approved, NULL AS ApprovedBy, NULL AS AmdOrderNo,
               NULL AS AmdDate, NULL AS AmdRefNo, NULL AS AmdRefDate,
               NULL AS ApprovalStatus, NULL AS PrintStatus, NULL AS FirstLevelApp,
               NULL AS Conflg, NULL AS CreatedBy, NULL AS CreatedDt,
               NULL AS UserId, NULL AS Carrier
        WHERE 1 = 0;
        SELECT 0 AS [LineNo] WHERE 1 = 0;
        SELECT 0 AS [LineNo] WHERE 1 = 0;
        RETURN;
    END

    -- ─── Result set 1: Header ─────────────────────────────────────────────────
    SELECT
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(t.TYPNAME, ''))                                AS OrderTypeDesc,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS Supplier,
        RTRIM(ISNULL(sl.slname, ''))                                AS SupplierName,
        RTRIM(ISNULL(h.cust_gstinno, ''))                           AS Gstin,
        CAST(ISNULL(h.cust_gststcode, 0) AS VARCHAR(50))            AS GstState,
        CASE WHEN UPPER(RTRIM(ISNULL(h.INSPECT, 'N'))) = 'Y' THEN 'YES' ELSE 'NO' END AS Inspect,
        ISNULL(h.roff, 0)                                           AS RoundOff,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        RTRIM(ISNULL(h.Form_type, ''))                              AS FormType,
        RTRIM(ISNULL(h.refno, ''))                                  AS RefNo,
        CASE WHEN h.refDate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.refDate AS DATE), 120) END AS RefDate,
        RTRIM(ISNULL(h.CurrCode, ''))                               AS Currency,
        ISNULL(h.FCurRate, 1)                                       AS CurrRate,
        RTRIM(ISNULL(h.REMARKS, ''))                                AS Remarks,
        -- Header GST: PO_ORDH stores amounts only (CGSTAMT/SGSTAMT/IGSTAMT), not percentages
        CAST(0 AS DECIMAL(10,2))                                    AS CgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS IgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.Cessper, 0)                                        AS CessPer,
        CAST(0 AS DECIMAL(10,2))                                    AS AedPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        ISNULL(h.PCKPER, 0)                                         AS PackPer,
        ISNULL(h.INSPER, 0)                                         AS InsurPer,
        ISNULL(h.SURPER, 0)                                         AS SurchargePer,
        ISNULL(h.ADDTAXPER, 0)                                      AS AddTaxPer,
        RTRIM(ISNULL(h.FILENO, ''))                                 AS FileNo,
        ISNULL(h.FCACharg, 0)                                       AS FcaFob,
        CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
        CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        'BEFORE'                                                                              AS CessApp,  -- Cess_Flg excluded: pre-GST retired per FSD v3.1 Stage 3 IST directive (13-Jun-2026)
        -- Payment
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.DIRECT_INS, ''))                             AS DirectInstr,
        RTRIM(ISNULL(h.BANK_CODE, ''))                              AS BankCode,
        RTRIM(ISNULL(h.PAYTERMS, ''))                               AS PaymentTerms,
        ISNULL(h.ADV_PER, 0)                                        AS AdvPer,
        ISNULL(h.ADV_AMT, 0)                                        AS AdvAmt,
        RTRIM(ISNULL(h.advpaymenttype, ''))                         AS ModeOfPayment,
        ''                                                          AS PayRef,
        NULL                                                        AS PayRefDate,
        RTRIM(ISNULL(h.chqno, ''))                                  AS ChequeNo,
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS ChequeDate,
        ISNULL(h.CRDDAYS, 0)                                        AS CreditDays,
        -- Instructions
        CASE WHEN h.Duedate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.Duedate AS DATE), 120) END AS DeliveryDate,
        RTRIM(ISNULL(h.DEL_INS1, ''))                               AS DeliveryLocation,
        RTRIM(ISNULL(h.Billadd, ''))                                AS BillingAddress,
        RTRIM(ISNULL(h.SPL_INS, ''))                                AS SpecialInstr,
        RTRIM(ISNULL(h.DEL_INS2, ''))                               AS Despatch,
        RTRIM(ISNULL(h.Note, ''))                                   AS Purpose,
        ''                                                          AS OtherLevies,
        RTRIM(ISNULL(h.PriceTerm, ''))                              AS PricingTerms,
        RTRIM(ISNULL(h.RemarksPF, ''))                              AS PackForwarding,
        RTRIM(ISNULL(h.RemarksIns, ''))                             AS Insurance,
        RTRIM(ISNULL(h.RemarksFrt, ''))                             AS Freight,
        -- Cancel / status
        RTRIM(ISNULL(h.REMINDER, ''))                               AS Reminder,
        ''                                                          AS Status,
        CAST(CASE WHEN ISNULL(h.CANFLG, '') <> '' THEN 1 ELSE 0 END AS BIT) AS Cancelled,
        CASE WHEN h.CANDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.CANDT AS DATE), 120) END AS CancelDate,
        RTRIM(ISNULL(h.REASON, ''))                                 AS CancelReason,
        RTRIM(ISNULL(h.APPROVED, 'N'))                              AS Approved,
        RTRIM(ISNULL(h.APPBY, ''))                                  AS ApprovedBy,
        -- Amendment
        TRY_CAST(NULLIF(RTRIM(h.AMDORDNO), '') AS DECIMAL(10,0))   AS AmdOrderNo,
        CASE WHEN h.AMDORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.AMDORDDT AS DATE), 120) END AS AmdDate,
        TRY_CAST(NULLIF(RTRIM(h.REFORDNO), '') AS DECIMAL(10,0))   AS AmdRefNo,
        CASE WHEN h.REFORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.REFORDDT AS DATE), 120) END AS AmdRefDate,
        -- Approval / print
        CASE WHEN ISNULL(h.Conflg, 'N') = 'Y' THEN 'CONFIRMED' ELSE 'PENDING' END AS ApprovalStatus,
        RTRIM(ISNULL(h.poprintflg, 'N'))                            AS PrintStatus,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(h.createdby, ''))                              AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        RTRIM(ISNULL(h.createdby, ''))                              AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;

    -- ─── Result set 2: Lines ──────────────────────────────────────────────────
    SELECT
        l.PORDSNO                                                   AS [LineNo],
        l.PRSNO                                                     AS PrSno,
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(CONVERT(varchar(10), CAST(l.PRDATE AS DATE), 120), '') AS PrDate,
        ISNULL(l.Rate, 0)                                           AS Rate,
        ISNULL(l.ORDqty, 0)                                         AS Qty,
        ISNULL(prl.qtyreqd,0) - ISNULL(prl.qtyord,0) - ISNULL(prl.Enq_Qty,0) AS BalanceQty,
        ISNULL(l.ORDVAL, 0)                                         AS Value,
        RTRIM(ISNULL(l.Tax_code, ''))                               AS TaxCode,
        ISNULL(l.taxper, 0)                                         AS TaxPer,
        ISNULL(l.Taxamt, 0)                                         AS TaxAmt,
        RTRIM(ISNULL(l.hsncode, ''))                                AS HsnCode,
        ISNULL(l.cgstper, 0)                                        AS CgstPer,
        ISNULL(l.cgstamt, 0)                                        AS CgstAmt,
        ISNULL(l.sgstper, 0)                                        AS SgstPer,
        ISNULL(l.sgstamt, 0)                                        AS SgstAmt,
        ISNULL(l.igstper, 0)                                        AS IgstPer,
        ISNULL(l.igstamt, 0)                                        AS IgstAmt,
        ISNULL(l.Tcs_per, 0)                                        AS TcsPer,
        ISNULL(l.Tcs_amt, 0)                                        AS TcsAmt,
        RTRIM(ISNULL(l.cgst_tax_code, ''))                          AS CgstCode,
        RTRIM(ISNULL(l.sgst_tax_code, ''))                          AS SgstCode,
        RTRIM(ISNULL(l.igst_tax_code, ''))                          AS IgstCode,
        RTRIM(ISNULL(l.reqidpo, ''))                                AS RequesterId,
        RTRIM(ISNULL(l.reqnamepo, ''))                              AS RequesterName,
        CASE WHEN ISNULL(l.igstper, 0) > 0 THEN 'IGST' ELSE 'LOCAL' END AS Route,
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    LEFT JOIN dbo.PO_PRL prl
        ON prl.divcode = l.DIVCODE
       AND prl.prno    = l.PRNO
       AND CAST(prl.prdate AS DATE) = CAST(l.PRDATE AS DATE)
       AND prl.prsno   = l.PRSNO
    WHERE l.DIVCODE = @DivCode
      AND l.PORDNO  = @PoNo
      AND CAST(l.PORDDT AS DATE) = @PoDate
    ORDER BY l.PORDSNO;

    -- ─── Result set 3: Delivery slots ─────────────────────────────────────────
    SELECT
        d.PORDSNO                                                   AS [LineNo],
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(l.ORDqty, 0)                                         AS PoQty,
        ROW_NUMBER() OVER (PARTITION BY d.PORDSNO ORDER BY d.shdate) AS SlotNo,
        CASE WHEN d.shdate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(d.shdate AS DATE), 120) END AS ShDate,
        ISNULL(d.Quantity, 0)                                       AS Qty,
        ''                                                          AS Remarks
    FROM dbo.PO_ORDL_DETL d
    INNER JOIN dbo.PO_ORDL l
        ON l.DIVCODE = d.divcode AND l.PORDNO = d.pordno
       AND CAST(l.PORDDT AS DATE) = CAST(d.porddt AS DATE)
       AND l.PORDSNO = d.PORDSNO
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE d.divcode = @DivCode
      AND d.pordno  = @PoNo
      AND CAST(d.porddt AS DATE) = @PoDate
    ORDER BY d.PORDSNO, d.shdate;
END;
GO



-- ============================================================
-- ksp_PO_GetPOHeader
-- Loads a specific PO by divCode + poNo + poDate.
-- Returns 3 result sets: (1) header, (2) lines, (3) delivery slots.
-- Used by Find / post-save / post-delete refresh.
-- Column mapping confirmed against live JAT PO_ORDH schema.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOHeader
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.PO_ORDH
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
    )
    BEGIN
        SELECT NULL AS DivCode WHERE 1 = 0;
        SELECT 0 AS [LineNo] WHERE 1 = 0;
        SELECT 0 AS [LineNo] WHERE 1 = 0;
        RETURN;
    END

    -- ─── Result set 1: Header ─────────────────────────────────────────────────
    SELECT
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(t.TYPNAME, ''))                                AS OrderTypeDesc,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS Supplier,
        RTRIM(ISNULL(sl.slname, ''))                                AS SupplierName,
        RTRIM(ISNULL(h.cust_gstinno, ''))                           AS Gstin,
        CAST(ISNULL(h.cust_gststcode, 0) AS VARCHAR(50))            AS GstState,
        CASE WHEN UPPER(RTRIM(ISNULL(h.INSPECT, 'N'))) = 'Y' THEN 'YES' ELSE 'NO' END AS Inspect,
        ISNULL(h.roff, 0)                                           AS RoundOff,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        RTRIM(ISNULL(h.Form_type, ''))                              AS FormType,
        RTRIM(ISNULL(h.refno, ''))                                  AS RefNo,
        CASE WHEN h.refDate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.refDate AS DATE), 120) END AS RefDate,
        RTRIM(ISNULL(h.CurrCode, ''))                               AS Currency,
        ISNULL(h.FCurRate, 1)                                       AS CurrRate,
        RTRIM(ISNULL(h.REMARKS, ''))                                AS Remarks,
        -- Header GST: PO_ORDH stores amounts only (CGSTAMT/SGSTAMT/IGSTAMT), not percentages
        CAST(0 AS DECIMAL(10,2))                                    AS CgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS IgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.Cessper, 0)                                        AS CessPer,
        CAST(0 AS DECIMAL(10,2))                                    AS AedPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        ISNULL(h.PCKPER, 0)                                         AS PackPer,
        ISNULL(h.INSPER, 0)                                         AS InsurPer,
        ISNULL(h.SURPER, 0)                                         AS SurchargePer,
        ISNULL(h.ADDTAXPER, 0)                                      AS AddTaxPer,
        RTRIM(ISNULL(h.FILENO, ''))                                 AS FileNo,
        ISNULL(h.FCACharg, 0)                                       AS FcaFob,
        CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
        CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        'BEFORE'                                                                              AS CessApp,  -- Cess_Flg excluded: pre-GST retired per FSD v3.1 Stage 3 IST directive (13-Jun-2026)
        -- Payment
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.DIRECT_INS, ''))                             AS DirectInstr,
        RTRIM(ISNULL(h.BANK_CODE, ''))                              AS BankCode,
        RTRIM(ISNULL(h.PAYTERMS, ''))                               AS PaymentTerms,
        ISNULL(h.ADV_PER, 0)                                        AS AdvPer,
        ISNULL(h.ADV_AMT, 0)                                        AS AdvAmt,
        RTRIM(ISNULL(h.advpaymenttype, ''))                         AS ModeOfPayment,
        ''                                                          AS PayRef,
        NULL                                                        AS PayRefDate,
        RTRIM(ISNULL(h.chqno, ''))                                  AS ChequeNo,
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS ChequeDate,
        ISNULL(h.CRDDAYS, 0)                                        AS CreditDays,
        -- Instructions
        CASE WHEN h.Duedate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.Duedate AS DATE), 120) END AS DeliveryDate,
        RTRIM(ISNULL(h.DEL_INS1, ''))                               AS DeliveryLocation,
        RTRIM(ISNULL(h.Billadd, ''))                                AS BillingAddress,
        RTRIM(ISNULL(h.SPL_INS, ''))                                AS SpecialInstr,
        RTRIM(ISNULL(h.DEL_INS2, ''))                               AS Despatch,
        RTRIM(ISNULL(h.Note, ''))                                   AS Purpose,
        ''                                                          AS OtherLevies,
        RTRIM(ISNULL(h.PriceTerm, ''))                              AS PricingTerms,
        RTRIM(ISNULL(h.RemarksPF, ''))                              AS PackForwarding,
        RTRIM(ISNULL(h.RemarksIns, ''))                             AS Insurance,
        RTRIM(ISNULL(h.RemarksFrt, ''))                             AS Freight,
        -- Cancel / status
        RTRIM(ISNULL(h.REMINDER, ''))                               AS Reminder,
        ''                                                          AS Status,
        CAST(CASE WHEN ISNULL(h.CANFLG, '') <> '' THEN 1 ELSE 0 END AS BIT) AS Cancelled,
        CASE WHEN h.CANDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.CANDT AS DATE), 120) END AS CancelDate,
        RTRIM(ISNULL(h.REASON, ''))                                 AS CancelReason,
        RTRIM(ISNULL(h.APPROVED, 'N'))                              AS Approved,
        RTRIM(ISNULL(h.APPBY, ''))                                  AS ApprovedBy,
        -- Amendment
        TRY_CAST(NULLIF(RTRIM(h.AMDORDNO), '') AS DECIMAL(10,0))   AS AmdOrderNo,
        CASE WHEN h.AMDORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.AMDORDDT AS DATE), 120) END AS AmdDate,
        TRY_CAST(NULLIF(RTRIM(h.REFORDNO), '') AS DECIMAL(10,0))   AS AmdRefNo,
        CASE WHEN h.REFORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.REFORDDT AS DATE), 120) END AS AmdRefDate,
        -- Approval / print
        CASE WHEN ISNULL(h.Conflg, 'N') = 'Y' THEN 'CONFIRMED' ELSE 'PENDING' END AS ApprovalStatus,
        RTRIM(ISNULL(h.poprintflg, 'N'))                            AS PrintStatus,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(h.createdby, ''))                              AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        RTRIM(ISNULL(h.createdby, ''))                              AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;

    -- ─── Result set 2: Lines ──────────────────────────────────────────────────
    SELECT
        l.PORDSNO                                                   AS [LineNo],
        l.PRSNO                                                     AS PrSno,
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(CONVERT(varchar(10), CAST(l.PRDATE AS DATE), 120), '') AS PrDate,
        ISNULL(l.Rate, 0)                                           AS Rate,
        ISNULL(l.ORDqty, 0)                                         AS Qty,
        ISNULL(prl.qtyreqd,0) - ISNULL(prl.qtyord,0) - ISNULL(prl.Enq_Qty,0) AS BalanceQty,
        ISNULL(l.ORDVAL, 0)                                         AS Value,
        RTRIM(ISNULL(l.Tax_code, ''))                               AS TaxCode,
        ISNULL(l.taxper, 0)                                         AS TaxPer,
        ISNULL(l.Taxamt, 0)                                         AS TaxAmt,
        RTRIM(ISNULL(l.hsncode, ''))                                AS HsnCode,
        ISNULL(l.cgstper, 0)                                        AS CgstPer,
        ISNULL(l.cgstamt, 0)                                        AS CgstAmt,
        ISNULL(l.sgstper, 0)                                        AS SgstPer,
        ISNULL(l.sgstamt, 0)                                        AS SgstAmt,
        ISNULL(l.igstper, 0)                                        AS IgstPer,
        ISNULL(l.igstamt, 0)                                        AS IgstAmt,
        ISNULL(l.Tcs_per, 0)                                        AS TcsPer,
        ISNULL(l.Tcs_amt, 0)                                        AS TcsAmt,
        RTRIM(ISNULL(l.cgst_tax_code, ''))                          AS CgstCode,
        RTRIM(ISNULL(l.sgst_tax_code, ''))                          AS SgstCode,
        RTRIM(ISNULL(l.igst_tax_code, ''))                          AS IgstCode,
        RTRIM(ISNULL(l.reqidpo, ''))                                AS RequesterId,
        RTRIM(ISNULL(l.reqnamepo, ''))                              AS RequesterName,
        CASE WHEN ISNULL(l.igstper, 0) > 0 THEN 'IGST' ELSE 'LOCAL' END AS Route,
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    LEFT JOIN dbo.PO_PRL prl
        ON prl.divcode = l.DIVCODE
       AND prl.prno    = l.PRNO
       AND CAST(prl.prdate AS DATE) = CAST(l.PRDATE AS DATE)
       AND prl.prsno   = l.PRSNO
    WHERE l.DIVCODE = @DivCode
      AND l.PORDNO  = @PoNo
      AND CAST(l.PORDDT AS DATE) = @PoDate
    ORDER BY l.PORDSNO;

    -- ─── Result set 3: Delivery slots ─────────────────────────────────────────
    SELECT
        d.PORDSNO                                                   AS [LineNo],
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(l.ORDqty, 0)                                         AS PoQty,
        ROW_NUMBER() OVER (PARTITION BY d.PORDSNO ORDER BY d.shdate) AS SlotNo,
        CASE WHEN d.shdate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(d.shdate AS DATE), 120) END AS ShDate,
        ISNULL(d.Quantity, 0)                                       AS Qty,
        ''                                                          AS Remarks
    FROM dbo.PO_ORDL_DETL d
    INNER JOIN dbo.PO_ORDL l
        ON l.DIVCODE = d.divcode AND l.PORDNO = d.pordno
       AND CAST(l.PORDDT AS DATE) = CAST(d.porddt AS DATE)
       AND l.PORDSNO = d.PORDSNO
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE d.divcode = @DivCode
      AND d.pordno  = @PoNo
      AND CAST(d.porddt AS DATE) = @PoDate
    ORDER BY d.PORDSNO, d.shdate;
END;
GO



-- ============================================================
-- ksp_PO_GetPrint
-- Returns print data for a PO (PDF generation via QuestPDF).
-- Returns 2 result sets: (1) header with division letterhead,
--                        (2) PO lines.
-- PP_DIVMAS confirmed columns: div_printname, PHONE1, gstinno,
--   add1, add2, add3, pincode, email — all verified.
-- FA_SLMAS confirmed columns: add1, add2, state, gstinno (lowercase). add3/city/pin unverified.
-- PO_ORDH: GST % columns don't exist — amounts only.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPrint
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── Result set 1: Print header (div letterhead + PO header) ──────────────
    SELECT
        -- Division letterhead
        div.DIV_LOGO                                                AS DivLogo,
        RTRIM(ISNULL(div.divname, ''))                              AS DivName,
        RTRIM(ISNULL(div.div_printname, div.divname))               AS DivPrintName,
        RTRIM(ISNULL(div.div_unitname, ''))                         AS DivUnitName,
        RTRIM(ISNULL(div.add1, ''))                                 AS DivAddress1,
        RTRIM(ISNULL(div.add2, ''))                                 AS DivAddress2,
        RTRIM(ISNULL(div.add3, ''))                                 AS DivAddress3,
        RTRIM(ISNULL(div.pincode, ''))                              AS DivPinCode,
        RTRIM(ISNULL(div.PHONE1, ''))                               AS DivPhone,
        RTRIM(ISNULL(div.email, ''))                                AS DivEmail,
        RTRIM(ISNULL(div.gstinno, ''))                              AS DivGstin,
        RTRIM(ISNULL(div.PAN, ''))                                  AS DivPan,
        RTRIM(ISNULL(div.WEBADDR, ''))                              AS DivWeb,
        -- PO header
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS SlCode,
        RTRIM(ISNULL(sl.slname, ''))                                AS SlName,
        RTRIM(ISNULL(sl.add1, '')) +
            CASE WHEN RTRIM(ISNULL(sl.add2,  '')) <> '' THEN ', ' + RTRIM(sl.add2)  ELSE '' END +
            CASE WHEN RTRIM(ISNULL(sl.state, '')) <> '' THEN ', ' + RTRIM(sl.state) ELSE '' END
                                                                     AS SlAddress,
        RTRIM(ISNULL(sl.gstinno, ''))                               AS SlGstin,
        RTRIM(ISNULL(sl.phone1, ''))                                AS SlPhone,
        RTRIM(ISNULL(sl.email, ''))                                 AS SlEmail,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(car.CARNAME, h.CARCODE))                       AS Carrier,
        RTRIM(ISNULL(h.CurrCode, ''))                               AS Currency,
        ISNULL(h.FCurRate, 1)                                       AS CurrRate,
        ISNULL(h.CRDDAYS, 0)                                        AS CreditDays,
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.REMARKS, ''))                                AS Remarks,
        -- PO_ORDH has no GST % columns — amounts only
        CAST(0 AS DECIMAL(10,2))                                    AS CgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS IgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        ISNULL(h.roff, 0)                                           AS RoundOff,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(h.createdby, ''))                              AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        -- Additional fields for V2 print
        RTRIM(ISNULL(h.refno, ''))                                  AS RefNo,
        CASE WHEN h.refDate IS NULL THEN ''
             ELSE CONVERT(varchar(10), h.refDate, 103) END          AS RefDate,
        CASE WHEN h.Duedate IS NULL THEN ''
             ELSE CONVERT(varchar(10), h.Duedate, 103) END          AS DeliveryDate,
        RTRIM(ISNULL(h.Note, ''))                                   AS Purpose,
        RTRIM(ISNULL(h.paytermcode, ''))                            AS PayTerms,
        ISNULL(h.Ins_Amt, 0)                                        AS InsAmt,
        ISNULL(h.Pack_Amt, 0)                                       AS PackAmt,
        LEFT(ISNULL(div.gstinno, ''), 2)                            AS DivStateCode,
        LEFT(ISNULL(sl.gstinno, ''), 2)                             AS SlStateCode
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.pp_divmas div
        ON RTRIM(div.divcode) = RTRIM(h.DIVCODE)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    LEFT JOIN dbo.PO_CAR car
        ON RTRIM(car.CARCODE) = RTRIM(h.CARCODE)
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;

    -- ─── Result set 2: Print lines ────────────────────────────────────────────
    SELECT
        l.PORDSNO                                                   AS [LineNo],
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        RTRIM(ISNULL(l.hsncode, ''))                                AS HsnCode,
        l.PRNO                                                      AS PrNo,
        l.PRSNO                                                     AS PrSno,
        ISNULL(l.ORDqty, 0)                                         AS Qty,
        ISNULL(l.Rate, 0)                                           AS Rate,
        ISNULL(l.ORDVAL, 0)                                         AS Value,
        RTRIM(ISNULL(l.Tax_code, ''))                               AS TaxCode,
        ISNULL(l.taxper, 0)                                         AS TaxPer,
        ISNULL(l.Taxamt, 0)                                         AS TaxAmt,
        ISNULL(l.cgstper, 0)                                        AS CgstPer,
        ISNULL(l.cgstamt, 0)                                        AS CgstAmt,
        ISNULL(l.sgstper, 0)                                        AS SgstPer,
        ISNULL(l.sgstamt, 0)                                        AS SgstAmt,
        ISNULL(l.igstper, 0)                                        AS IgstPer,
        ISNULL(l.igstamt, 0)                                        AS IgstAmt,
        ISNULL(l.Tcs_per, 0)                                        AS TcsPer,
        ISNULL(l.Tcs_amt, 0)                                        AS TcsAmt,
        ISNULL(l.disper, 0)                                         AS LineDis,
        ISNULL(l.disamt, 0)                                         AS LineDisAmt
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE l.DIVCODE = @DivCode
      AND l.PORDNO  = @PoNo
      AND CAST(l.PORDDT AS DATE) = @PoDate
    ORDER BY l.PORDSNO;
END;
GO




-- ============================================================
-- PREREQUISITE: PO Number Sequence (CEO confirmed 07-Jun-2026)
-- Run ONCE on JAT DB before deploying ksp_PO_SaveEntry.
-- If the sequence already exists, this is a no-op.
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_PO_AllocatePONo' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    -- Seed the sequence from the current MAX PORDNO so no gaps or conflicts occur.
    DECLARE @SeqStart BIGINT = 1;
    SELECT @SeqStart = ISNULL(MAX(PORDNO), 0) + 1 FROM dbo.PO_ORDH;
    DECLARE @sql NVARCHAR(500) = N'CREATE SEQUENCE dbo.seq_PO_AllocatePONo AS BIGINT START WITH ' + CAST(@SeqStart AS NVARCHAR(20)) + N' INCREMENT BY 1 NO CACHE;';
    EXEC sp_executesql @sql;
END
GO


-- ============================================================
-- ksp_PO_SaveEntry
-- Converts approved PR lines into a Purchase Order (ADD only).
-- Atomic transaction: header + lines + delivery slots + PR update.
-- Column names verified against live JAT schema via ksp_PO_GetLastPO.
-- JSON keys are camelCase (C# JsonNamingPolicy.CamelCase).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SaveEntry
(
    -- Header
    @DivCode          VARCHAR(2),
    @PoDate           DATE,
    @OrderType        VARCHAR(5),
    @Supplier         VARCHAR(10),
    @Currency         VARCHAR(3),
    @CurrRate         NUMERIC(13,4)  = 1,
    @Carrier          VARCHAR(10),
    @Inspect          VARCHAR(5)     = NULL,
    @FormType         VARCHAR(10)    = NULL,
    @RefNo            VARCHAR(30)    = NULL,
    @RefDate          DATE           = NULL,
    @Remarks          VARCHAR(500)   = NULL,
    -- Tax / Discount
    @CgstPer          NUMERIC(10,2)  = 0,
    @SgstPer          NUMERIC(10,2)  = 0,
    @IgstPer          NUMERIC(10,2)  = 0,
    @TcsPer           NUMERIC(10,2)  = 0,
    @DiscPer          NUMERIC(10,2)  = 0,
    @CessPer          NUMERIC(10,2)  = 0,
    @AedPer           NUMERIC(10,2)  = 0,    -- legacy pass-through (D-11)
    @FreightAmt       NUMERIC(13,2)  = 0,
    @PackPer          NUMERIC(10,2)  = 0,
    @InsurPer         NUMERIC(10,2)  = 0,
    @SurchargePer     NUMERIC(10,2)  = 0,
    @AddTaxPer        NUMERIC(10,2)  = 0,
    @FileNo           VARCHAR(20)    = NULL,
    @FcaFob           NUMERIC(13,2)  = 0,
    @FreightType      VARCHAR(10)    = 'PAID',
    @DiscApp          VARCHAR(10)    = 'BEFORE',  -- disflg: 'BEFORE'→'B', 'AFTER'→'A' (wired 16-Jun-2026)
    @PackApp          VARCHAR(10)    = 'BEFORE',  -- PACK_FLG: 'BEFORE'→'B', 'AFTER'→'A' (wired 16-Jun-2026)
    @CessApp          VARCHAR(10)    = 'BEFORE',  -- Cess_Flg excluded: pre-GST retired per FSD v3.1 Stage 3 IST directive (13-Jun-2026). Not wired in SPINRISE.
    -- Payment
    @PayMode          VARCHAR(10)    = 'DIRECT',
    @DirectInstr      VARCHAR(200)   = NULL,
    @BankCode         VARCHAR(10)    = NULL,
    @PaymentTerms     VARCHAR(100)   = NULL,
    @AdvPer           NUMERIC(10,2)  = 0,
    @AdvAmt           NUMERIC(13,2)  = 0,
    @ModeOfPayment    VARCHAR(20)    = NULL,
    @PayRef           VARCHAR(50)    = NULL,   -- no column in PO_ORDH; accepted, not stored
    @PayRefDate       DATE           = NULL,   -- no column in PO_ORDH; accepted, not stored
    @ChequeNo         VARCHAR(50)    = NULL,
    @ChequeDate       DATE           = NULL,
    -- Instructions
    @CreditDays       INT            = 0,
    @DeliveryDate     DATE           = NULL,
    @DeliveryLocation VARCHAR(200)   = NULL,
    @BillingAddress   VARCHAR(200)   = NULL,
    @SpecialInstr     VARCHAR(500)   = NULL,
    @Despatch         VARCHAR(200)   = NULL,
    @Purpose          VARCHAR(500)   = NULL,
    @OtherLevies      VARCHAR(200)   = NULL,   -- no confirmed column; accepted, not stored
    @PricingTerms     VARCHAR(100)   = NULL,
    @PackForwarding   VARCHAR(200)   = NULL,
    @Insurance        VARCHAR(200)   = NULL,
    @Freight          VARCHAR(200)   = NULL,
    -- Lines (camelCase JSON; each element has a nested $.slots array)
    @LinesJson        NVARCHAR(MAX),
    -- Financial year bounds
    @FDate            DATE,
    @LDate            DATE,
    -- Audit
    @UserId           VARCHAR(50),
    @HostName         VARCHAR(100)   = NULL,
    @IpAddress        VARCHAR(50)    = NULL,
    -- Output
    @PoNo             NUMERIC(10,0)  OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 0. FY date guard ─────────────────────────────────────────────────────
        IF @PoDate < @FDate OR @PoDate > @LDate
            RAISERROR('PO Date is outside the open financial year. Please select a date within the current financial year.', 16, 1);

        -- ── 1. Header mandatory fields (BR-11, BR-12, BR-13, BR-14) ─────────────
        IF RTRIM(ISNULL(@OrderType, '')) = ''
            RAISERROR('Purchase Type Cannot be empty', 16, 1);
        IF RTRIM(ISNULL(@Supplier, '')) = ''
            RAISERROR('Party Cannot be empty', 16, 1);
        IF RTRIM(ISNULL(@Currency, '')) = ''
            RAISERROR('Currency Cannot be empty', 16, 1);
        IF RTRIM(ISNULL(@Carrier, '')) = ''
            RAISERROR('Carrier Cannot be empty', 16, 1);

        -- ── 2. BR-15: Bank mode requires BankCode + ChequeNo; HO requires PricingTerms
        IF UPPER(RTRIM(ISNULL(@PayMode, ''))) = 'BANK'
        BEGIN
            IF RTRIM(ISNULL(@BankCode, '')) = ''
                RAISERROR('Bank Code Cannot be empty', 16, 1);
            IF RTRIM(ISNULL(@ChequeNo, '')) = ''
                RAISERROR('Cheque No. Cannot be empty', 16, 1);
        END

        IF UPPER(RTRIM(ISNULL(@OrderType, ''))) = 'HO'
            AND RTRIM(ISNULL(@PricingTerms, '')) = ''
            RAISERROR('Pricing Term Cannot be empty', 16, 1);

        -- ── 3. BR-01: Backdate check (FSD §4.6) ─────────────────────────────────
        -- When BACKDATE='N', PO date must equal today OR the max existing PO date.
        DECLARE @BackDate CHAR(1) = 'Y';
        SELECT TOP 1 @BackDate = ISNULL(UPPER(RTRIM(BACKDATE)), 'Y') FROM dbo.IN_PARA;

        IF @BackDate <> 'Y'
        BEGIN
            DECLARE @ProcessingDate DATE = CAST(GETDATE() AS DATE);
            DECLARE @MaxPoDate      DATE;
            SELECT @MaxPoDate = CAST(MAX(PORDDT) AS DATE) FROM dbo.PO_ORDH WHERE DIVCODE = @DivCode;

            IF @PoDate <> @ProcessingDate
               AND NOT (@MaxPoDate IS NOT NULL AND @PoDate = @MaxPoDate)
                RAISERROR('PO Date must be equal to Current Date Or Max Purchase Order Date.', 16, 1);
        END

        -- ── 4. Parse lines JSON into temp table (one row per line) ───────────────
        --    SlotsJson captured AS JSON for the nested delivery OPENJSON pass.
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NUMERIC(4,0)) AS PORDSNO,
            j.PrNo,
            j.PrSno,
            j.PrDate,
            RTRIM(j.ItemCode)           AS ItemCode,
            j.Rate,
            j.Qty,
            RTRIM(ISNULL(j.TaxCode,'')) AS TaxCode,
            RTRIM(ISNULL(j.HsnCode,'')) AS HsnCode,
            ISNULL(j.CgstPer, 0)        AS CgstPer,
            ISNULL(j.SgstPer, 0)        AS SgstPer,
            ISNULL(j.IgstPer, 0)        AS IgstPer,
            ISNULL(j.TcsPer,  0)        AS TcsPer,
            RTRIM(ISNULL(j.CgstCode,'')) AS CgstCode,
            RTRIM(ISNULL(j.SgstCode,'')) AS SgstCode,
            RTRIM(ISNULL(j.IgstCode,''))     AS IgstCode,
            RTRIM(ISNULL(j.RequesterId,''))  AS RequesterId,
            RTRIM(ISNULL(j.RequesterName,'')) AS RequesterName,
            j.SlotsJson
        INTO #Lines
        FROM OPENJSON(@LinesJson)
        WITH (
            PrNo          NUMERIC(6,0)   '$.prNo',
            PrSno         NUMERIC(6,0)   '$.prSno',
            PrDate        DATE           '$.prDate',
            ItemCode      VARCHAR(10)    '$.itemCode',
            Rate          NUMERIC(13,4)  '$.rate',
            Qty           NUMERIC(12,3)  '$.qty',
            TaxCode       VARCHAR(10)    '$.taxCode',
            HsnCode       VARCHAR(20)    '$.hsnCode',
            CgstPer       NUMERIC(10,2)  '$.cgstPer',
            SgstPer       NUMERIC(10,2)  '$.sgstPer',
            IgstPer       NUMERIC(10,2)  '$.igstPer',
            TcsPer        NUMERIC(10,2)  '$.tcsPer',
            CgstCode      VARCHAR(10)    '$.cgstCode',
            SgstCode      VARCHAR(10)    '$.sgstCode',
            IgstCode      VARCHAR(10)    '$.igstCode',
            RequesterId   VARCHAR(20)    '$.requesterId',
            RequesterName VARCHAR(100)   '$.requesterName',
            SlotsJson     NVARCHAR(MAX)  '$.slots' AS JSON
        ) j
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

        -- ── 5. Line-level validations ────────────────────────────────────────────
        IF NOT EXISTS (SELECT 1 FROM #Lines)
            RAISERROR('One item required to save the order', 16, 1);

        -- BR-06: qty > 0
        IF EXISTS (SELECT 1 FROM #Lines WHERE Qty <= 0)
            RAISERROR('Order Quantity cannot be empty', 16, 1);

        -- BR-07: rate > 0
        IF EXISTS (SELECT 1 FROM #Lines WHERE Rate <= 0)
            RAISERROR('Please Enter Order Rate', 16, 1);

        -- BR-08: tax code not empty
        IF EXISTS (SELECT 1 FROM #Lines WHERE TaxCode = '')
            RAISERROR('TaxCode cannot be empty', 16, 1);

        -- BR-10: HSN code not empty (check both JSON and item master)
        DECLARE @HsnError NVARCHAR(500);
        SELECT TOP 1 @HsnError =
            'The HSN Code is not available for this Item : ' + RTRIM(ISNULL(i.itemname, l.ItemCode))
        FROM #Lines l
        INNER JOIN dbo.IN_ITEM i ON i.itemcode = l.ItemCode
        WHERE l.HsnCode = '' AND RTRIM(ISNULL(i.hsncode, '')) = '';

        IF @HsnError IS NOT NULL
            RAISERROR(@HsnError, 16, 1);

        -- BR-05: ordered qty <= PR balance (QTYREQD - QTYORD - enq_qty)
        DECLARE @QtyError NVARCHAR(500);
        SELECT TOP 1 @QtyError =
            'The Ordered Quantity cannot be greater than ' +
            LTRIM(STR(
                ISNULL(prl.QTYREQD, 0) - ISNULL(prl.QTYORD, 0) - ISNULL(prl.enq_qty, 0),
                12, 3))
        FROM #Lines l
        INNER JOIN dbo.PO_PRL prl
            ON prl.divcode = @DivCode AND prl.prno = l.PrNo
           AND CAST(prl.prdate AS DATE) = l.PrDate AND prl.prsno = l.PrSno
        WHERE l.Qty > (ISNULL(prl.QTYREQD, 0) - ISNULL(prl.QTYORD, 0) - ISNULL(prl.enq_qty, 0));

        IF @QtyError IS NOT NULL
            RAISERROR(@QtyError, 16, 1);

        -- BR-09: GST code active-status check (ig_tax.TAXSTATUS = 'Y')
        IF EXISTS (
            SELECT 1 FROM #Lines l
            LEFT JOIN dbo.IG_TAX cg ON RTRIM(cg.TAX_CODE) = RTRIM(l.CgstCode)
            LEFT JOIN dbo.IG_TAX sg ON RTRIM(sg.TAX_CODE) = RTRIM(l.SgstCode)
            LEFT JOIN dbo.IG_TAX ig ON RTRIM(ig.TAX_CODE) = RTRIM(l.IgstCode)
            WHERE (l.CgstCode <> '' AND UPPER(ISNULL(cg.TAXSTATUS, '')) <> 'Y')
               OR (l.SgstCode <> '' AND UPPER(ISNULL(sg.TAXSTATUS, '')) <> 'Y')
               OR (l.IgstCode <> '' AND UPPER(ISNULL(ig.TAXSTATUS, '')) <> 'Y')
        )
            RAISERROR('One or more GST tax codes are inactive. Please select an active code.', 16, 1);

        -- BR-02: Re-verify PR line eligibility at save time (race condition guard)
        IF EXISTS (
            SELECT 1 FROM #Lines l
            INNER JOIN dbo.PO_PRL prl
                ON prl.divcode = @DivCode AND prl.prno = l.PrNo
               AND CAST(prl.prdate AS DATE) = l.PrDate AND prl.prsno = l.PrSno
            WHERE ISNULL(prl.DirectApp, 'N') <> 'Y'
               OR ISNULL(prl.FClosed,   'N') =  'Y'
        )
            RAISERROR('One or more PR lines are no longer eligible for ordering.', 16, 1);

        -- ── 6. Allocate PO number (atomic SEQUENCE — CEO confirmed 07-Jun-2026) ──
        -- SEQUENCE guarantees uniqueness under concurrent users (no race condition).
        -- Prerequisite: dbo.seq_PO_AllocatePONo must exist in JAT DB.
        --   CREATE SEQUENCE dbo.seq_PO_AllocatePONo START WITH 1 INCREMENT BY 1;
        SET @PoNo = NEXT VALUE FOR dbo.seq_PO_AllocatePONo;

        -- Floor to PO_DOC_PARA.STDOCNO if the sequence has not yet reached the starting number.
        DECLARE @StartDocNo NUMERIC(10,0) = 1;
        SELECT @StartDocNo = ISNULL(STDOCNO, 1)
        FROM dbo.PO_DOC_PARA
        WHERE TC = 'PURCHASE ORDER';

        IF @PoNo < @StartDocNo
            SET @PoNo = @StartDocNo;

        -- ── 7a. Division approval parameters (FSD §5.8 / §5.9) ────────────────
        -- If PoFirstLevelApp='N', auto-approve first level on save.
        -- Conflg: If PoConf='N' (no confirmation step required), auto-confirm.
        DECLARE @PoFirstLevelApp CHAR(1) = 'Y';
        DECLARE @PoConf          CHAR(1) = 'N';
        SELECT TOP 1
            @PoFirstLevelApp = ISNULL(UPPER(RTRIM(PoFirstLevelApp)), 'Y'),
            @PoConf          = ISNULL(UPPER(RTRIM(Po_Confirm)),       'N')
        FROM dbo.PO_PARA
        WHERE divcode = @DivCode;

        DECLARE @FirstLevelApp VARCHAR(1) = CASE WHEN @PoFirstLevelApp = 'N' THEN 'Y' ELSE 'N' END;
        DECLARE @Conflg        VARCHAR(1) = CASE WHEN @PoConf          = 'N' THEN 'Y' ELSE 'N' END;

        -- ── 7. Derived values ────────────────────────────────────────────────────
        DECLARE @OrdVal  NUMERIC(18,2);
        DECLARE @CgstAmt NUMERIC(18,2);
        DECLARE @SgstAmt NUMERIC(18,2);
        DECLARE @IgstAmt NUMERIC(18,2);
        SELECT
            @OrdVal  = SUM(ROUND(Rate * Qty, 2)),
            @CgstAmt = SUM(ROUND((Rate * Qty) * CgstPer / 100.0, 2)),
            @SgstAmt = SUM(ROUND((Rate * Qty) * SgstPer / 100.0, 2)),
            @IgstAmt = SUM(ROUND((Rate * Qty) * IgstPer / 100.0, 2))
        FROM #Lines;

        -- Supplier GSTIN + state code (authoritative from master, not client-sent)
        DECLARE @SupGstin    VARCHAR(50)   = NULL;
        DECLARE @SupGstState NUMERIC(10,0) = 0;
        SELECT TOP 1
            @SupGstin    = RTRIM(ISNULL(GSTINNO, '')),
            @SupGstState = TRY_CAST(ISNULL(gststatecode, '0') AS NUMERIC(10,0))
        FROM dbo.FA_SLMAS
        WHERE RTRIM(slcode) = RTRIM(@Supplier);

        DECLARE @CreatedDt DATETIME = GETDATE();

        -- ── 8. INSERT PO_ORDH ────────────────────────────────────────────────────
        INSERT INTO dbo.PO_ORDH
        (
            DIVCODE,   PORDNO,  PORDDT,  POGRP,    SLCODE,
            CurrCode,  FCurRate, CARCODE, INSPECT,
            Form_type, refno,   refDate, REMARKS,
            DISPER, Cessper, FREIGHT, PCKPER, INSPER, SURPER, ADDTAXPER,
            FILENO, FCACharg, FRTFLG, disflg, PACK_FLG,
            PAYMENT, DIRECT_INS, BANK_CODE, PAYTERMS,
            ADV_PER, ADV_AMT, advpaymenttype,
            CHQNO, CHQDT, CRDDAYS,
            Duedate, DEL_INS1, Billadd, SPL_INS, DEL_INS2,
            Note, PriceTerm, RemarksPF, RemarksIns, RemarksFrt,
            ORDVAL, roff,
            CGSTAMT, SGSTAMT, IGSTAMT,
            cust_gstinno, cust_gststcode,
            FirstlevelApp, Conflg, poprintflg,
            createdby, createddt
        )
        VALUES
        (
            @DivCode, @PoNo, @PoDate, @OrderType, @Supplier,
            @Currency,
            ISNULL(@CurrRate, 1),
            @Carrier,
            CASE WHEN UPPER(RTRIM(ISNULL(@Inspect,''))) IN ('YES','Y') THEN 'Y' ELSE 'N' END,
            NULLIF(RTRIM(ISNULL(@FormType,'')),     ''),
            NULLIF(RTRIM(ISNULL(@RefNo,'')),        ''),
            @RefDate,
            NULLIF(RTRIM(ISNULL(@Remarks,'')),      ''),
            ISNULL(@DiscPer,      0),
            ISNULL(@CessPer,      0),
            ISNULL(@FreightAmt,   0),
            ISNULL(@PackPer,      0),
            ISNULL(@InsurPer,     0),
            ISNULL(@SurchargePer, 0),
            ISNULL(@AddTaxPer,    0),
            NULLIF(RTRIM(ISNULL(@FileNo,'')),       ''),
            ISNULL(@FcaFob, 0),
            CASE WHEN UPPER(RTRIM(ISNULL(@FreightType,''))) = 'TOPAY' THEN 'Y' ELSE '' END,
            CASE WHEN UPPER(RTRIM(ISNULL(@DiscApp,'')))    = 'AFTER' THEN 'A' ELSE 'B' END,  -- disflg
            CASE WHEN UPPER(RTRIM(ISNULL(@PackApp,'')))    = 'AFTER' THEN 'A' ELSE 'B' END,  -- PACK_FLG
            CASE WHEN UPPER(RTRIM(ISNULL(@PayMode,''))) = 'BANK' THEN 'B' ELSE 'D' END,
            NULLIF(RTRIM(ISNULL(@DirectInstr,'')),  ''),
            NULLIF(RTRIM(ISNULL(@BankCode,'')),     ''),
            NULLIF(RTRIM(ISNULL(@PaymentTerms,'')), ''),
            ISNULL(@AdvPer, 0),
            ISNULL(@AdvAmt, 0),
            NULLIF(RTRIM(ISNULL(@ModeOfPayment,'')), ''),
            NULLIF(RTRIM(ISNULL(@ChequeNo,'')),     ''),
            @ChequeDate,
            ISNULL(@CreditDays, 0),
            @DeliveryDate,
            NULLIF(RTRIM(ISNULL(@DeliveryLocation,'')), ''),
            NULLIF(RTRIM(ISNULL(@BillingAddress,'')),   ''),
            NULLIF(RTRIM(ISNULL(@SpecialInstr,'')),     ''),
            NULLIF(RTRIM(ISNULL(@Despatch,'')),         ''),
            NULLIF(RTRIM(ISNULL(@Purpose,'')),          ''),
            NULLIF(RTRIM(ISNULL(@PricingTerms,'')),     ''),
            NULLIF(RTRIM(ISNULL(@PackForwarding,'')),   ''),
            NULLIF(RTRIM(ISNULL(@Insurance,'')),        ''),
            NULLIF(RTRIM(ISNULL(@Freight,'')),          ''),
            ISNULL(@OrdVal, 0),
            0,                        -- roff: round-off (computed by client, stored as 0 here)
            ISNULL(@CgstAmt, 0),
            ISNULL(@SgstAmt, 0),
            ISNULL(@IgstAmt, 0),
            @SupGstin,
            @SupGstState,
            @FirstLevelApp,           -- 'Y' if PoFirstLevelApp='N', else 'N'
            @Conflg,                  -- 'Y' if PoConf='N' (auto-confirm), else 'N'
            'N',                      -- poprintflg
            @UserId,
            @CreatedDt
        );

        -- FSD §14: Reset amendment/cancellation flags on every new save
        UPDATE dbo.PO_ORDH
        SET AMDORDNO = NULL, CANFLG = NULL
        WHERE DIVCODE = @DivCode AND PORDNO = @PoNo;

        -- ── 8b. Read back the actual PORDDT stored in PO_ORDH after any triggers/defaults.
        --       PO_ORDL and PO_ORDL_DETL must use this exact value so that the
        --       insposup trigger (which joins PO_ORDH on exact porddt) can find the row.
        DECLARE @ActualPoDt DATETIME;
        SELECT @ActualPoDt = PORDDT FROM dbo.PO_ORDH WHERE DIVCODE = @DivCode AND PORDNO = @PoNo;

        -- ── 9. INSERT PO_ORDL (one row per line) ─────────────────────────────────
        --    taxper = CgstPer + SgstPer + IgstPer (total GST %)
        --    Amounts computed from Rate × Qty × per% / 100
        INSERT INTO dbo.PO_ORDL
        (
            DIVCODE,  PORDNO,  PORDDT, PORDSNO, POGRP,
            ITEMCODE, PRNO,    PRDATE, PRSNO,
            Rate,     ORDqty,  ORDVAL,
            Tax_code, taxper,  Taxamt,
            hsncode,
            cgstper,  cgstamt,  cgst_tax_code,
            sgstper,  sgstamt,  sgst_tax_code,
            igstper,  igstamt,  igst_tax_code,
            Tcs_per,  Tcs_amt,
            reqidpo,  reqnamepo
        )
        SELECT
            @DivCode, @PoNo, @ActualPoDt, l.PORDSNO, @OrderType,
            l.ItemCode,
            l.PrNo,
            prl.prdate,
            l.PrSno,
            l.Rate,
            l.Qty,
            ROUND(l.Rate * l.Qty, 2),
            LEFT(l.TaxCode,  5),  -- PO_ORDL.TAX_CODE is varchar(5)
            l.CgstPer + l.SgstPer + l.IgstPer,
            ROUND((l.Rate * l.Qty) * (l.CgstPer + l.SgstPer + l.IgstPer) / 100.0, 2),
            LEFT(l.HsnCode,  8),  -- PO_ORDL.hsncode is varchar(8)
            l.CgstPer,
            ROUND((l.Rate * l.Qty) * l.CgstPer / 100.0, 2),
            LEFT(l.CgstCode, 5),  -- PO_ORDL.cgst_tax_code is varchar(5)
            l.SgstPer,
            ROUND((l.Rate * l.Qty) * l.SgstPer / 100.0, 2),
            LEFT(l.SgstCode, 5),  -- PO_ORDL.sgst_tax_code is varchar(5)
            l.IgstPer,
            ROUND((l.Rate * l.Qty) * l.IgstPer / 100.0, 2),
            LEFT(l.IgstCode, 5),  -- PO_ORDL.igst_tax_code is varchar(5)
            l.TcsPer,
            ROUND((l.Rate * l.Qty) * l.TcsPer / 100.0, 2),
            NULLIF(l.RequesterId, ''),
            NULLIF(l.RequesterName, '')
        FROM #Lines l
        INNER JOIN dbo.PO_PRL prl
            ON prl.divcode = @DivCode AND prl.prno = l.PrNo
           AND CAST(prl.prdate AS DATE) = l.PrDate AND prl.prsno = l.PrSno;

        -- Guard: every line in #Lines must have produced an insert row.
        -- A mismatch means the PO_PRL join found no match (divcode/prdate mismatch).
        DECLARE @LinesInserted INT = @@ROWCOUNT;
        DECLARE @LinesExpected INT = (SELECT COUNT(*) FROM #Lines);
        IF @LinesInserted <> @LinesExpected
            RAISERROR('PO line save incomplete: %d of %d PR lines were matched in PO_PRL. Refresh the PR picker and retry.', 16, 1, @LinesInserted, @LinesExpected);

        -- ── 10. INSERT PO_ORDL_DETL (delivery slots, up to 4 per line) ────────────
        --     OPENJSON(NULL) safely returns 0 rows, so no extra NULL guard needed.

        -- Cap: max 4 slots per line (FSD Handover §6.3)
        IF EXISTS (
            SELECT 1
            FROM #Lines l
            CROSS APPLY OPENJSON(l.SlotsJson) WITH (qty NUMERIC(12,3) '$.qty') s
            WHERE l.SlotsJson IS NOT NULL
            GROUP BY l.PORDSNO
            HAVING COUNT(*) > 4
        )
            RAISERROR('Maximum 4 delivery slots are allowed per order line.', 16, 1);

        -- Reconciliation: slot qty total must equal line ordered qty
        IF EXISTS (
            SELECT 1
            FROM #Lines l
            CROSS APPLY (
                SELECT SUM(s.qty) AS SlotTotal
                FROM OPENJSON(l.SlotsJson) WITH (qty NUMERIC(12,3) '$.qty') s
                WHERE s.qty > 0
            ) st
            WHERE l.SlotsJson IS NOT NULL
              AND st.SlotTotal IS NOT NULL
              AND ABS(st.SlotTotal - l.Qty) > 0.001
        )
            RAISERROR('Delivery slot quantities must sum to the ordered quantity for each line.', 16, 1);

        INSERT INTO dbo.PO_ORDL_DETL
        (divcode, pordno, porddt, pordsno, pogrp, itemcode, shdate, Quantity)
        SELECT
            @DivCode, @PoNo, @ActualPoDt,
            l.PORDSNO,
            @OrderType,
            l.ItemCode,
            TRY_CAST(NULLIF(RTRIM(ISNULL(s.shDate, '')), '') AS DATE),
            s.qty
        FROM #Lines l
        CROSS APPLY OPENJSON(l.SlotsJson)
        WITH (
            shDate  NVARCHAR(10)  '$.shDate',
            qty     NUMERIC(12,3) '$.qty'
        ) s
        WHERE s.qty > 0
          AND TRY_CAST(NULLIF(RTRIM(ISNULL(s.shDate, '')), '') AS DATE) IS NOT NULL;

        -- ── 11. UPDATE PO_PRL — increment QTYORD, mark as ordered ────────────────
        UPDATE prl
        SET
            QTYORD   = ISNULL(prl.QTYORD, 0) + l.Qty,
            PRSTATUS = 'O'
        FROM dbo.PO_PRL prl
        INNER JOIN #Lines l
            ON prl.divcode = @DivCode AND prl.prno = l.PrNo
           AND CAST(prl.prdate AS DATE) = l.PrDate AND prl.prsno = l.PrSno;

        DROP TABLE #Lines;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID('tempdb..#Lines') IS NOT NULL
            DROP TABLE #Lines;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev INT            = ERROR_SEVERITY();
        RAISERROR(@ErrMsg, @ErrSev, 1);
    END CATCH
END;
GO

-- ============================================================
-- ksp_PO_DeletePO
-- Deletes a PO (FULL mode for PR→PO Transfer screen).
-- Flow:
--   1. BR-03: GRN guard — blocks delete if GRN raised (IN_TRNTAIL).
--      RAISERROR contains "GRN" — C# catches this and returns HTTP 409.
--   2. BR-04: All line delete reasons must be non-empty.
--   3. Write audit row to LogDet_PO.
--   4. Reverse QTYORD on PO_PRL (restore PR balance).
--   5. Cascade delete: PO_ORDL_DETL → PO_ORDL → PO_ORDH.
-- All steps in one atomic transaction (THROW re-raises on error).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DeletePO
(
    @DivCode         VARCHAR(2),
    @PoNo            NUMERIC(10,0),
    @PoDate          DATE,
    @DeleteMode      VARCHAR(10),
    @DefaultReason   NVARCHAR(500),
    @LineReasonsJson NVARCHAR(MAX),
    @UserId          VARCHAR(20),
    @HostName        VARCHAR(100) = NULL,
    @IpAddress       VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- BR-03: GRN guard — "GRN" in message triggers HTTP 409 in C#
    IF EXISTS (
        SELECT 1 FROM dbo.IN_TRNTAIL
        WHERE DIVCODE = @DivCode AND PORDNO = @PoNo
    )
    BEGIN
        RAISERROR('SORRY - ALREADY GRN IS RAISED FOR THIS PURCHASE ORDER', 16, 1);
        RETURN;
    END

    -- BR-04: Every line reason must be non-empty
    IF EXISTS (
        SELECT 1
        FROM OPENJSON(@LineReasonsJson)
        WITH (prSno INT '$.prSno', deleteReason NVARCHAR(500) '$.deleteReason')
        WHERE ISNULL(RTRIM(deleteReason), '') = ''
    )
    BEGIN
        RAISERROR('Delete Reason Cannot be Empty', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Update delete reason on each PO line from JSON array
        UPDATE l
        SET    l.deletereason = j.deleteReason
        FROM   dbo.PO_ORDL l
        INNER JOIN OPENJSON(@LineReasonsJson)
            WITH (prSno INT '$.prSno', deleteReason NVARCHAR(500) '$.deleteReason') j
            ON l.PRSNO = j.prSno
        WHERE  l.DIVCODE = @DivCode
          AND  l.PORDNO  = @PoNo
          AND  CAST(l.PORDDT AS DATE) = @PoDate;

        -- Audit log — one row per PO delete using confirmed LogDet_PO columns
        INSERT INTO dbo.LogDet_PO
            (divcode, prno, prdate, depcode,
             username, Trans_date, Trans_UserId,
             Trans_Name, Trans_Mod,
             Trans_IPADD, Trans_Host)
        VALUES
            (@DivCode, @PoNo, @PoDate, '',
             @UserId, GETDATE(), @UserId,
             'Purchase Order Delete', 'DELETE',
             @IpAddress, @HostName);

        -- Reverse QTYORD on PR lines (restore PR balance)
        UPDATE prl
        SET    prl.qtyord = ISNULL(prl.qtyord, 0) - ISNULL(pol.ORDqty, 0)
        FROM   dbo.PO_PRL prl
        INNER JOIN dbo.PO_ORDL pol
            ON  pol.DIVCODE = prl.divcode
            AND pol.PRNO    = prl.prno
            AND CAST(pol.PRDATE AS DATE) = CAST(prl.prdate AS DATE)
            AND pol.PRSNO   = prl.prsno
        WHERE  pol.DIVCODE = @DivCode
          AND  pol.PORDNO  = @PoNo
          AND  CAST(pol.PORDDT AS DATE) = @PoDate;

        -- Cascade delete: child tables first
        DELETE FROM dbo.PO_ORDL_DETL
        WHERE  DIVCODE = @DivCode
          AND  PORDNO  = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate;

        DELETE FROM dbo.PO_ORDL
        WHERE  DIVCODE = @DivCode
          AND  PORDNO  = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate;

        DELETE FROM dbo.PO_ORDH
        WHERE  DIVCODE = @DivCode
          AND  PORDNO  = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================
-- ksp_PO_SetPrintFlag
-- Sets poprintflg='Y' on PO_ORDH after a successful PDF print.
-- Called by Print action (FSD §3.18) only after PDF bytes generated.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetPrintFlag
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.PO_ORDH
    SET    poprintflg = 'Y'
    WHERE  DIVCODE = @DivCode
      AND  PORDNO  = @PoNo
      AND  CAST(PORDDT AS DATE) = @PoDate;
END;
GO

-- ============================================================
-- ksp_PO_GetPOList
-- Paginated PO search for the Find modal and nav-index build.
-- Returns: divCode, poNo, poDate, orderType, supplier,
--          supplierName, orderValue, approvalStatus, totalLines.
-- Excludes cancelled POs. Ordered newest first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOList
(
    @DivCode   VARCHAR(2),
    @FDate     DATE,
    @LDate     DATE,
    @Search    VARCHAR(100) = NULL,
    @Supplier  VARCHAR(10)  = NULL,
    @Page      INT          = 1,
    @PageSize  INT          = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS Supplier,
        RTRIM(ISNULL(sl.slname, ''))                                AS SupplierName,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        CASE WHEN ISNULL(h.Conflg, 'N') = 'Y' THEN 'CONFIRMED' ELSE 'PENDING' END AS ApprovalStatus,
        (
            SELECT COUNT(*) FROM dbo.PO_ORDL l
            WHERE l.DIVCODE = h.DIVCODE
              AND l.PORDNO  = h.PORDNO
              AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
        )                                                           AS TotalLines
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.FA_SLMAS sl ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    WHERE h.DIVCODE = @DivCode
      AND CAST(h.PORDDT AS DATE) BETWEEN @FDate AND @LDate
      AND ISNULL(h.CANFLG, '') = ''
      AND (
            @Search IS NULL OR @Search = ''
            OR CAST(h.PORDNO AS VARCHAR(20)) LIKE '%' + @Search + '%'
            OR RTRIM(ISNULL(h.SLCODE,  '')) LIKE '%' + @Search + '%'
            OR RTRIM(ISNULL(sl.slname, '')) LIKE '%' + @Search + '%'
          )
      AND (@Supplier IS NULL OR @Supplier = '' OR RTRIM(h.SLCODE) = RTRIM(@Supplier))
    ORDER BY h.PORDDT DESC, h.PORDNO DESC
    OFFSET (@Page - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO



-- ============================================================
-- ksp_PR_DateWise_Report  (PR Report Integration — 18 Jun 2026)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_DateWise_Report
    @Divcode  varchar(2),
    @FromDate datetime,
    @ToDate   datetime,
    @FrmDep   varchar(3) = NULL,
    @ToDep    varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.prdate                                          AS PrDate,
            l.prno                                            AS PrNo,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            ISNULL(l.qtyind,  0)                             AS QtyIndent,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.prstatus                                        AS PrStatusCode,
            l.SecondApp                                       AS SecondApp,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName
        FROM dbo.PO_PRH h
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        LEFT  JOIN dbo.IN_DEP dep
            ON  h.depcode = dep.DEPCODE
            AND h.divcode = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.divcode = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @Divcode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND (@FrmDep IS NULL OR h.depcode >= @FrmDep)
          AND (@ToDep   IS NULL OR h.depcode <= @ToDep)
        ORDER BY h.prdate, l.prno, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PR_DeptWise_Report  (PR Report Integration — 18 Jun 2026)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_DeptWise_Report
    @Divcode  varchar(2),
    @FromDate datetime,
    @ToDate   datetime,
    @DepCode  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.divcode                                         AS DivCode,
            h.depcode                                         AS DepCode,
            RTRIM(ISNULL(dep.DEPNAME, ''))                   AS DepName,
            l.prno                                            AS PrNo,
            l.prdate                                          AS PrDate,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.prstatus                                        AS PrStatusCode,
            l.SecondApp                                       AS SecondApp,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName
        FROM dbo.PO_PRH h
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        LEFT  JOIN dbo.IN_DEP dep
            ON  h.depcode = dep.DEPCODE
            AND h.divcode = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.divcode = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @Divcode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND (@DepCode IS NULL OR h.depcode = @DepCode)
        ORDER BY dep.DEPNAME, l.prno, l.prdate, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
