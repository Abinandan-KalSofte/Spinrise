-- ============================================================
-- merged.sql — M01 PR (Purchase Requisition)
-- Databases: JAT *and* SCM (SCMTS) on 172.16.16.52\sql2016 —
-- this file deploys to BOTH site databases.
-- Rule: NEVER run individual SP files in production — use this file
-- NOTE: ksp_PR_Save uses OPENJSON — requires compat level >= 130.
--       Run manually against the selected DB first if needed:
--       ALTER DATABASE <SelectedDB> SET COMPATIBILITY_LEVEL = 130;
--
-- ⚠️ 07-Jul: a hardcoded "USE JAT;" (+ ALTER DATABASE JAT ...) was
-- REMOVED from here. It silently redirected every run to JAT
-- regardless of the database selected in SSMS/sqlcmd — the exact
-- SCM-landed-on-JAT incident already fixed once in merged_jat.sql
-- (PR #33), found here on a second-pass review (Sasi, 07-Jul).
-- Select the target database FIRST (SSMS dropdown / sqlcmd -d),
-- exactly as DEPLOY_STEPS.txt already instructs.
--
-- NOTE: ksp_GetDatabases used to live here too, behind a "USE master;"
-- switch-back attempt. That's a dead end -- a USE statement executed
-- via dynamic SQL (EXEC/sp_executesql) only changes context for the
-- duration of that dynamic call and reverts once it returns, so there
-- is no generic way to "return to whatever DB was selected" from pure
-- T-SQL. ksp_GetDatabases is master-scoped infrastructure, not a PR-
-- module SP -- moved to its own one-time setup script:
-- Scripts/02-StoredProcedures/ksp_GetDatabases.sql. Run it once
-- against master; it does not belong in either merged file.
-- ============================================================

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
        RTRIM(ISNULL(d.DIVNAME,   ''))        AS DivName,
        RTRIM(ISNULL(d.CUST_ID1, ''))        AS CustId1
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
        RTRIM(ISNULL(d.DIVNAME,   ''))    AS DivName,
        RTRIM(ISNULL(d.CUST_ID1, ''))    AS CustId1
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
            curstock, CCCODE, SubCost, CATCODE, BGRPCODE,
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
                @UserId, GETUTCDATE(), 4,
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
                @UserId, GETUTCDATE(), 4,
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
                @UserId, GETUTCDATE(), 4,
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
-- MODULE = 4 -- PR and PO Entry share this USERLEVEL permission
-- group by design (confirmed with Abinandan, 07-Jul, in response to
-- Sasi's review question). Same group as ksp_PO_GetUserLevel --
-- one ULEVEL controls both screens. Not a bug, not a collision.
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
-- UPDLOCK + HOLDLOCK (held under the caller's transaction) prevents race
-- condition on concurrent amendment entry — no session-level isolation
-- change needed for this. Number derived from MAX(amendno)+1 in PO_APRH for the FY.
-- SP name CONFIRMED by Sasi (Stage 2, 23-May-2026).
-- NOTE (Sasi 07-Jul review): this SP is always called nested inside
-- ksp_PR_SaveAmendment's open transaction. SET TRANSACTION ISOLATION LEVEL is
-- session-scoped, not transaction-scoped, so a SERIALIZABLE set here used to
-- silently persist for the rest of the caller's session/batch after this proc
-- returned. Removed in favour of UPDLOCK+HOLDLOCK alone, which already gives
-- the same atomicity guarantee (the lock is held until the enclosing
-- transaction ends) without altering the caller's isolation level.
-- FSD: M01 PR Amendment Entry v2.3 | AF-04
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[usp_GetNextAmendNo]
    @DivCode    VARCHAR(2),
    @FDate      DATE,
    @LDate      DATE,
    @NewDocNo   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
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
-- Target: whichever client DB is currently selected (JAT or SCM/SCMTS) —
-- this migration runs against both, same as the rest of merged.sql.
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

-- PO_APRH: header snapshot for 2nd+ amendments (legacy fallback only — PO_PRH
-- is preserved under CR-M01-AM-001; comment corrected 07-Jul, Sasi review)
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
-- LEFT JOIN to PO_PRH — legacy fallback only (pre-CR-M01-AM-001 data);
-- current builds no longer delete PO_PRH after the first amendment.
-- depcode/REQNAME fall back to PO_APRH columns stored on ADD.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentList]
    @DivCode    VARCHAR(2),
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
    @DivCode    VARCHAR(2),
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
--   #1 — Amendment header (PO_APRH; LEFT JOIN PO_PRH as fallback)
--   #2 — Amendment lines (PO_APRL + IN_ITEM)
-- ISNULL(a.<col>, h.<col>) fallback to PO_PRH — legacy fallback only
-- (pre-CR-M01-AM-001 data); current builds no longer delete PO_PRH.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentById]
    @DivCode    VARCHAR(2),
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
-- LEFT JOIN to PO_PRH — legacy fallback only (pre-CR-M01-AM-001 data);
-- header fields fall back to PO_APRH columns stored on ADD.
-- FSD: M01 PR Amendment Entry v2.3
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_GetAmendmentPrint]
    @DivCode    VARCHAR(2),
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
--   PATH C: amdflg='D' PO_APRL snapshot + LogDet_po Trans_Mod='DELETE' written for each deleted line BEFORE the physical delete (audit trail gap — Sasi 07-Jul review).
--   @Result OUTPUT: 0=success, 2=business rule violation, 3=concurrency conflict, -1=infrastructure error (Sasi 07-Jul review).
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_SaveAmendment]
    @Mode               VARCHAR(15),        -- 'ADD'
    @DivCode            VARCHAR(2),
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

    -- Drives @Result classification in CATCH (Sasi 07-Jul review): 2=business rule, 3=concurrency conflict
    DECLARE @ErrCode INT = 2;

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

        -- PATH C audit trail (Sasi 07-Jul review): snapshot deleted lines into PO_APRL (amdflg='D')
        -- + LogDet_po (Trans_Mod='DELETE') BEFORE the physical delete, so a legitimate PATH C
        -- deletion remains distinguishable after the fact from a line that was never entered —
        -- restoring the "original records preserved intact" premise of Option C.
        DECLARE @MaxAprlSnoDel INT;
        SELECT @MaxAprlSnoDel = ISNULL(MAX(prsno), 0)
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
            @MaxAprlSnoDel + ROW_NUMBER() OVER (ORDER BY p.prsno),
            ROW_NUMBER() OVER (ORDER BY p.prsno),
            p.itemcode, p.macno, p.qtyind, p.reqddate, p.RATE,
            'ORIGINAL', NULL,
            NULL, p.CCCODE, p.CATCODE, p.BGRPCODE,
            p.PLACE, p.APPCOST, p.remarks, 'D'
        FROM dbo.PO_PRL p
        WHERE  p.divcode              = @DivCode
          AND  p.prno                 = @PrNo
          AND  CAST(p.prdate AS DATE) = @PrDate
          AND  p.prsno NOT IN (SELECT PrSno FROM @LineWork);

        INSERT INTO dbo.LogDet_po
            (divcode, prno, prdate, prsno, itemcode, macno, quantity, RATE,
             Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
             Trans_UserId, Trans_date, moduleNo, reqname, createdby)
        SELECT
            @DivCode, @PrNo, @PrDate, p.prsno, p.itemcode, p.macno,
            CAST(p.qtyind AS NUMERIC(15,0)), p.RATE,
            'PR Amendment', 'DELETE', @HostName, @IpAddress,
            @UserId, GETUTCDATE(), 4, '', @UserId
        FROM dbo.PO_PRL p
        WHERE  p.divcode              = @DivCode
          AND  p.prno                 = @PrNo
          AND  CAST(p.prdate AS DATE) = @PrDate
          AND  p.prsno NOT IN (SELECT PrSno FROM @LineWork);

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
               p.CCCODE   = lw.CcCode,
               p.SubCost  = lw.CcCode
               -- FirstApp, SecondApp, ThirdApp, PRSTATUS, DirectApp preserved
        FROM   dbo.PO_PRL p
        INNER JOIN @LineWork lw
            ON  p.divcode              = @DivCode
            AND p.prno                 = @PrNo
            AND CAST(p.prdate AS DATE) = @PrDate
            AND p.prsno                = lw.PrSno
            AND p.row_version          = lw.RowVersion;

        IF @@ROWCOUNT <> @PathAExpected
        BEGIN
            SET @ErrCode = 3; -- concurrency conflict (Sasi 07-Jul review)
            RAISERROR('One or more lines were modified by another user. Please reload and try again.', 16, 1);
        END

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
             CCCODE, SubCost, CATCODE, BGRPCODE, PLACE, APPCOST, remarks,
             amdflg, Depcode,
             FirstApp, SecondApp, ThirdApp, prstatus, DirectApp)
        SELECT
            @DivCode, @PrNo, @PrDate,
            @MaxPrSno + ROW_NUMBER() OVER (ORDER BY lw.PrSno),
            lw.ItemCode, lw.MacNo, lw.QtyInd,
            TRY_CONVERT(DATE, NULLIF(lw.ReqdDate, '')),
            lw.Rate, lw.CcCode, lw.CcCode, lw.CatCode, lw.BgrpCode,
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
            @UserId, GETUTCDATE(), 4, '', @UserId
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
        SET @Result = CASE WHEN ERROR_SEVERITY() = 16 THEN @ErrCode ELSE -1 END;
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
             @UserId, GETUTCDATE(), @UserId,
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
             @UserId, GETUTCDATE(), @UserId,
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


-- ============================================================
-- ksp_PenPR_GetDateWise
-- Pending PR Date-Wise report.
-- Pending predicate: FCLOSED <> 'y' AND (qtyreqd - qtyord) >= 1
-- Column aliases verified against PendingPrDateWiseRowDto.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PenPR_GetDateWise
    @DivCode  varchar(10),
    @FromDate datetime,
    @ToDate   datetime
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.prno                                            AS PrNo,
            h.prdate                                          AS PrDate,
            h.app3date                                        AS App3Date,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.reqddate                                        AS ReqdDate,
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
        LEFT  JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @DivCode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND ISNULL(l.FCLOSED, 'N') <> 'y'
          AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0)) >= 1
        ORDER BY h.prdate, l.prno, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PenPR_GetDeptWise
-- Pending PR Department-Wise report.
-- @DepCode = NULL returns all departments.
-- Pending predicate: FCLOSED <> 'y' AND (qtyreqd - qtyord) >= 1
-- Column aliases verified against PendingPrDeptWiseRowDto.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PenPR_GetDeptWise
    @DivCode  varchar(10),
    @FromDate datetime,
    @ToDate   datetime,
    @DepCode  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            dep.DEPCODE                                       AS DepCode,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            l.prno                                            AS PrNo,
            h.prdate                                          AS PrDate,
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Uom,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrdered,
            ISNULL(l.qtyrec,  0)                             AS QtyReceived,
            l.reqddate                                        AS ReqdDate,
            l.remarks                                         AS Remarks,
            h.app3date                                        AS App3Date,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName,
            RTRIM(ISNULL(div.DIVNAME,       ''))             AS DivName
        FROM dbo.PO_PRH h
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        INNER JOIN dbo.IN_DEP dep
            ON  h.depcode = dep.DEPCODE
            AND h.divcode = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.divcode = div.DIVCODE
        LEFT  JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @DivCode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND ISNULL(l.FCLOSED, 'N') <> 'y'
          AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0)) >= 1
          AND (@DepCode IS NULL OR h.depcode = @DepCode)
        ORDER BY dep.DEPNAME, l.prno, h.prdate, l.itemcode;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PenPR_GetItemWise
-- Pending PR Item-Wise report.
-- @FItem / @TItem: empty string = all items; code = range/single.
-- Single: FItem = TItem = itemcode
-- All / multiple: FItem = '' , TItem = '' (post-filter in app layer for multi-select)
-- Pending predicate: FCLOSED <> 'y' AND (qtyreqd - qtyord) >= 1
-- Column aliases verified against PendingPrItemWiseRowDto.
-- PrStatus decoded in the application layer (DecodePrStatus).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PenPR_GetItemWise
    @DivCode  varchar(10),
    @FromDate datetime,
    @ToDate   datetime,
    @FItem    varchar(50) = '',
    @TItem    varchar(50) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.itemcode                                        AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                  AS ItemName,
            l.prno                                            AS IndentNo,
            h.prdate                                          AS IndentDt,
            RTRIM(ISNULL(dep.DEPNAME,  ''))                  AS DepName,
            dep.DEPCODE                                       AS DepCode,
            RTRIM(ISNULL(div.DIVNAME,  ''))                  AS DivName,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname,  ''))             AS DivUnitName,
            RTRIM(ISNULL(itm.UOM,      ''))                  AS Unit,
            ISNULL(l.qtyreqd, 0)                             AS QtyReqd,
            ISNULL(l.qtyord,  0)                             AS QtyOrd,
            ISNULL(l.qtyrec,  0)                             AS QtyRec,
            l.prstatus                                        AS PrStatusCode,
            l.SecondApp                                       AS SecondApp,
            h.refno                                           AS RefNo,
            l.remarks                                         AS Remarks,
            l.reqddate                                        AS ReqdDate,
            h.placeofiss                                      AS PlaceOfIss
        FROM dbo.PO_PRH h
        LEFT  JOIN dbo.IN_DEP dep
            ON  h.depcode = dep.DEPCODE
            AND h.divcode = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.divcode = div.DIVCODE
        INNER JOIN dbo.PO_PRL l
            ON  h.divcode = l.divcode
            AND h.prno    = l.prno
            AND h.prdate  = l.prdate
        LEFT  JOIN dbo.IN_ITEM itm
            ON  l.itemcode = itm.ITEMCODE
        WHERE h.divcode = @DivCode
          AND h.prdate  BETWEEN @FromDate AND @ToDate
          AND ISNULL(l.FCLOSED, 'N') <> 'y'
          AND (ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0)) >= 1
          AND (ISNULL(@FItem, '') = '' OR l.itemcode >= @FItem)
          AND (ISNULL(@TItem, '') = '' OR l.itemcode <= @TItem)
        ORDER BY l.itemcode, l.prno, h.prdate;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
-- ============================================================
-- merged_jat.sql — M01 PO (PR → PO Transfer + PO Approval)
-- Databases: JAT *and* SCM (SCMTS) on 172.16.16.52\sql2016 —
-- this file deploys to BOTH site databases.
-- Contains ALL ksp_PO_* stored procedures.
--
-- ⚠️ 06-Jul: the hardcoded "USE [JAT];" was REMOVED. It silently
-- redirected every run to JAT regardless of the database selected
-- in SSMS/sqlcmd — an SCM deployment executed with this file was
-- discovered to have landed on JAT instead (SCM had stale
-- ksp_PO_SaveEntry and no report SPs until 06-Jul 17:45).
-- Select the target database FIRST (SSMS dropdown / sqlcmd -d),
-- exactly as DEPLOY_STEPS.txt already instructs.
-- ============================================================

-- ============================================================
-- Auth SPs — duplicated here because JAT users authenticate
-- against the JAT DB (CUST_ID1 added for customer-specific reports)
-- ============================================================

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
        RTRIM(ISNULL(d.DIVNAME,   ''))       AS DivName,
        RTRIM(ISNULL(d.CUST_ID1, ''))        AS CustId1
    FROM   dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE  p.divcode   = @DivCode
      AND  p.user_name = @UserName
      AND  dbo.DecryptString(p.password) = @Password
      AND  UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
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
        RTRIM(ISNULL(d.DIVNAME,   ''))   AS DivName,
        RTRIM(ISNULL(d.CUST_ID1, ''))    AS CustId1
    FROM   dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE  p.user_id  = @UserId
      AND  p.divcode  = @DivCode
      AND  UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
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
-- MODULE = 4 -- PR and PO Entry share this USERLEVEL permission
-- group by design (confirmed with Abinandan, 07-Jul, in response to
-- Sasi's review question). Same group as ksp_PR_GetUserPermissions
-- -- one ULEVEL controls both screens. Not a bug, not a collision.
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
          AND MODULE          = 4   -- shared with PR (ksp_PR_GetUserPermissions) by design
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
-- Returns: flags for approved PR lines, doc para, backdate, max PO date, roundoff tolerance.
-- FIX 2: Added Roundoff field for round-off validation (frontend expects numeric tolerance).
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
    DECLARE @Roundoff             NUMERIC(5, 2) = NULL;  -- FIX 2: Roundoff tolerance threshold

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
          AND RTRIM(ISNULL(l.prstatus, '')) NOT IN ('E','C','Z','X')
          AND ISNULL(h.cancelflag, '') = ''
    )
        SET @ApprovedPrLinesExist = 1;

    -- Check 2: PO doc series defined in PO_DOC_PARA
    -- ⚠ VERIFY: TC value for Purchase Order in this installation
    IF EXISTS (SELECT 1 FROM dbo.PO_DOC_PARA WHERE TC = 'PURCHASE ORDER')
        SET @DocParaExists = 1;

    -- Backdate flag
    SELECT TOP 1 @BackDateFlag = ISNULL(UPPER(RTRIM(BACKDATE)), 'Y')
    FROM dbo.IN_PARA;

    -- Max existing PO date for this division
    SELECT @MaxPoDate = CAST(MAX(PORDDT) AS DATE)
    FROM dbo.PO_ORDH
    WHERE divcode = @DivCode
      AND ISNULL(CANFLG, '') = '';

    -- FIX 2: Fetch Roundoff tolerance from PO_PARA (division-level PO parameters)
    -- If not configured, defaults to NULL (frontend treats NULL as 0 → tolerance = 1)
    -- NOTE: If ROUNDOFF column does not exist in PO_PARA, run:
    -- ALTER TABLE dbo.PO_PARA ADD ROUNDOFF NUMERIC(5, 2) NULL;
    SELECT @Roundoff = ISNULL(p.ROUNDOFF, NULL)
    FROM dbo.PO_PARA p
    WHERE p.divcode = @DivCode;

    SELECT
        @ApprovedPrLinesExist AS ApprovedPrLinesExist,
        @DocParaExists        AS DocParaExists,
        @BackDateFlag         AS BackDateFlag,
        @MaxPoDate            AS MaxPoDate,
        @Roundoff             AS Roundoff;  -- FIX 2: Round-off tolerance
END;
GO



-- ============================================================
-- ksp_PO_GetOrderTypes
-- Returns purchase order type lookup.
-- PO_TYPE columns: TYPE_CODE, TYPNAME, active (varchar)
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

    SELECT
        RTRIM(s.slcode)                                         AS SlCode,
        RTRIM(ISNULL(s.slname, ''))                             AS SlName,
        RTRIM(ISNULL(s.gstinno, ''))                            AS GstinNo,
        RTRIM(ISNULL(s.gststatecode, ''))                       AS GstStateCode,
        RTRIM(ISNULL(s.gststatecode, '')) +
            CASE WHEN RTRIM(ISNULL(s.state, '')) <> ''
                 THEN ' - ' + RTRIM(s.state)
                 ELSE '' END                                    AS GstStateName,
        RTRIM(ISNULL(s.city, ''))                               AS City   -- CR-003: ⚠ VERIFY column name in FA_SLMAS
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



-- ============================================================
-- ksp_PO_GetPayTerms
-- Returns all payment term codes and descriptions from Ig_PayTerm.
-- Used to populate the Payment Term dropdown on the PO Entry screen.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPayTerms
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(PayTerm_Code)               AS PayTermCode,
        RTRIM(ISNULL(PayTerm_Desc, ''))   AS PayTermDesc
    FROM dbo.Ig_PayTerm
    ORDER BY PayTerm_Code;
END;
GO



-- ksp_PO_GetPRLines
-- Returns eligible PR lines for the PO PR Picker (BR-02).
-- Filter: DirectApp='Y', Fclosed<>'Y', balance qty > 0,
--         prstatus NOT IN ('E','C','Z','X'), PR not cancelled.
-- NOTE: 'O' (Ordered) intentionally omitted — balance>0 excludes fully-ordered lines.
--       Legacy VB6 sets prstatus='O' for partial orders; blocking 'O' hides lines
--       with remaining balance qty (POT-LC-01). FClosed='Y' covers closed lines.
-- Balance = QTYREQD - QTYORD - Enq_Qty
-- GST columns (CgstPer/SgstPer/IgstPer/GstTaxCode) sourced from IN_ITEM.
-- SuggestedRate: last ordered rate from PO_ORDL; falls back to PR line Rate; 0 if neither.
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
        CONVERT(varchar(10), CAST(ISNULL(h.prdate, l.prdate) AS DATE), 120) AS PrDate,
        l.prsno                                                         AS PrSno,
        RTRIM(l.itemcode)                                               AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                                   AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                        AS Uom,
        ISNULL(l.qtyreqd, 0) - ISNULL(l.qtyord, 0) - ISNULL(l.Enq_Qty, 0) AS BalanceQty,
        RTRIM(ISNULL(d.depname, ''))                                    AS Department,
        RTRIM(ISNULL(scc.SCCNAME, ''))                                  AS SubCostCentre,
        ISNULL(l.SubCost, 0)                                            AS SubCostCode,
        RTRIM(ISNULL(l.Depcode, ''))                                    AS DepCode,
        RTRIM(ISNULL(l.remarks, ''))                                    AS Remarks,
        RTRIM(ISNULL(i.hsncode, ''))                                    AS HsnCode,
        ISNULL(i.CGST_PER, 0)                                          AS CgstPer,
        ISNULL(i.SGST_PER, 0)                                          AS SgstPer,
        ISNULL(i.IGST_PER, 0)                                          AS IgstPer,
        RTRIM(ISNULL(i.GSTTAXCODE, ''))                                AS GstTaxCode,
        RTRIM(ISNULL(h.REQNAME, ''))                                    AS RequesterId,
        RTRIM(ISNULL(e.ename, ''))                                      AS RequesterName,
        ISNULL(
            COALESCE(
                NULLIF((
                    SELECT TOP 1 pol.Rate
                    FROM   dbo.PO_ORDL pol
                    INNER JOIN dbo.PO_ORDH poh
                        ON  poh.DIVCODE = pol.DIVCODE
                        AND poh.PORDNO  = pol.PORDNO
                        AND poh.PORDDT  = pol.PORDDT
                    WHERE  pol.DIVCODE  = @DivCode
                      AND  pol.ITEMCODE = l.itemcode
                      AND  pol.Rate     > 0
                    ORDER BY poh.PORDDT DESC
                ), 0),
                NULLIF(l.Rate, 0)
            ),
            0
        )                                                               AS SuggestedRate
    FROM dbo.PO_PRL l
    INNER JOIN dbo.PO_PRH h
        ON h.divcode = l.divcode AND h.prno = l.prno
       AND CAST(h.prdate AS DATE) = CAST(l.prdate AS DATE)
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.itemcode
    LEFT JOIN dbo.IN_DEP d
        ON d.divcode = l.divcode AND d.depcode = h.depcode
    LEFT JOIN dbo.In_Scc scc
        ON scc.SCCCODE = l.SubCost
       AND scc.DEPCODE = l.Depcode
       AND scc.Divcode = l.divcode
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
      AND RTRIM(ISNULL(l.prstatus, '')) NOT IN ('E','C','Z','X')
      AND ISNULL(h.cancelflag, '') = ''
      AND (@OrderType IS NULL OR RTRIM(ISNULL(h.PO_GRP, '')) = @OrderType)
      AND (@Search IS NULL
           OR RTRIM(l.itemcode) LIKE @Search + '%'
           OR RTRIM(i.itemname) LIKE '%' + @Search + '%'
           OR CAST(l.prno AS VARCHAR(20)) LIKE @Search + '%')
    ORDER BY h.prdate DESC, l.prno DESC, l.prsno   -- CR-001: newest PRs first
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
               NULL AS PackApp, NULL AS PayMode,
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
               NULL AS UserId, NULL AS Carrier,
               NULL AS FreightPosition, NULL AS InsurancePosition, NULL AS CessPosition,
               NULL AS PackingAmt, NULL AS InsuranceAmt,
               NULL AS DiscountAmt, NULL AS CessAmt, NULL AS AddTaxAmt
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
        ISNULL(h.htcs_amt, 0)                                       AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.Cessper, 0)                                        AS CessPer,
        CAST(0 AS DECIMAL(10,2))                                    AS AedPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        -- FreightPer not stored in PO_ORDH; read from first PO_ORDL line (Frgt1per stored per-line)
        ISNULL((SELECT TOP 1 l.Frgt1per FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
                ORDER BY l.PORDSNO), 0)                             AS FreightPer,
        ISNULL(h.PCKPER, 0)                                         AS PackPer,
        ISNULL(h.INSPER, 0)                                         AS InsurPer,
        ISNULL(h.SURPER, 0)                                         AS SurchargePer,
        ISNULL(h.ADDTAXPER, 0)                                      AS AddTaxPer,
        RTRIM(ISNULL(h.FILENO, ''))                                 AS FileNo,
        ISNULL(h.FCACharg, 0)                                       AS FcaFob,
        CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
        CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        -- Applicability position flags (FRT_FLG/Ins_Flg/Cess_Flg: 'A'=AFTER, else BEFORE)
        CASE WHEN UPPER(RTRIM(ISNULL(h.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsurancePosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessPosition,
        -- Charge amounts: Pack_Amt/Ins_Amt stored in DB; Disc/Cess/AddTax aggregated from PO_ORDL
        -- (using ORDVAL × % was wrong after T-0025 changed ORDVAL to grand total, not item value)
        ISNULL(h.Pack_Amt, 0)                                                                 AS PackingAmt,
        ISNULL(h.Ins_Amt,  0)                                                                 AS InsuranceAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.disamt,    0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS DiscountAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.cess_amt,  0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS CessAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.ADDTAXAMT, 0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS AddTaxAmt,
        -- Payment
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.DIRECT_INS, ''))                             AS DirectInstr,
        RTRIM(ISNULL(h.BANK_CODE, ''))                              AS BankCode,
        RTRIM(ISNULL(h.PAYTERMS, ''))                               AS PaymentTerms,
        RTRIM(ISNULL(h.paytermcode, ''))                            AS PaymentTermCode,
        ISNULL(h.ADV_PER, 0)                                        AS AdvPer,
        ISNULL(h.ADV_AMT, 0)                                        AS AdvAmt,
        RTRIM(ISNULL(h.advpaymenttype, ''))                         AS ModeOfPayment,
        RTRIM(ISNULL(h.chqno, ''))                                  AS PayRef,    -- FIX: CHQNO stores PayRef (DIRECT) or ChequeNo (BANK) via COALESCE; return same value
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS PayRefDate, -- FIX: CHQDT stores PayRefDate (DIRECT) or ChequeDate (BANK) via COALESCE
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
        RTRIM(ISNULL(h.Note2, ''))                                  AS OtherLevies, -- FIX: was hardcoded ''; @OtherLevies maps to Note2 per SaveEntry comment
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
        -- Effective approval status: checks PO_ORDH flags first, then derives from PO_PARA
        -- settings so POs created before auto-confirm SaveEntry was deployed show correctly.
        CASE
            WHEN ISNULL(h.Conflg, 'N') = 'Y'
              THEN 'CONFIRMED'
            WHEN ISNULL(para.Po_Confirm, 'N') = 'N'
                 AND (ISNULL(para.PoFirstLevelApp,  'N') = 'N' OR ISNULL(h.FirstlevelApp,  'N') = 'Y')
                 AND (ISNULL(para.PoSecondLevelApp, 'N') = 'N' OR ISNULL(h.SecondlevelApp, 'N') = 'Y')
              THEN 'CONFIRMED'
            WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y'
              THEN 'First Level Approved'
            ELSE 'PENDING'
        END AS ApprovalStatus,
        RTRIM(ISNULL(h.poprintflg, 'N'))                            AS PrintStatus,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(u.user_name, h.createdby))                     AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        RTRIM(ISNULL(h.createdby, ''))                              AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    LEFT JOIN dbo.PO_PARA para ON para.divcode = h.DIVCODE
    OUTER APPLY (
        SELECT TOP 1 u.user_name
        FROM dbo.PP_PASSWD u
        WHERE RTRIM(u.user_id) = RTRIM(h.createdby)
          AND RTRIM(u.divcode)  = RTRIM(h.DIVCODE)
    ) u
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
        ISNULL(l.cgstamt,0) + ISNULL(l.sgstamt,0) + ISNULL(l.igstamt,0) AS TaxAmt,
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
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason,
        ISNULL(l.disper,    0)                                      AS DiscPer,
        ISNULL(l.disamt,    0)                                      AS DiscAmt,
        ISNULL(l.PACKPER,   0)                                      AS PackingPer,
        ISNULL(l.Packamt,   0)                                      AS PackingAmt,
        ISNULL(l.Frgt1per,  0)                                      AS FreightPer,
        ISNULL(l.Frgt1Amt,  0)                                      AS FreightAmt,
        ISNULL(l.Ins_per,   0)                                      AS InsurancePer,
        ISNULL(l.Ins_amt,   0)                                      AS InsuranceAmt,
        ISNULL(l.OTHCHGS,   0)                                      AS OtherCharges,
        ISNULL(l.cess_per,  0)                                      AS CessPer,
        ISNULL(l.cess_amt,  0)                                      AS CessAmt,
        RTRIM(ISNULL(l.ADDTAX_CODE, ''))                            AS AddTaxCode,
        ISNULL(l.ADDTAXPER, 0)                                      AS AddTaxPer,
        ISNULL(l.ADDTAXAMT, 0)                                      AS AddTaxAmt,
        ISNULL(l.FCACharg,  0)                                      AS FcaFob,
        CASE WHEN UPPER(RTRIM(ISNULL(l.DISFLG,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPos,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsuranceDuty,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessTaxPos,
        -- POT-TC-04 / POT-TC-03: Net line total = taxable + charges - discount + GST + TCS
        -- Fix: cess_amt was missing from the sum, causing NetAmount to under-report by the cess charge.
        ISNULL(l.ORDVAL,0)
          - ISNULL(l.disamt,0)
          + ISNULL(l.Packamt,0)
          + ISNULL(l.Frgt1Amt,0)
          + ISNULL(l.Ins_amt,0)
          + ISNULL(l.OTHCHGS,0)
          + ISNULL(l.cess_amt,0)
          + ISNULL(l.cgstamt,0)
          + ISNULL(l.sgstamt,0)
          + ISNULL(l.igstamt,0)
          + ISNULL(l.Tcs_amt,0)
          + ISNULL(l.ADDTAXAMT,0)                                    AS NetAmount,
        ISNULL(l.SubCost, 0)                                        AS SubCostCode,
        RTRIM(ISNULL(l.DepCode, ''))                                AS DepCode
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
        ISNULL(d.Quantity, 0)                                       AS Qty
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
-- ksp_PO_GetFirstPO
-- Loads the FIRST (oldest) PO for the division in the FY window.
-- Returns 3 result sets: (1) header, (2) lines, (3) delivery slots.
-- Symmetric with ksp_PO_GetLastPO — only ORDER BY direction differs.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetFirstPO
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
    ORDER BY PORDDT ASC, PORDNO ASC;

    IF @PoNo IS NULL
    BEGIN
        SELECT NULL AS DivCode, NULL AS PoNo, NULL AS PoDate, NULL AS OrderType,
               NULL AS OrderTypeDesc, NULL AS Supplier, NULL AS SupplierName,
               NULL AS Gstin, NULL AS GstState, NULL AS Inspect,
               NULL AS RoundOff, NULL AS OrderValue, NULL AS FormType,
               NULL AS RefNo, NULL AS RefDate, NULL AS Currency, NULL AS CurrRate,
               NULL AS Remarks, NULL AS CgstPer, NULL AS SgstPer, NULL AS IgstPer,
               NULL AS TcsPer, NULL AS DiscPer, NULL AS CessPer, NULL AS AedPer,
               NULL AS FreightAmt, NULL AS FreightPer, NULL AS PackPer, NULL AS InsurPer,
               NULL AS SurchargePer, NULL AS AddTaxPer, NULL AS FileNo,
               NULL AS FcaFob, NULL AS FreightType, NULL AS DiscApp,
               NULL AS PackApp, NULL AS PayMode,
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
               NULL AS UserId, NULL AS Carrier,
               NULL AS FreightPosition, NULL AS InsurancePosition, NULL AS CessPosition,
               NULL AS PackingAmt, NULL AS InsuranceAmt,
               NULL AS DiscountAmt, NULL AS CessAmt, NULL AS AddTaxAmt
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
        CAST(0 AS DECIMAL(10,2))                                    AS CgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS IgstPer,
        ISNULL(h.htcs_amt, 0)                                       AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.Cessper, 0)                                        AS CessPer,
        CAST(0 AS DECIMAL(10,2))                                    AS AedPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        ISNULL((SELECT TOP 1 l.Frgt1per FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
                ORDER BY l.PORDSNO), 0)                             AS FreightPer,
        ISNULL(h.PCKPER, 0)                                         AS PackPer,
        ISNULL(h.INSPER, 0)                                         AS InsurPer,
        ISNULL(h.SURPER, 0)                                         AS SurchargePer,
        ISNULL(h.ADDTAXPER, 0)                                      AS AddTaxPer,
        RTRIM(ISNULL(h.FILENO, ''))                                 AS FileNo,
        ISNULL(h.FCACharg, 0)                                       AS FcaFob,
        CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
        CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsurancePosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessPosition,
        ISNULL(h.Pack_Amt, 0)                                                                 AS PackingAmt,
        ISNULL(h.Ins_Amt,  0)                                                                 AS InsuranceAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.disamt,    0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS DiscountAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.cess_amt,  0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS CessAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.ADDTAXAMT, 0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS AddTaxAmt,
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.DIRECT_INS, ''))                             AS DirectInstr,
        RTRIM(ISNULL(h.BANK_CODE, ''))                              AS BankCode,
        RTRIM(ISNULL(h.PAYTERMS, ''))                               AS PaymentTerms,
        RTRIM(ISNULL(h.paytermcode, ''))                            AS PaymentTermCode,
        ISNULL(h.ADV_PER, 0)                                        AS AdvPer,
        ISNULL(h.ADV_AMT, 0)                                        AS AdvAmt,
        RTRIM(ISNULL(h.advpaymenttype, ''))                         AS ModeOfPayment,
        RTRIM(ISNULL(h.chqno, ''))                                  AS PayRef,
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS PayRefDate,
        RTRIM(ISNULL(h.chqno, ''))                                  AS ChequeNo,
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS ChequeDate,
        ISNULL(h.CRDDAYS, 0)                                        AS CreditDays,
        CASE WHEN h.Duedate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.Duedate AS DATE), 120) END AS DeliveryDate,
        RTRIM(ISNULL(h.DEL_INS1, ''))                               AS DeliveryLocation,
        RTRIM(ISNULL(h.Billadd, ''))                                AS BillingAddress,
        RTRIM(ISNULL(h.SPL_INS, ''))                                AS SpecialInstr,
        RTRIM(ISNULL(h.DEL_INS2, ''))                               AS Despatch,
        RTRIM(ISNULL(h.Note, ''))                                   AS Purpose,
        RTRIM(ISNULL(h.Note2, ''))                                  AS OtherLevies,
        RTRIM(ISNULL(h.PriceTerm, ''))                              AS PricingTerms,
        RTRIM(ISNULL(h.RemarksPF, ''))                              AS PackForwarding,
        RTRIM(ISNULL(h.RemarksIns, ''))                             AS Insurance,
        RTRIM(ISNULL(h.RemarksFrt, ''))                             AS Freight,
        RTRIM(ISNULL(h.REMINDER, ''))                               AS Reminder,
        ''                                                          AS Status,
        CAST(CASE WHEN ISNULL(h.CANFLG, '') <> '' THEN 1 ELSE 0 END AS BIT) AS Cancelled,
        CASE WHEN h.CANDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.CANDT AS DATE), 120) END AS CancelDate,
        RTRIM(ISNULL(h.REASON, ''))                                 AS CancelReason,
        RTRIM(ISNULL(h.APPROVED, 'N'))                              AS Approved,
        RTRIM(ISNULL(h.APPBY, ''))                                  AS ApprovedBy,
        TRY_CAST(NULLIF(RTRIM(h.AMDORDNO), '') AS DECIMAL(10,0))   AS AmdOrderNo,
        CASE WHEN h.AMDORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.AMDORDDT AS DATE), 120) END AS AmdDate,
        TRY_CAST(NULLIF(RTRIM(h.REFORDNO), '') AS DECIMAL(10,0))   AS AmdRefNo,
        CASE WHEN h.REFORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.REFORDDT AS DATE), 120) END AS AmdRefDate,
        -- Effective approval status: checks PO_ORDH flags first, then derives from PO_PARA
        -- settings so POs created before auto-confirm SaveEntry was deployed show correctly.
        CASE
            WHEN ISNULL(h.Conflg, 'N') = 'Y'
              THEN 'CONFIRMED'
            WHEN ISNULL(para.Po_Confirm, 'N') = 'N'
                 AND (ISNULL(para.PoFirstLevelApp,  'N') = 'N' OR ISNULL(h.FirstlevelApp,  'N') = 'Y')
                 AND (ISNULL(para.PoSecondLevelApp, 'N') = 'N' OR ISNULL(h.SecondlevelApp, 'N') = 'Y')
              THEN 'CONFIRMED'
            WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y'
              THEN 'First Level Approved'
            ELSE 'PENDING'
        END AS ApprovalStatus,
        RTRIM(ISNULL(h.poprintflg, 'N'))                            AS PrintStatus,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(u.user_name, h.createdby))                     AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        RTRIM(ISNULL(h.createdby, ''))                              AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    LEFT JOIN dbo.PO_PARA para ON para.divcode = h.DIVCODE
    OUTER APPLY (
        SELECT TOP 1 u.user_name
        FROM dbo.PP_PASSWD u
        WHERE RTRIM(u.user_id) = RTRIM(h.createdby)
          AND RTRIM(u.divcode)  = RTRIM(h.DIVCODE)
    ) u
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
        ISNULL(l.cgstamt,0) + ISNULL(l.sgstamt,0) + ISNULL(l.igstamt,0) AS TaxAmt,
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
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason,
        ISNULL(l.disper,    0)                                      AS DiscPer,
        ISNULL(l.disamt,    0)                                      AS DiscAmt,
        ISNULL(l.PACKPER,   0)                                      AS PackingPer,
        ISNULL(l.Packamt,   0)                                      AS PackingAmt,
        ISNULL(l.Frgt1per,  0)                                      AS FreightPer,
        ISNULL(l.Frgt1Amt,  0)                                      AS FreightAmt,
        ISNULL(l.Ins_per,   0)                                      AS InsurancePer,
        ISNULL(l.Ins_amt,   0)                                      AS InsuranceAmt,
        ISNULL(l.OTHCHGS,   0)                                      AS OtherCharges,
        ISNULL(l.cess_per,  0)                                      AS CessPer,
        ISNULL(l.cess_amt,  0)                                      AS CessAmt,
        RTRIM(ISNULL(l.ADDTAX_CODE, ''))                            AS AddTaxCode,
        ISNULL(l.ADDTAXPER, 0)                                      AS AddTaxPer,
        ISNULL(l.ADDTAXAMT, 0)                                      AS AddTaxAmt,
        ISNULL(l.FCACharg,  0)                                      AS FcaFob,
        CASE WHEN UPPER(RTRIM(ISNULL(l.DISFLG,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPos,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsuranceDuty,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessTaxPos,
        ISNULL(l.ORDVAL,0)
          - ISNULL(l.disamt,0)
          + ISNULL(l.Packamt,0)
          + ISNULL(l.Frgt1Amt,0)
          + ISNULL(l.Ins_amt,0)
          + ISNULL(l.OTHCHGS,0)
          + ISNULL(l.cess_amt,0)
          + ISNULL(l.cgstamt,0)
          + ISNULL(l.sgstamt,0)
          + ISNULL(l.igstamt,0)
          + ISNULL(l.Tcs_amt,0)
          + ISNULL(l.ADDTAXAMT,0)                                    AS NetAmount,
        ISNULL(l.SubCost, 0)                                        AS SubCostCode,
        RTRIM(ISNULL(l.DepCode, ''))                                AS DepCode
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
        ISNULL(d.Quantity, 0)                                       AS Qty
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
        ISNULL(h.htcs_amt, 0)                                       AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.Cessper, 0)                                        AS CessPer,
        CAST(0 AS DECIMAL(10,2))                                    AS AedPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        -- FreightPer not stored in PO_ORDH; read from first PO_ORDL line (Frgt1per stored per-line)
        ISNULL((SELECT TOP 1 l.Frgt1per FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
                ORDER BY l.PORDSNO), 0)                             AS FreightPer,
        ISNULL(h.PCKPER, 0)                                         AS PackPer,
        ISNULL(h.INSPER, 0)                                         AS InsurPer,
        ISNULL(h.SURPER, 0)                                         AS SurchargePer,
        ISNULL(h.ADDTAXPER, 0)                                      AS AddTaxPer,
        RTRIM(ISNULL(h.FILENO, ''))                                 AS FileNo,
        ISNULL(h.FCACharg, 0)                                       AS FcaFob,
        CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
        CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        -- Applicability position flags (FRT_FLG/Ins_Flg/Cess_Flg: 'A'=AFTER, else BEFORE)
        CASE WHEN UPPER(RTRIM(ISNULL(h.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsurancePosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessPosition,
        -- Charge amounts: Pack_Amt/Ins_Amt stored in DB; Disc/Cess/AddTax aggregated from PO_ORDL
        -- (using ORDVAL × % was wrong after T-0025 changed ORDVAL to grand total, not item value)
        ISNULL(h.Pack_Amt, 0)                                                                 AS PackingAmt,
        ISNULL(h.Ins_Amt,  0)                                                                 AS InsuranceAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.disamt,    0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS DiscountAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.cess_amt,  0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS CessAmt,
        ISNULL((SELECT ROUND(SUM(ISNULL(l.ADDTAXAMT, 0)), 2) FROM dbo.PO_ORDL l
                WHERE l.DIVCODE = h.DIVCODE AND l.PORDNO = h.PORDNO
                  AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)), 0)                   AS AddTaxAmt,
        -- Payment
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.DIRECT_INS, ''))                             AS DirectInstr,
        RTRIM(ISNULL(h.BANK_CODE, ''))                              AS BankCode,
        RTRIM(ISNULL(h.PAYTERMS, ''))                               AS PaymentTerms,
        RTRIM(ISNULL(h.paytermcode, ''))                            AS PaymentTermCode,
        ISNULL(h.ADV_PER, 0)                                        AS AdvPer,
        ISNULL(h.ADV_AMT, 0)                                        AS AdvAmt,
        RTRIM(ISNULL(h.advpaymenttype, ''))                         AS ModeOfPayment,
        RTRIM(ISNULL(h.chqno, ''))                                  AS PayRef,    -- FIX: CHQNO stores PayRef (DIRECT) or ChequeNo (BANK) via COALESCE; return same value
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS PayRefDate, -- FIX: CHQDT stores PayRefDate (DIRECT) or ChequeDate (BANK) via COALESCE
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
        RTRIM(ISNULL(h.Note2, ''))                                  AS OtherLevies, -- FIX: was hardcoded ''; @OtherLevies maps to Note2 per SaveEntry comment
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
        -- Effective approval status: checks PO_ORDH flags first, then derives from PO_PARA
        -- settings so POs created before auto-confirm SaveEntry was deployed show correctly.
        CASE
            WHEN ISNULL(h.Conflg, 'N') = 'Y'
              THEN 'CONFIRMED'
            WHEN ISNULL(para.Po_Confirm, 'N') = 'N'
                 AND (ISNULL(para.PoFirstLevelApp,  'N') = 'N' OR ISNULL(h.FirstlevelApp,  'N') = 'Y')
                 AND (ISNULL(para.PoSecondLevelApp, 'N') = 'N' OR ISNULL(h.SecondlevelApp, 'N') = 'Y')
              THEN 'CONFIRMED'
            WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y'
              THEN 'First Level Approved'
            ELSE 'PENDING'
        END AS ApprovalStatus,
        RTRIM(ISNULL(h.poprintflg, 'N'))                            AS PrintStatus,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(u.user_name, h.createdby))                     AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        RTRIM(ISNULL(h.createdby, ''))                              AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    LEFT JOIN dbo.PO_PARA para ON para.divcode = h.DIVCODE
    OUTER APPLY (
        SELECT TOP 1 u.user_name
        FROM dbo.PP_PASSWD u
        WHERE RTRIM(u.user_id) = RTRIM(h.createdby)
          AND RTRIM(u.divcode)  = RTRIM(h.DIVCODE)
    ) u
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
        ISNULL(l.cgstamt,0) + ISNULL(l.sgstamt,0) + ISNULL(l.igstamt,0) AS TaxAmt,
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
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason,
        ISNULL(l.disper,    0)                                      AS DiscPer,
        ISNULL(l.disamt,    0)                                      AS DiscAmt,
        ISNULL(l.PACKPER,   0)                                      AS PackingPer,
        ISNULL(l.Packamt,   0)                                      AS PackingAmt,
        ISNULL(l.Frgt1per,  0)                                      AS FreightPer,
        ISNULL(l.Frgt1Amt,  0)                                      AS FreightAmt,
        ISNULL(l.Ins_per,   0)                                      AS InsurancePer,
        ISNULL(l.Ins_amt,   0)                                      AS InsuranceAmt,
        ISNULL(l.OTHCHGS,   0)                                      AS OtherCharges,
        ISNULL(l.cess_per,  0)                                      AS CessPer,
        ISNULL(l.cess_amt,  0)                                      AS CessAmt,
        RTRIM(ISNULL(l.ADDTAX_CODE, ''))                            AS AddTaxCode,
        ISNULL(l.ADDTAXPER, 0)                                      AS AddTaxPer,
        ISNULL(l.ADDTAXAMT, 0)                                      AS AddTaxAmt,
        ISNULL(l.FCACharg,  0)                                      AS FcaFob,
        CASE WHEN UPPER(RTRIM(ISNULL(l.DISFLG,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPos,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsuranceDuty,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessTaxPos,
        -- POT-TC-04 / POT-TC-03: Net line total = taxable + charges - discount + GST + TCS
        -- Fix: cess_amt was missing from the sum, causing NetAmount to under-report by the cess charge.
        ISNULL(l.ORDVAL,0)
          - ISNULL(l.disamt,0)
          + ISNULL(l.Packamt,0)
          + ISNULL(l.Frgt1Amt,0)
          + ISNULL(l.Ins_amt,0)
          + ISNULL(l.OTHCHGS,0)
          + ISNULL(l.cess_amt,0)
          + ISNULL(l.cgstamt,0)
          + ISNULL(l.sgstamt,0)
          + ISNULL(l.igstamt,0)
          + ISNULL(l.Tcs_amt,0)
          + ISNULL(l.ADDTAXAMT,0)                                    AS NetAmount,
        ISNULL(l.SubCost, 0)                                        AS SubCostCode,
        RTRIM(ISNULL(l.DepCode, ''))                                AS DepCode
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
        ISNULL(d.Quantity, 0)                                       AS Qty
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




-- PO number allocation: FY-scoped MAX+1 with UPDLOCK+HOLDLOCK (see ksp_PO_SaveEntry §6).
-- No SEQUENCE object required — numbers restart from STDOCNO each financial year.




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

    -- TC-06: block deletion only when a CONFIGURED approval level is genuinely done.
    -- Conflg and FirstlevelApp may be auto-set by SaveEntry when PO_PARA disables those
    -- steps (Po_Confirm='N' / PoFirstLevelApp='N'), so each flag is only honoured when
    -- the matching PO_PARA column is 'Y' (i.e. the step is actually required).
    DECLARE @UseL1   CHAR(1) = 'N';
    DECLARE @UseL2   CHAR(1) = 'N';
    DECLARE @UseConf CHAR(1) = 'N';

    SELECT
        @UseL1   = ISNULL(PoFirstLevelApp,  'N'),
        @UseL2   = ISNULL(PoSecondLevelApp, 'N'),
        @UseConf = ISNULL(Po_Confirm,        'N')
    FROM dbo.PO_PARA
    WHERE divcode = @DivCode;

    IF EXISTS (
        SELECT 1 FROM dbo.PO_ORDH
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND (   (@UseL1   = 'Y' AND RTRIM(ISNULL(FirstlevelApp,  'N')) = 'Y')
               OR (@UseL2   = 'Y' AND RTRIM(ISNULL(SecondlevelApp, 'N')) = 'Y')
               OR (@UseConf = 'Y' AND RTRIM(ISNULL(Conflg,         'N')) = 'Y'))
    )
    BEGIN
        RAISERROR('Cannot delete an approved Purchase Order.', 16, 1);
        RETURN;
    END

    -- FD-05: ERP 7.4 parity — only the latest PO in the FY can be deleted.
    -- Prevents sequence gaps (e.g. deleting PO-1198 while PO-1199/1200 exist).
    DECLARE @FYStartDel DATE, @FYEndDel DATE;
    IF MONTH(@PoDate) >= 4
    BEGIN
        SET @FYStartDel = DATEFROMPARTS(YEAR(@PoDate),     4,  1);
        SET @FYEndDel   = DATEFROMPARTS(YEAR(@PoDate) + 1, 3, 31);
    END
    ELSE
    BEGIN
        SET @FYStartDel = DATEFROMPARTS(YEAR(@PoDate) - 1, 4,  1);
        SET @FYEndDel   = DATEFROMPARTS(YEAR(@PoDate),     3, 31);
    END

    IF @PoNo <> (
        SELECT ISNULL(MAX(PORDNO), @PoNo)
        FROM dbo.PO_ORDH
        WHERE DIVCODE = @DivCode
          AND CAST(PORDDT AS DATE) >= @FYStartDel
          AND CAST(PORDDT AS DATE) <= @FYEndDel
    )
    BEGIN
        RAISERROR('Cannot delete this Purchase Order. Only the latest Purchase Order in the financial year can be deleted.', 16, 1);
        RETURN;
    END

    -- BR-03: GRN guard — scoped to the financial year of the PO date so that
    -- the same PORDNO reused in a later FY does not false-block deletion.
    -- Indian FY: April 1 – March 31. DOCDT is the GRN receipt date.
    DECLARE @FYStart DATE, @FYEnd DATE;
    IF MONTH(@PoDate) >= 4
    BEGIN
        SET @FYStart = DATEFROMPARTS(YEAR(@PoDate),     4,  1);
        SET @FYEnd   = DATEFROMPARTS(YEAR(@PoDate) + 1, 3, 31);
    END
    ELSE
    BEGIN
        SET @FYStart = DATEFROMPARTS(YEAR(@PoDate) - 1, 4,  1);
        SET @FYEnd   = DATEFROMPARTS(YEAR(@PoDate),     3, 31);
    END

    IF EXISTS (
        SELECT 1 FROM dbo.IN_TRNTAIL
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND DOCDT  >= @FYStart
          AND DOCDT  <= @FYEnd
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
             @UserId, GETUTCDATE(), @UserId,
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

        -- POT-LC-01 / CD-NEW-01: Restore PR line visibility after PO delete.
        -- Reset PRSTATUS 'O' -> '' so line passes the NOT IN ('O',...) filter in GetPRLines.
        -- Reset FClosed 'Y' -> 'N' for fully-ordered lines (set by SaveEntry on full order).
        -- No FClosed='Y' guard -- reset all affected lines unconditionally.
        UPDATE prl
        SET    prl.FClosed  = 'N',
               prl.PRSTATUS = CASE WHEN prl.PRSTATUS = 'O' THEN '' ELSE prl.PRSTATUS END
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
        -- Effective approval status: checks PO_ORDH flags first, then derives from PO_PARA
        -- settings so POs created before auto-confirm SaveEntry was deployed show correctly.
        CASE
            WHEN ISNULL(h.Conflg, 'N') = 'Y'
              THEN 'CONFIRMED'
            WHEN ISNULL(para.Po_Confirm, 'N') = 'N'
                 AND (ISNULL(para.PoFirstLevelApp,  'N') = 'N' OR ISNULL(h.FirstlevelApp,  'N') = 'Y')
                 AND (ISNULL(para.PoSecondLevelApp, 'N') = 'N' OR ISNULL(h.SecondlevelApp, 'N') = 'Y')
              THEN 'CONFIRMED'
            WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y'
              THEN 'First Level Approved'
            ELSE 'PENDING'
        END AS ApprovalStatus,
        (
            SELECT COUNT(*) FROM dbo.PO_ORDL l
            WHERE l.DIVCODE = h.DIVCODE
              AND l.PORDNO  = h.PORDNO
              AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
        )                                                           AS TotalLines
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.FA_SLMAS sl ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    LEFT JOIN dbo.PO_PARA para ON para.divcode = h.DIVCODE
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
-- ksp_PO_UpdateBudget  (SP #13)
-- Deducts PO order value from PO_BUDGET.BALAMT after a
-- successful PO save. Only runs when BudgetControl = 'Y'
-- in PO_PARA for the division.
-- Join chain: PO_ORDL → PO_PRL → PO_BUDGET
--   (CATCODE / CCCODE / BGRPCODE from PO_PRL)
-- YEARMON = YYYYMM derived from @PoDate.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_UpdateBudget
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check activation flag — exit silently if not active
    DECLARE @BudgetControl CHAR(1) = 'N';
    SELECT TOP 1 @BudgetControl = ISNULL(UPPER(RTRIM(BudgetControl)), 'N')
    FROM dbo.PO_PARA
    WHERE divcode = @DivCode;

    IF @BudgetControl <> 'Y'
        RETURN;

    DECLARE @YearMon INT = YEAR(@PoDate) * 100 + MONTH(@PoDate);

    UPDATE b
    SET
        b.BALAMT     = ISNULL(b.BALAMT,     0) - ROUND(l.Rate * l.ORDqty, 2),
        b.budutilamt = ISNULL(b.budutilamt, 0) + ROUND(l.Rate * l.ORDqty, 2)
    FROM dbo.PO_BUDGET b
    INNER JOIN dbo.PO_ORDL l
        ON  l.DIVCODE = @DivCode
        AND l.PORDNO  = @PoNo
        AND CAST(l.PORDDT AS DATE) = @PoDate
    INNER JOIN dbo.PO_PRL prl
        ON  prl.divcode = @DivCode
        AND prl.prno    = l.PRNO
        AND CAST(prl.prdate AS DATE) = CAST(l.PRDATE AS DATE)
        AND prl.prsno   = l.PRSNO
    WHERE b.DIVCODE = @DivCode
      AND b.CATCODE = prl.CATCODE
      AND b.CCCODE  = prl.CCCODE
      AND b.GRPCODE = prl.BGRPCODE
      AND b.YEARMON = @YearMon;
END;
GO

-- ============================================================
-- ksp_PO_UpdateBudgetQty  (SP #14)
-- Deducts PO ordered quantity from PO_BUDGETQTY_YEAR.BUD_BALQTY
-- after a successful PO save. Only runs when BudgetQty = 'Y'
-- in PO_PARA for the division.
-- Join: PO_ORDL → PO_BUDGETQTY_YEAR on DIVCODE + ITEMCODE + YEAR.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_UpdateBudgetQty
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check activation flag — exit silently if not active
    DECLARE @BudgetQty CHAR(1) = 'N';
    SELECT TOP 1 @BudgetQty = ISNULL(UPPER(RTRIM(BudgetQty)), 'N')
    FROM dbo.PO_PARA
    WHERE divcode = @DivCode;

    IF @BudgetQty <> 'Y'
        RETURN;

    DECLARE @Year INT = YEAR(@PoDate);

    UPDATE b
    SET
        b.BUD_BALQTY  = ISNULL(b.BUD_BALQTY,  0) - l.ORDqty,
        b.BUD_UTILQTY = ISNULL(b.BUD_UTILQTY, 0) + l.ORDqty
    FROM dbo.PO_BUDGETQTY_YEAR b
    INNER JOIN dbo.PO_ORDL l
        ON  l.DIVCODE = @DivCode
        AND l.PORDNO  = @PoNo
        AND CAST(l.PORDDT AS DATE) = @PoDate
    WHERE b.DIVCODE  = @DivCode
      AND b.ITEMCODE = l.ITEMCODE
      AND b.YEAR     = @Year;
END;
GO
-- ============================================================
-- CR-009: UNIQUE constraint on PO_LPORATEAPP (DIVCODE, CDOCNO, CDATE)
-- Idempotent — safe to re-run.
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PO_LPORATEAPP')
      AND name = 'UQ_LPORATEAPP_DIVCODE_CDOCNO_CDATE'
)
BEGIN
    ALTER TABLE dbo.PO_LPORATEAPP
    ADD CONSTRAINT UQ_LPORATEAPP_DIVCODE_CDOCNO_CDATE
    UNIQUE (DIVCODE, CDOCNO, CDATE);
END;
GO

-- ============================================================
-- ksp_PO_SaveLPORateHistory  (SP #15)
-- Records LPO rate history in PO_LPORATEAPP after every Add save.
-- Always active — no activation flag (FSD §8.4 / §1368).
-- Called once per PO line from PoEntryRepository after ksp_PO_SaveEntry.
-- CR-009: UPDLOCK+HOLDLOCK on MAX(CDOCNO) SELECT prevents concurrent duplicate allocation.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SaveLPORateHistory
(
    @DivCode   VARCHAR(5),
    @PoNo      NUMERIC(10,0),
    @PoDate    DATE,
    @OrderType VARCHAR(5),
    @Supplier  VARCHAR(10),
    @ItemCode  VARCHAR(10),
    @Qty       NUMERIC(12,3),
    @Rate      NUMERIC(13,4),
    @UserId    VARCHAR(15)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewCDocNo   NUMERIC(10,0);
    DECLARE @LPoRdNo     NUMERIC(10,0);
    DECLARE @LPoRdDt     DATE;
    DECLARE @LPoGrp      VARCHAR(5);
    DECLARE @LSlCode     VARCHAR(10);
    DECLARE @LRate       NUMERIC(13,4);

    BEGIN TRANSACTION;
    BEGIN TRY
        -- CDOCNO = MAX+1; UPDLOCK+HOLDLOCK prevents concurrent duplicate allocation (CR-009)
        SELECT @NewCDocNo = ISNULL(MAX(CDOCNO), 0) + 1
        FROM dbo.PO_LPORATEAPP WITH (UPDLOCK, HOLDLOCK)
        WHERE RTRIM(ISNULL(DIVCODE, '')) = RTRIM(@DivCode);

        -- Previous most-recent PO for the same item in this division (excluding current PO)
        SELECT TOP 1
            @LPoRdNo = h.PORDNO,
            @LPoRdDt = CAST(h.PORDDT AS DATE),
            @LPoGrp  = RTRIM(ISNULL(h.POGRP, '')),
            @LSlCode = RTRIM(ISNULL(h.SLCODE,  '')),
            @LRate   = l.RATE
        FROM dbo.PO_ORDL l
        INNER JOIN dbo.PO_ORDH h
            ON  h.PORDNO  = l.PORDNO
            AND h.PORDDT  = l.PORDDT
            AND h.DIVCODE = l.DIVCODE
        WHERE RTRIM(ISNULL(l.ITEMCODE, '')) = RTRIM(@ItemCode)
          AND RTRIM(ISNULL(h.DIVCODE,  '')) = RTRIM(@DivCode)
          AND h.PORDNO <> @PoNo
        ORDER BY h.PORDDT DESC, h.PORDNO DESC;

        INSERT INTO dbo.PO_LPORATEAPP
        (
            DIVCODE,    CDOCNO,
            LPORDNO,    LPORDDT,   LPOGRP,    LSLCODE,
            ITEMCODE,   CQUANTITY, LRATE,
            CDATE,      CSLCODE,   CPOGRP,    CRATE,
            CREATEDBY,  CREATEDDATE
        )
        VALUES
        (
            RTRIM(@DivCode),    @NewCDocNo,
            @LPoRdNo,           @LPoRdDt,   @LPoGrp,          @LSlCode,
            RTRIM(@ItemCode),   @Qty,        @LRate,
            GETDATE(),          RTRIM(@Supplier), RTRIM(@OrderType), @Rate,
            RTRIM(@UserId),     GETDATE()
        );

        COMMIT TRANSACTION;
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
-- ============================================================
-- ksp_PO_GetDeliverySchedule
-- Returns delivery slot schedule for a given PO (divCode + poNo + poDate).
-- Source: PO_ORDL_DETL joined to PO_ORDL + IN_ITEM.
-- Delivery Schedule field order (CEO-confirmed Option B):
--   LineNo | ItemCode | ItemName | Uom | PrNo | PoQty |
--   SlotNo | ShDate | Qty | BalanceQty | Remarks
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetDeliverySchedule
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

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
        ISNULL(l.ORDqty, 0) - ISNULL(
            (SELECT SUM(d2.Quantity)
             FROM dbo.PO_ORDL_DETL d2
             WHERE d2.divcode = d.divcode
               AND d2.pordno  = d.pordno
               AND CAST(d2.porddt AS DATE) = CAST(d.porddt AS DATE)
               AND d2.PORDSNO = d.PORDSNO), 0)                      AS BalanceQty
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
-- ksp_PO_GetApprovalStatus  [SP #17]
-- Returns current PO approval flags for a given PO.
-- Scope: FirstlevelApp + SecondlevelApp + Conflg per FSD v1.1 §5.18
--        + PO_PARA flags so frontend knows which levels are required.
-- CEO task list: SP #17 (referred to as GetApprovalHistory — Sasi confirmed
--                name as GetApprovalStatus and scope as current flag return).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetApprovalStatus
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))   AS FirstLevelApp,
        RTRIM(ISNULL(h.SecondlevelApp, 'N'))  AS SecondLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))           AS Conflg,
        CAST(h.row_version AS BIGINT)          AS RowVersion,
        ISNULL(p.PoFirstLevelApp,   'N')       AS PoFirstLevelRequired,
        ISNULL(p.PoSecondLevelApp,  'N')       AS PoSecondLevelRequired,
        ISNULL(p.Po_Confirm,        'N')       AS PoConfirmRequired,
        RTRIM(ISNULL(h.poprintflg,  'N'))      AS PrintStatus,
        CAST(CASE WHEN ISNULL(h.CANFLG, '') <> '' THEN 1 ELSE 0 END AS BIT) AS Cancelled
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_PARA p
        ON p.divcode = h.DIVCODE
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;
END;
GO

-- ============================================================
-- ksp_PO_SetFirstApproval
-- Sets PO_ORDH.FirstlevelApp = 'Y' for the given PO.
-- Optimistic concurrency guard via row_version (CD-08 FSD v3.1).
-- Inserts audit row into LogDet_PO (§7 column set, FSD v1.1).
-- Returns @Result OUTPUT: 0=success, 3=concurrency conflict, 4=not found.
--
-- CR-PO-APPROVAL-01 (see Docs/CR/CR-PO-APPROVAL-01_SetApprovalSPs.md):
-- @Disposition param + BR-03 onlineremarks cascade + BR-04 Decline handling below.
-- ✅ DEPLOYED to JAT (10-Jul-2026). Sasi's written clearance (09-Jul) covers the base
-- scope; the 10-Jul addenda (postpone-date, audit-stamp columns, CASE-logic fix) are
-- flagged in the CR as needing a follow-up confirmation to Sasi — see CR Addendum 6.
-- ============================================================
-- ksp_PO_SetFirstApproval
-- Sets PO_ORDH.FirstlevelApp = 'Y' for the given PO.
-- Optimistic concurrency guard via row_version (CD-08 FSD v3.1).
-- Inserts audit row into LogDet_PO (§7 column set, FSD v1.1).
-- Returns @Result OUTPUT: 0=success, 3=concurrency conflict, 4=not found.
--
-- CR-PO-APPROVAL-01 (see Docs/CR/CR-PO-APPROVAL-01_SetApprovalSPs.md):
-- @Disposition param + BR-03 onlineremarks cascade + BR-04 Decline handling below.
-- ✅ DEPLOYED to JAT (10-Jul-2026). Sasi's written clearance (09-Jul) covers the base
-- scope; the 10-Jul addenda (postpone-date, audit-stamp columns, CASE-logic fix) are
-- flagged in the CR as needing a follow-up confirmation to Sasi — see CR Addendum 6.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetFirstApproval
(
    @DivCode     VARCHAR(2),
    @PoNo        NUMERIC(10,0),
    @PoDate      DATE,
    @UserId      VARCHAR(25),
    @UserName    VARCHAR(50)   = NULL,
    @IpAddress   VARCHAR(50)   = NULL,
    @HostName    VARCHAR(100)  = NULL,
    @Remarks     VARCHAR(25)   = NULL,
    @RowVersion  BINARY(8)     = NULL,
    @Disposition INT           = 2,   -- CR-PO-APPROVAL-01: 1=PL Discuss,2=Approved,3=Hold,4=Declined,5=Postpone (BR-03)
    @PostponeDate DATE         = NULL, -- CR-PO-APPROVAL-01: legacy-parity postpone re-surface date (BR-05); required when @Disposition=5
    @Result      INT           OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Result = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Guard: must not already be first-approved
        IF EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(FirstlevelApp, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('PO is already first-approved.', 16, 1);
            RETURN;
        END

        -- CR-PO-APPROVAL-01 / BR-04 / legacy parity (ksp_porder_FirstLevelapproval):
        -- only Approved(2) sets 'Y'; Declined(4) and Postpone(5) reset to 'N';
        -- PL Discuss(1) and Hold(3) leave the flag untouched (legacy has no branch
        -- for them at all — self-reference is the single-statement equivalent).
        -- Postpone additionally stamps Firstlevelpostponedt with the caller-supplied
        -- re-surface date (BR-05) — ksp_PO_GetPendingFirstApproval hides the PO from
        -- the queue until that date arrives.
        -- FirstlevlAppUserID/FirstlevlAppDate stamped on every branch legacy touches
        -- (2/4/5) — matches ksp_porder_FirstLevelapproval exactly (user-reported gap,
        -- 10-Jul-2026: these two columns were missing from the first pass).
        UPDATE dbo.PO_ORDH
        SET FirstlevelApp = CASE WHEN @Disposition = 2 THEN 'Y'
                                  WHEN @Disposition IN (4) THEN 'C'
								  WHEN @Disposition IN (5) THEN 'N'
                                  ELSE FirstlevelApp END,
            FirstlevlAppUserID = CASE WHEN @Disposition IN (2, 4, 5) THEN @UserId ELSE FirstlevlAppUserID END,
            FirstlevlAppDate   = CASE WHEN @Disposition IN (2, 4, 5) THEN GETUTCDATE() ELSE FirstlevlAppDate END,
            Firstlevelpostponedt = CASE WHEN @Disposition = 5 THEN @PostponeDate ELSE Firstlevelpostponedt END
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND (@RowVersion IS NULL OR row_version = @RowVersion);

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            IF EXISTS (
                SELECT 1 FROM dbo.PO_ORDH
                WHERE DIVCODE = @DivCode
                  AND PORDNO  = @PoNo
                  AND CAST(PORDDT AS DATE) = @PoDate
            )
                SET @Result = 3; -- concurrency conflict
            ELSE
                SET @Result = 4; -- record not found
            RETURN;
        END

        -- CR-PO-APPROVAL-01 / BR-03: cascade onlineremarks to all lines of the header
        -- (same predicate shape as the BR-D1 cascade already live in SetFinalApproval).
        -- Open Question 1 (see CR doc): cascading First/Second like Final is inferred
        -- from the frontend contract, not yet FSD-confirmed — pending Sasi/CEO sign-off.
        UPDATE dbo.PO_ORDL
        SET onlineremarks = @Remarks,
            -- CR-PO-APPROVAL-01 / BR-04: Declined closes the line.
            FClosed = CASE WHEN @Disposition = 4 THEN 'Y' ELSE FClosed END
        WHERE PORDNO = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND DIVCODE = @DivCode;

        -- Audit insert into LogDet_PO (§7 column set — lowercase convention)
        INSERT INTO dbo.LogDet_PO
            (divcode, pordno, porddt,
             Trans_Name, Trans_Mod,
             Trans_UserId, Trans_date,
             Trans_IPADD, Trans_Host,
             moduleNo, Reason)
        VALUES
            (@DivCode, @PoNo, @PoDate,
             'PO_FirstLevel', 'M01',
             @UserId, GETUTCDATE(),
             ISNULL(@IpAddress, ''), ISNULL(@HostName, ''),
             1, LEFT(ISNULL(@Remarks, ''), 25));

        COMMIT TRANSACTION;
        SET @Result = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PO_SetSecondApproval
-- Sets PO_ORDH.SecondlevelApp = 'Y' for the given PO.
-- Prerequisites: FirstlevelApp must be 'Y'. PoSecondLevelApp must be
--   'Y' in PO_PARA (caller should have verified before invoking).
-- Optimistic concurrency guard via row_version (CD-08 FSD v3.1).
-- Inserts audit row into LogDet_PO (§7 column set, FSD v1.1).
-- Returns @Result OUTPUT: 0=success, 2=first-level not done,
--   3=concurrency conflict, 4=not found.
--
-- CR-PO-APPROVAL-01 (see Docs/CR/CR-PO-APPROVAL-01_SetApprovalSPs.md):
-- @Disposition param + BR-03 onlineremarks cascade + BR-04 Decline handling below.
-- ✅ DEPLOYED to JAT (10-Jul-2026). Sasi's written clearance (09-Jul) covers the base
-- scope; the 10-Jul addenda (postpone-date, Conflg-reset, audit-stamp columns,
-- CASE-logic fix) are flagged in the CR as needing a follow-up confirmation to Sasi —
-- see CR Addendum 6.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetSecondApproval
(
    @DivCode     VARCHAR(2),
    @PoNo        NUMERIC(10,0),
    @PoDate      DATE,
    @UserId      VARCHAR(25),
    @UserName    VARCHAR(50)   = NULL,
    @IpAddress   VARCHAR(50)   = NULL,
    @HostName    VARCHAR(100)  = NULL,
    @Remarks     VARCHAR(25)   = NULL,
    @RowVersion  BINARY(8)     = NULL,
    @Disposition INT           = 2,   -- CR-PO-APPROVAL-01: 1=PL Discuss,2=Approved,3=Hold,4=Declined,5=Postpone (BR-03)
    @PostponeDate DATE         = NULL, -- CR-PO-APPROVAL-01: legacy-parity postpone re-surface date (BR-05); required when @Disposition=5
    @Result      INT           OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Result = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Prerequisite: first-level must already be approved
        IF NOT EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(FirstlevelApp, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @Result = 2; -- first-level approval not done
            RAISERROR('PO first-level approval is not complete.', 16, 1);
            RETURN;
        END

        -- Guard: must not already be second-approved
        IF EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(SecondlevelApp, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('PO is already second-approved.', 16, 1);
            RETURN;
        END

        -- CR-PO-APPROVAL-01 / BR-04 / legacy parity (ksp_porder_SecondLevelapproval):
        -- only Approved(2) sets 'Y'; Declined(4) and Postpone(5) reset to 'N';
        -- PL Discuss(1) and Hold(3) leave the flag untouched. Postpone additionally
        -- stamps SecondLevelPostPoneDt with the caller-supplied re-surface date
        -- (BR-05) — ksp_PO_GetPendingSecondApproval hides the PO until that date.
        -- SecondLevelAppUserId/SecondLevelAppDate stamped on every branch legacy
        -- touches (2/4/5) — matches ksp_porder_SecondLevelapproval exactly
        -- (user-reported gap, 10-Jul-2026).
        UPDATE dbo.PO_ORDH
        SET SecondlevelApp = CASE WHEN @Disposition = 2 THEN 'Y'
                                   WHEN @Disposition IN (4, 5) THEN 'N'
                                   ELSE SecondlevelApp END,
            SecondLevelAppUserId = CASE WHEN @Disposition IN (2, 4, 5) THEN @UserId ELSE SecondLevelAppUserId END,
            SecondLevelAppDate   = CASE WHEN @Disposition IN (2, 4, 5) THEN GETUTCDATE() ELSE SecondLevelAppDate END,
            SecondLevelPostPoneDt = CASE WHEN @Disposition = 5 THEN @PostponeDate ELSE SecondLevelPostPoneDt END
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND (@RowVersion IS NULL OR row_version = @RowVersion);

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            IF EXISTS (
                SELECT 1 FROM dbo.PO_ORDH
                WHERE DIVCODE = @DivCode
                  AND PORDNO  = @PoNo
                  AND CAST(PORDDT AS DATE) = @PoDate
            )
                SET @Result = 3; -- concurrency conflict
            ELSE
                SET @Result = 4; -- record not found
            RETURN;
        END

        -- Legacy parity (ksp_porder_SecondLevelapproval, lines 262-265): Approve at
        -- Second Level unconditionally resets Conflg back to 'N' with a fresh
        -- Appuserid/Appip/Appdate stamp, regardless of prior Final-level state.
        -- Sasi confirmed 10-Jul-2026: follow legacy exactly for this quirk.
        IF @Disposition = 2
        BEGIN
            UPDATE dbo.PO_ORDH
            SET Conflg = 'N', Appuserid = @UserId, Appip = @IpAddress, Appdate = GETUTCDATE()
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate;
        END

        -- CR-PO-APPROVAL-01 / BR-03: cascade onlineremarks to all lines of the header
        -- (same predicate shape as the BR-D1 cascade already live in SetFinalApproval).
        -- Open Question 1 (see CR doc): cascading First/Second like Final is inferred
        -- from the frontend contract, not yet FSD-confirmed — pending Sasi/CEO sign-off.
        UPDATE dbo.PO_ORDL
        SET onlineremarks = @Remarks,
            -- CR-PO-APPROVAL-01 / BR-04: Declined closes the line.
            FClosed = CASE WHEN @Disposition = 4 THEN 'Y' ELSE FClosed END
        WHERE PORDNO = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND DIVCODE = @DivCode;

        -- Audit insert into LogDet_PO (§7 column set — lowercase convention)
        INSERT INTO dbo.LogDet_PO
            (divcode, pordno, porddt,
             Trans_Name, Trans_Mod,
             Trans_UserId, Trans_date,
             Trans_IPADD, Trans_Host,
             moduleNo, Reason)
        VALUES
            (@DivCode, @PoNo, @PoDate,
             'PO_SecondLevel', 'M01',
             @UserId, GETUTCDATE(),
             ISNULL(@IpAddress, ''), ISNULL(@HostName, ''),
             1, LEFT(ISNULL(@Remarks, ''), 25));

        COMMIT TRANSACTION;
        SET @Result = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PO_SetFinalApproval
-- Sets PO_ORDH.Conflg = 'Y' (Final Confirmation) for the given PO.
-- Prerequisites:
--   - FirstlevelApp = 'Y' (always required)
--   - SecondlevelApp = 'Y' if PO_PARA.PoSecondLevelApp = 'Y'
-- Optimistic concurrency guard via row_version (CD-08 FSD v3.1).
-- Inserts audit row into LogDet_PO (§7 column set, FSD v1.1).
-- Returns @Result OUTPUT: 0=success, 2=prerequisites not met,
--   3=concurrency conflict, 4=not found.
--
-- CR-PO-APPROVAL-01 (see Docs/CR/CR-PO-APPROVAL-01_SetApprovalSPs.md):
-- @Disposition param + BR-04 FClosed-on-Decline below.
-- The BR-D1 cascade UPDATE further down was already live before this CR (commit
-- 21b2275) — unaffected by this change.
-- ✅ DEPLOYED to JAT (10-Jul-2026). Sasi's written clearance (09-Jul) covers the base
-- scope; the 10-Jul addenda (postpone-date, audit-stamp columns, CASE-logic fix) are
-- flagged in the CR as needing a follow-up confirmation to Sasi — see CR Addendum 6.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetFinalApproval
(
    @DivCode     VARCHAR(2),
    @PoNo        NUMERIC(10,0),
    @PoDate      DATE,
    @UserId      VARCHAR(25),
    @UserName    VARCHAR(50)   = NULL,
    @IpAddress   VARCHAR(50)   = NULL,
    @HostName    VARCHAR(100)  = NULL,
    @Remarks     VARCHAR(25)   = NULL,
    @RowVersion  BINARY(8)     = NULL,
    @Disposition INT           = 2,   -- CR-PO-APPROVAL-01: 1=PL Discuss,2=Approved,3=Hold,4=Declined,5=Postpone (BR-03)
    @PostponeDate DATE         = NULL, -- CR-PO-APPROVAL-01: legacy-parity postpone re-surface date (BR-05); required when @Disposition=5
    @Result      INT           OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Result = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @PoSecondLevelApp CHAR(1);
        SELECT @PoSecondLevelApp = ISNULL(PoSecondLevelApp, 'N')
        FROM dbo.PO_PARA
        WHERE divcode = @DivCode;

        -- Prerequisite: first-level must be approved
        IF NOT EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(FirstlevelApp, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @Result = 2;
            RAISERROR('PO first-level approval is not complete.', 16, 1);
            RETURN;
        END

        -- Prerequisite: second-level must be approved (when required)
        IF @PoSecondLevelApp = 'Y'
           AND NOT EXISTS (
               SELECT 1 FROM dbo.PO_ORDH
               WHERE DIVCODE = @DivCode
                 AND PORDNO  = @PoNo
                 AND CAST(PORDDT AS DATE) = @PoDate
                 AND RTRIM(ISNULL(SecondlevelApp, 'N')) = 'Y'
           )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @Result = 2;
            RAISERROR('PO second-level approval is not complete.', 16, 1);
            RETURN;
        END

        -- Guard: must not already be confirmed
        IF EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(Conflg, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('PO is already confirmed.', 16, 1);
            RETURN;
        END

        -- CR-PO-APPROVAL-01 / BR-D4: only Approved (2) sets Conflg='Y'. Decline/Hold/
        -- Postpone leave Conflg untouched (still 'N' from the guard above) — BR-D4
        -- explicitly does NOT reset FirstlevelApp/SecondlevelApp on any disposition;
        -- this guard clause is the intentional, explicit expression of that rule —
        -- do NOT add a FirstlevelApp/SecondlevelApp reset here by copy-paste from
        -- First/Second Level's Decline handling. Open Question (CR doc): whether
        -- Decline/Hold/Postpone at Final should set some other Conflg value has no
        -- FSD-stated answer — "unchanged" is the safest reading of BR-D4's "modifies
        -- conflg and PO_ORDL only" wording, pending Sasi/CEO confirmation.
        -- Postpone stamps the generic postponedt column with the caller-supplied
        -- re-surface date (BR-05, legacy parity ksp_porder_FinalLevelapproval) —
        -- ksp_PO_GetPendingFinalApproval hides the PO until that date arrives.
        -- Appuserid/Appip/Appdate stamped on every branch legacy touches (2/4/5) —
        -- matches ksp_porder_FinalLevelapproval exactly (user-reported gap,
        -- 10-Jul-2026). Not the same columns as BR-D4's guard above — that guard
        -- protects FirstlevelApp/SecondlevelApp only, untouched by this stamp.
        UPDATE dbo.PO_ORDH
        SET Conflg = CASE WHEN @Disposition = 2 THEN 'Y' ELSE Conflg END,
            Appuserid  = CASE WHEN @Disposition IN (2, 4, 5) THEN @UserId ELSE Appuserid END,
            Appip      = CASE WHEN @Disposition IN (2, 4, 5) THEN @IpAddress ELSE Appip END,
            Appdate    = CASE WHEN @Disposition IN (2, 4, 5) THEN GETUTCDATE() ELSE Appdate END,
            postponedt = CASE WHEN @Disposition = 5 THEN @PostponeDate ELSE postponedt END
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND (@RowVersion IS NULL OR row_version = @RowVersion);

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            IF EXISTS (
                SELECT 1 FROM dbo.PO_ORDH
                WHERE DIVCODE = @DivCode
                  AND PORDNO  = @PoNo
                  AND CAST(PORDDT AS DATE) = @PoDate
            )
                SET @Result = 3; -- concurrency conflict
            ELSE
                SET @Result = 4; -- record not found
            RETURN;
        END

        -- BR-D1: Cascade write to all lines of the header (Final Level action applies to all PO_ORDL rows)
        -- CR-PO-APPROVAL-01 / BR-04: Declined additionally closes all cascaded lines.
        UPDATE dbo.PO_ORDL
        SET onlineremarks = @Remarks,
            FClosed = CASE WHEN @Disposition = 4 THEN 'Y' ELSE FClosed END
        WHERE PORDNO = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND DIVCODE = @DivCode;

        -- Audit insert into LogDet_PO (§7 column set — lowercase convention)
        INSERT INTO dbo.LogDet_PO
            (divcode, pordno, porddt,
             Trans_Name, Trans_Mod,
             Trans_UserId, Trans_date,
             Trans_IPADD, Trans_Host,
             moduleNo, Reason)
        VALUES
            (@DivCode, @PoNo, @PoDate,
             'PO_FinalLevel', 'M01',
             @UserId, GETUTCDATE(),
             ISNULL(@IpAddress, ''), ISNULL(@HostName, ''),
             1, LEFT(ISNULL(@Remarks, ''), 25));

        COMMIT TRANSACTION;
        SET @Result = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
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
        RTRIM(ISNULL(cby.user_name, ISNULL(h.createdby, '')))      AS CreatedBy,
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
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(h.createdby)
                   AND RTRIM(divcode) = RTRIM(h.DIVCODE))                 cby
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
        ISNULL(l.cgstamt,0) + ISNULL(l.sgstamt,0) + ISNULL(l.igstamt,0) AS TaxAmt,
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
-- ksp_PO_SaveEntry: tax/charge formula alignment
-- POT-TC-01/CR-012: packing base=netAfterDisc; GST base=position-flag-adjusted; OTHCHGS=direct Rs amount
-- ============================================================
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
    @FreightPer       NUMERIC(10,2)  = 0,    -- CR-009: derives FreightAmt when FreightAmt=0
    @PackPer          NUMERIC(10,2)  = 0,
    @PackAmt          NUMERIC(13,2)  = 0,
    @InsurPer         NUMERIC(10,2)  = 0,
    @InsurAmt         NUMERIC(13,2)  = 0,
    @SurchargePer     NUMERIC(10,2)  = 0,
    @AddTaxPer        NUMERIC(10,2)  = 0,
    @RoundOff         NUMERIC(13,2)  = 0,
    @TotalOrdVal      NUMERIC(18,2)  = 0,   -- FD-01: grand total (incl. charges + GST + TCS + roundoff) supplied by frontend
    @FileNo           VARCHAR(20)    = NULL,
    @FcaFob           NUMERIC(13,2)  = 0,
    @FreightType      VARCHAR(10)    = 'PAID',
    @DiscApp          VARCHAR(10)    = 'BEFORE',  -- disflg:   'BEFORE'→'B', 'AFTER'→'A'
    @PackApp          VARCHAR(10)    = 'BEFORE',  -- PACK_FLG: 'BEFORE'→'B', 'AFTER'→'A'
    @FreightPosition  VARCHAR(10)    = 'BEFORE',  -- FRT_FLG:  'BEFORE'→'B', 'AFTER'→'A'
    @InsurancePosition VARCHAR(10)   = 'BEFORE',  -- Ins_Flg:  'BEFORE'→'B', 'AFTER'→'A'
    @CessApp          VARCHAR(10)    = 'BEFORE',  -- Cess_Flg: 'BEFORE'→'B', 'AFTER'→'A'
    -- Payment
    @PayMode          VARCHAR(10)    = 'DIRECT',
    @DirectInstr      VARCHAR(200)   = NULL,
    @BankCode         VARCHAR(10)    = NULL,
    @PaymentTerms     VARCHAR(100)   = NULL,
    @PayTermCode      VARCHAR(25)    = NULL,   -- paytermcode: Ig_PayTerm.PayTerm_Code lookup value stored to PO_ORDH
    @AdvPer           NUMERIC(10,2)  = 0,
    @AdvAmt           NUMERIC(13,2)  = 0,
    @ModeOfPayment    VARCHAR(20)    = NULL,
    @PayRef           VARCHAR(50)    = NULL,   -- confirmed by SasiR: maps to CHQNO (non-bank payment ref; COALESCE with @ChequeNo)
    @PayRefDate       DATE           = NULL,   -- confirmed by SasiR: maps to CHQDT (non-bank payment ref date; COALESCE with @ChequeDate)
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
    @OtherLevies      VARCHAR(200)   = NULL,   -- confirmed by SasiR: maps to Note2 in PO_ORDH
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

        -- Order-level guard only (NOT a line-level check) — a line netting to 0 via
        -- 100% discount remains valid (Option A / POT-Disc-02/03: free samples,
        -- warranty, inter-unit at nil value). The entire order cannot net to zero
        -- or negative. Mirrors the frontend save guard in usePoTransferForm.ts.
        IF ISNULL(@TotalOrdVal, 0) <= 0
            RAISERROR('Total Order Value must be greater than zero. Please verify the commercial charges and discount values.', 16, 1);

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

        -- ── 3. Date validations (CR-017, CR-018, BR-01) ─────────────────────────
        -- CR-017: Always reject future PO dates.
        DECLARE @Today DATE = CAST(GETDATE() AS DATE);
        IF @PoDate > @Today
            RAISERROR('PO Date cannot be a future date.', 16, 1);

        -- CR-017: Always reject if earlier than last PO date in this division.
        DECLARE @MaxPoDate DATE;
        SELECT @MaxPoDate = CAST(MAX(PORDDT) AS DATE) FROM dbo.PO_ORDH WHERE DIVCODE = @DivCode;
        IF @MaxPoDate IS NOT NULL AND @PoDate < @MaxPoDate
            RAISERROR('PO Date cannot be earlier than the last Purchase Order date for this division.', 16, 1);

        -- CR-018: Reference Date must not be after PO Date.
        IF @RefDate IS NOT NULL AND @RefDate > @PoDate
            RAISERROR('Reference Date cannot be later than the PO Date.', 16, 1);

        -- BR-01: Backdate check (FSD §4.6) — when BACKDATE='N', date must equal today or max PO date.
        DECLARE @BackDate CHAR(1) = 'Y';
        SELECT TOP 1 @BackDate = ISNULL(UPPER(RTRIM(BACKDATE)), 'Y') FROM dbo.IN_PARA;
        IF @BackDate <> 'Y'
        BEGIN
            IF @PoDate <> @Today
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
            ISNULL(j.DiscPer,      0)        AS DiscPer,
            ISNULL(j.PackingPer,   0)        AS PackingPer,
            ISNULL(j.FreightPer,   0)        AS FreightPer,
            ISNULL(j.InsurancePer, 0)        AS InsurancePer,
            ISNULL(j.CessPer,      0)        AS CessPer,
            ISNULL(j.FcaFob,       0)        AS FcaFob,
            ISNULL(j.OtherCharges, 0)        AS OtherCharges,
            RTRIM(ISNULL(j.AddTaxCode, ''))  AS AddTaxCode,
            ISNULL(j.AddTaxPer,    0)        AS AddTaxPer,
            RTRIM(ISNULL(j.DiscApp,       'BEFORE')) AS DiscApp,
            RTRIM(ISNULL(j.PackApp,       'BEFORE')) AS PackApp,
            RTRIM(ISNULL(j.FreightPos,    'BEFORE')) AS FreightPos,
            RTRIM(ISNULL(j.InsuranceDuty, 'BEFORE')) AS InsuranceDuty,
            RTRIM(ISNULL(j.CessTaxPos,    'BEFORE')) AS CessTaxPos,
            -- Option A: frontend-computed ₹ amounts (0 when not sent = SP formula is fallback)
            ISNULL(j.FeGrossVal,  0) AS FeGrossVal,
            ISNULL(j.FeDiscAmt,   0) AS FeDiscAmt,
            ISNULL(j.FePackAmt,   0) AS FePackAmt,
            ISNULL(j.FeFrgtAmt,   0) AS FeFrgtAmt,
            ISNULL(j.FeInsAmt,    0) AS FeInsAmt,
            ISNULL(j.FeCgstAmt,   0) AS FeCgstAmt,
            ISNULL(j.FeSgstAmt,   0) AS FeSgstAmt,
            ISNULL(j.FeIgstAmt,   0) AS FeIgstAmt,
            ISNULL(j.FeTcsAmt,    0) AS FeTcsAmt,
            ISNULL(j.FeAddTaxAmt, 0) AS FeAddTaxAmt,
            ISNULL(j.LandingCost, 0) AS LandingCost,
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
            DiscPer       NUMERIC(10,2)  '$.discPer',
            PackingPer    NUMERIC(10,2)  '$.packingPer',
            FreightPer    NUMERIC(10,2)  '$.freightPer',
            InsurancePer  NUMERIC(10,2)  '$.insurancePer',
            CessPer       NUMERIC(10,2)  '$.cessPer',
            FcaFob        NUMERIC(13,2)  '$.fcaFob',
            OtherCharges  NUMERIC(13,2)  '$.otherCharges',
            AddTaxCode    VARCHAR(10)    '$.addTaxCode',
            AddTaxPer     NUMERIC(10,2)  '$.addTaxPer',
            DiscApp       VARCHAR(10)    '$.discApp',
            PackApp       VARCHAR(10)    '$.packApp',
            FreightPos    VARCHAR(10)    '$.freightPos',
            InsuranceDuty VARCHAR(10)    '$.insuranceDuty',
            CessTaxPos    VARCHAR(10)    '$.cessTaxPos',
            FeGrossVal    NUMERIC(13,2)  '$.grossVal',
            FeDiscAmt     NUMERIC(13,2)  '$.discAmt',
            FePackAmt     NUMERIC(13,2)  '$.packingAmt',
            FeFrgtAmt     NUMERIC(13,2)  '$.freightAmt',
            FeInsAmt      NUMERIC(13,2)  '$.insuranceAmt',
            FeCgstAmt     NUMERIC(13,2)  '$.cgstAmt',
            FeSgstAmt     NUMERIC(13,2)  '$.sgstAmt',
            FeIgstAmt     NUMERIC(13,2)  '$.igstAmt',
            FeTcsAmt      NUMERIC(13,2)  '$.tcsAmt',
            FeAddTaxAmt   NUMERIC(13,2)  '$.addTaxAmt',
            LandingCost   NUMERIC(15,2)  '$.landingCost',
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

        -- POT-Disc-02/03 Option A (CEO 02-Jul-2026): the >=100%% discount hard block is
        -- removed — 100%% discount (net order value = 0) is a valid scenario (free
        -- samples / warranty / inter-unit nil-value). The only discount guard is the
        -- net-order-value >= 0 check in step 7 below.

        -- ── 6. Allocate PO number (FY-scoped MAX+1) ──────────────────────────
        -- Unique key is (DIVCODE, PORDNO, PORDDT) — numbers restart from STDOCNO
        -- at the start of each financial year. UPDLOCK+HOLDLOCK inside BEGIN TRAN
        -- prevents concurrent transactions from reading the same MAX before either commits.
        DECLARE @StartDocNo NUMERIC(10,0) = 1;
        SELECT @StartDocNo = ISNULL(STDOCNO, 1)
        FROM dbo.PO_DOC_PARA
        WHERE TC = 'PURCHASE ORDER';

        SELECT @PoNo = ISNULL(MAX(PORDNO), 0) + 1
        FROM dbo.PO_ORDH WITH (UPDLOCK, HOLDLOCK)
        WHERE CAST(PORDDT AS DATE) >= @FDate
          AND CAST(PORDDT AS DATE) <= @LDate;

        IF @PoNo < @StartDocNo
            SET @PoNo = @StartDocNo;

        -- ── 7a. Division approval parameters (FSD §5.8 / §5.9) ────────────────
        -- BR-09: If PoFirstLevelApp='N', auto-approve first level on save.
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
        -- @CgstAmt/@SgstAmt/@IgstAmt are computed in step 9b after PO_ORDL INSERT,
        -- from position-flag-adjusted per-line amounts matching the frontend formula.
        DECLARE @OrdVal  NUMERIC(18,2);
        DECLARE @CgstAmt NUMERIC(18,2) = 0;
        DECLARE @SgstAmt NUMERIC(18,2) = 0;
        DECLARE @IgstAmt NUMERIC(18,2) = 0;
        SELECT @OrdVal = SUM(ROUND(Rate * Qty, 2)) FROM #Lines;

        -- Net after per-line discount — correct base for header Pack/Ins/Freight derivation (matches frontend)
        DECLARE @NetAfterLineDisc NUMERIC(18,2);
        SELECT @NetAfterLineDisc = SUM(
            ROUND(Rate * Qty, 2) - ROUND(Rate * Qty * DiscPer / 100.0, 2)
        ) FROM #Lines;

        -- POT-Disc-02/03 Option A: net order value must not be negative. Primary check
        -- is the frontend grand total (@TotalOrdVal = SUM(line net) + round-off); the
        -- fallback (direct SP callers that do not send a total) resolves each line's
        -- discount the same way LineCalc does (FeDiscAmt primary, DiscPer%% fallback).
        DECLARE @NetOfDiscSum NUMERIC(18,2);
        SELECT @NetOfDiscSum = SUM(
            ROUND(Rate * Qty, 2)
            - ISNULL(NULLIF(FeDiscAmt, 0), ROUND(Rate * Qty * DiscPer / 100.0, 2))
        ) FROM #Lines;

        IF (CASE WHEN @TotalOrdVal <> 0 THEN @TotalOrdVal ELSE ISNULL(@NetOfDiscSum, 0) END) < 0
            RAISERROR('Net Order Value cannot be negative.', 16, 1);

        -- ORDVAL to persist: client grand total when supplied; else net-of-discount sum
        -- (equals SUM(Rate*Qty) when no discount — matches the old FD-01 fallback; with
        -- a discount it stores the true order value, so a valid 100%% discount PO
        -- persists ORDVAL = 0 instead of the undiscounted gross).
        DECLARE @PersistOrdVal NUMERIC(18,2) =
            CASE WHEN @TotalOrdVal <> 0 THEN @TotalOrdVal
                 ELSE ISNULL(@NetOfDiscSum, ISNULL(@OrdVal, 0)) END;

        -- Derive FreightAmt from FreightPer when FreightAmt not supplied (uses net-after-disc base)
        IF @FreightPer > 0 AND @FreightAmt = 0
            SET @FreightAmt = ROUND(@NetAfterLineDisc * @FreightPer / 100.0, 2);

        -- Pack_Amt / Ins_Amt back-filled in step 9b from SUM(PO_ORDL) after line inserts

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
            DISPER, Cessper, FREIGHT, PCKPER, Pack_Amt, INSPER, Ins_Amt, SURPER, ADDTAXPER,
            FILENO, FCACharg, FRTFLG, disflg, PACK_FLG, FRT_FLG, Ins_Flg, Cess_Flg,
            PAYMENT, DIRECT_INS, BANK_CODE, PAYTERMS, paytermcode,
            ADV_PER, ADV_AMT, advpaymenttype,
            CHQNO, CHQDT, CRDDAYS,
            Duedate, DEL_INS1, Billadd, SPL_INS, DEL_INS2,
            Note, Note2, PriceTerm, RemarksPF, RemarksIns, RemarksFrt,
            ORDVAL, roff,
            CGSTAMT, SGSTAMT, IGSTAMT,
            cust_gstinno, cust_gststcode,
            FirstlevelApp, Conflg, poprintflg,
            createdby, createddt, htcs_amt
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
            ISNULL(@PackAmt,      0),
            ISNULL(@InsurPer,     0),
            ISNULL(@InsurAmt,     0),
            ISNULL(@SurchargePer, 0),
            ISNULL(@AddTaxPer,    0),
            NULLIF(RTRIM(ISNULL(@FileNo,'')),       ''),
            ISNULL(@FcaFob, 0),
            CASE WHEN UPPER(RTRIM(ISNULL(@FreightType,''))) = 'TOPAY' THEN 'Y' ELSE 'N' END,  -- FrtToPayFlg: legacy flag expects 'Y'/'N'; empty string converts to 'N'
            CASE WHEN UPPER(RTRIM(ISNULL(@DiscApp,'')))    = 'AFTER' THEN 'A' ELSE 'B' END,  -- disflg
            CASE WHEN UPPER(RTRIM(ISNULL(@PackApp,'')))          = 'AFTER' THEN 'A' ELSE 'B' END,  -- PACK_FLG
            CASE WHEN UPPER(RTRIM(ISNULL(@FreightPosition,'')))  = 'AFTER' THEN 'A' ELSE 'B' END,  -- FRT_FLG
            CASE WHEN UPPER(RTRIM(ISNULL(@InsurancePosition,''))) = 'AFTER' THEN 'A' ELSE 'B' END, -- Ins_Flg
            CASE WHEN UPPER(RTRIM(ISNULL(@CessApp,'')))           = 'AFTER' THEN 'A' ELSE 'B' END, -- Cess_Flg
            CASE WHEN UPPER(RTRIM(ISNULL(@PayMode,''))) = 'BANK' THEN 'B' ELSE 'D' END,
            NULLIF(RTRIM(ISNULL(@DirectInstr,'')),   ''),
            NULLIF(RTRIM(ISNULL(@BankCode,'')),      ''),
            NULLIF(RTRIM(ISNULL(@PaymentTerms,'')),  ''),
            NULLIF(RTRIM(ISNULL(@PayTermCode,'')),   ''),   -- paytermcode: Ig_PayTerm lookup code; stored to PO_ORDH, read by ksp_PO_GetPrint
            ISNULL(@AdvPer, 0),
            ISNULL(@AdvAmt, 0),
            NULLIF(LEFT(RTRIM(ISNULL(@ModeOfPayment,'')), 5), ''),   -- advpaymenttype VARCHAR(5) — confirmed 2026-06-22
            COALESCE(NULLIF(RTRIM(ISNULL(@ChequeNo, '')), ''), NULLIF(RTRIM(ISNULL(@PayRef, '')), '')),   -- CHQNO: bank cheque no. (primary) else payment ref
            COALESCE(@ChequeDate, @PayRefDate),                                                            -- CHQDT: bank cheque date (primary) else payment ref date
            ISNULL(@CreditDays, 0),
            @DeliveryDate,
            NULLIF(RTRIM(ISNULL(@DeliveryLocation,'')), ''),
            NULLIF(RTRIM(ISNULL(@BillingAddress,'')),   ''),
            NULLIF(RTRIM(ISNULL(@SpecialInstr,'')),     ''),
            NULLIF(RTRIM(ISNULL(@Despatch,'')),         ''),
            NULLIF(RTRIM(ISNULL(@Purpose,'')),          ''),   -- Note
            NULLIF(RTRIM(ISNULL(@OtherLevies,'')),      ''),   -- Note2 (confirmed by SasiR)
            NULLIF(RTRIM(ISNULL(@PricingTerms,'')),     ''),
            NULLIF(RTRIM(ISNULL(@PackForwarding,'')),   ''),
            NULLIF(RTRIM(ISNULL(@Insurance,'')),        ''),
            NULLIF(RTRIM(ISNULL(@Freight,'')),          ''),
            -- FD-01 + POT-Disc Option A: client grand total; fallback @PersistOrdVal (net-of-discount sum)
            @PersistOrdVal,
            ISNULL(@RoundOff, 0),     -- roff: client-supplied round-off
            ISNULL(@CgstAmt, 0),
            ISNULL(@SgstAmt, 0),
            ISNULL(@IgstAmt, 0),
            @SupGstin,
            @SupGstState,
            @FirstLevelApp,           -- 'Y' if PoFirstLevelApp='N' (BR-09), else 'N'
            @Conflg,                  -- 'Y' if PoConf='N' (auto-confirm), else 'N'
            'N',                      -- poprintflg
            @UserId,
            @CreatedDt, 
			@TcsPer
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

        -- ── 9. INSERT PO_ORDL via CTE — per-line derived amounts ─────────────────
        -- POT-TC-01 / CR-012: Packing base = net-of-discount (matches frontend).
        -- GST base adjusts per per-line position flags (BEFORE/AFTER).
        -- OTHCHGS is a direct ₹ amount, not a percentage — stored as-is.
        ;WITH LineCalc AS (
            SELECT
                l.*,
                prl.prdate                                                                                AS PrlPrDate,
                -- PO_ORDL.SubCost is sourced from the PR line's cost-centre code
                -- (PO_PRL.CCCODE numeric(4,0)), not PO_PRL.SubCost.
                ISNULL(prl.CCCODE, 0)                                                                    AS SubCostCode,
                RTRIM(ISNULL(prl.Depcode, ''))                                                           AS DepCode,
                -- Option A: frontend ₹ primary; SP formula fallback when 0
                ISNULL(NULLIF(l.FeGrossVal, 0), ROUND(l.Rate * l.Qty, 2))                               AS GrossVal,
                ISNULL(NULLIF(l.FeDiscAmt, 0),  ROUND(l.Rate * l.Qty * l.DiscPer / 100.0, 2))          AS DiscAmt,
                -- POT-TD-07/08/09/10: fall back to header % when per-line value is 0
                COALESCE(NULLIF(l.PackingPer,   0), @PackPer)                                            AS EffPackPer,
                COALESCE(NULLIF(l.FreightPer,   0), @FreightPer)                                         AS EffFrgtPer,
                COALESCE(NULLIF(l.InsurancePer, 0), @InsurPer)                                           AS EffInsPer,
                COALESCE(NULLIF(l.CessPer,      0), @CessPer)                                            AS EffCessPer,
                -- Packing / Freight / Insurance: frontend ₹ primary; net-after-disc formula fallback
                ISNULL(NULLIF(l.FePackAmt, 0),
                    ROUND(((l.Rate * l.Qty) - ROUND(l.Rate * l.Qty * l.DiscPer / 100.0, 2))
                          * COALESCE(NULLIF(l.PackingPer,   0), @PackPer)   / 100.0, 2))                 AS PackAmt,
                ISNULL(NULLIF(l.FeFrgtAmt, 0),
                    ROUND(((l.Rate * l.Qty) - ROUND(l.Rate * l.Qty * l.DiscPer / 100.0, 2))
                          * COALESCE(NULLIF(l.FreightPer,   0), @FreightPer) / 100.0, 2))                AS FrgtAmt,
                ISNULL(NULLIF(l.FeInsAmt, 0),
                    ROUND(((l.Rate * l.Qty) - ROUND(l.Rate * l.Qty * l.DiscPer / 100.0, 2))
                          * COALESCE(NULLIF(l.InsurancePer, 0), @InsurPer)   / 100.0, 2))               AS InsAmt
            FROM #Lines l
            INNER JOIN dbo.PO_PRL prl
                ON prl.divcode = @DivCode AND prl.prno = l.PrNo
               AND CAST(prl.prdate AS DATE) = l.PrDate AND prl.prsno = l.PrSno
        ),
        LineCalcGst AS (
            SELECT
                c.*,
                -- GST assessable base: gross ± position-flag adjustments (CR-012 / POT-TD-10)
                ROUND(
                    c.GrossVal
                    - CASE WHEN UPPER(RTRIM(c.DiscApp))       = 'BEFORE' THEN c.DiscAmt ELSE 0 END
                    + CASE WHEN UPPER(RTRIM(c.FreightPos))    = 'BEFORE' THEN c.FrgtAmt ELSE 0 END
                    + CASE WHEN UPPER(RTRIM(c.PackApp))       = 'BEFORE' THEN c.PackAmt ELSE 0 END
                    + CASE WHEN UPPER(RTRIM(c.InsuranceDuty)) = 'BEFORE' THEN c.InsAmt  ELSE 0 END
                , 2)                                                                                      AS GstBase
            FROM LineCalc c
        ),
        LineCalcFinal AS (
            SELECT
                c.*,
                ISNULL(NULLIF(c.FeCgstAmt,   0), ROUND(c.GstBase * c.CgstPer   / 100.0, 2)) AS CgstAmtFinal,
                ISNULL(NULLIF(c.FeSgstAmt,   0), ROUND(c.GstBase * c.SgstPer   / 100.0, 2)) AS SgstAmtFinal,
                ISNULL(NULLIF(c.FeIgstAmt,   0), ROUND(c.GstBase * c.IgstPer   / 100.0, 2)) AS IgstAmtFinal,
                ISNULL(NULLIF(c.FeTcsAmt,    0), ROUND(c.GrossVal * c.TcsPer   / 100.0, 2)) AS TcsAmtFinal,
                ISNULL(NULLIF(c.FeAddTaxAmt, 0), ROUND(c.GrossVal * c.AddTaxPer / 100.0, 2)) AS AddTaxAmtFinal
            FROM LineCalcGst c
        )
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
            reqidpo,  reqnamepo,
            disper,   disamt,
            PACKPER,  Packamt,
            Frgt1per, Frgt1Amt,
            Ins_per,  Ins_amt,
            OTHCHGS,
            cess_per, cess_amt,
            ADDTAX_CODE, ADDTAXPER, ADDTAXAMT,
            FCACharg,
            DISFLG, PACK_FLG, FRT_FLG, Ins_Flg, Cess_Flg,
            SubCost, DepCode, LANDCOST, FRate, FValue
        )
        SELECT
            @DivCode, @PoNo, @ActualPoDt, c.PORDSNO, @OrderType,
            c.ItemCode,
            c.PrNo,
            c.PrlPrDate,
            c.PrSno,
            c.Rate,
            c.Qty,
            c.GrossVal,
            LEFT(c.TaxCode,  5),
            c.CgstPer + c.SgstPer + c.IgstPer,
            c.CgstAmtFinal + c.SgstAmtFinal + c.IgstAmtFinal,
            LEFT(c.HsnCode,  8),
            c.CgstPer,
            c.CgstAmtFinal,
            LEFT(c.CgstCode, 5),
            c.SgstPer,
            c.SgstAmtFinal,
            LEFT(c.SgstCode, 5),
            c.IgstPer,
            c.IgstAmtFinal,
            LEFT(c.IgstCode, 5),
            c.TcsPer,
            c.TcsAmtFinal,
            NULLIF(c.RequesterId,   ''),   -- reqidpo   VARCHAR(50) — no cap needed
            NULLIF(c.RequesterName, ''),   -- reqnamepo VARCHAR(100) — no cap needed
            c.DiscPer,
            c.DiscAmt,
            c.EffPackPer,
            c.PackAmt,
            c.EffFrgtPer,
            c.FrgtAmt,
            c.EffInsPer,
            c.InsAmt,
            c.OtherCharges,                              -- direct ₹ amount (not a %)
            c.EffCessPer,
            ROUND(c.GrossVal * c.EffCessPer / 100.0, 2),
            NULLIF(c.AddTaxCode, ''),
            c.AddTaxPer,
            c.AddTaxAmtFinal,
            c.FcaFob,
            CASE WHEN UPPER(RTRIM(ISNULL(c.DiscApp,       ''))) = 'AFTER' THEN 'A' ELSE 'B' END,
            CASE WHEN UPPER(RTRIM(ISNULL(c.PackApp,       ''))) = 'AFTER' THEN 'A' ELSE 'B' END,
            CASE WHEN UPPER(RTRIM(ISNULL(c.FreightPos,    ''))) = 'AFTER' THEN 'A' ELSE 'B' END,
            CASE WHEN UPPER(RTRIM(ISNULL(c.InsuranceDuty, ''))) = 'AFTER' THEN 'A' ELSE 'B' END,
            CASE WHEN UPPER(RTRIM(ISNULL(c.CessTaxPos,    ''))) = 'AFTER' THEN 'A' ELSE 'B' END,
            -- SubCost / DepCode come from the PR line (PO_PRL) join, inserted as-is.
            -- Previously wrapped in NULLIF(), which wrote NULL whenever the PR line
            -- carried 0 / '' — that is why these columns never showed a value.
            c.SubCostCode,
            NULLIF(c.DepCode, ''),          -- varchar(3): '' is not a meaningful dept code
            c.LandingCost,                  -- PO_ORDL.LANDCOST — UI's Landing Cost (line net amount)
            -- FRate: the line's foreign-currency rate. No foreign-currency rate is
            -- captured per line today, so it mirrors the line's own Rate.
            c.Rate,
            c.GrossVal                      -- FValue mirrors the value stored in ORDVAL
        FROM LineCalcFinal c;

        -- Guard: every line in #Lines must have produced an insert row.
        -- A mismatch means the PO_PRL join found no match (divcode/prdate mismatch).
        DECLARE @LinesInserted INT = @@ROWCOUNT;
        DECLARE @LinesExpected INT = (SELECT COUNT(*) FROM #Lines);
        IF @LinesInserted <> @LinesExpected
            RAISERROR('PO line save incomplete: %d of %d PR lines were matched in PO_PRL. Refresh the PR picker and retry.', 16, 1, @LinesInserted, @LinesExpected);

        -- ── 9b. Back-fill PO_ORDH GST totals from the inserted per-line amounts ──
        -- Position-flag-adjusted cgstamt/sgstamt/igstamt are now in PO_ORDL.
        -- Sum them here and update PO_ORDH so CGSTAMT/SGSTAMT/IGSTAMT are correct.
        SELECT
            @CgstAmt = SUM(cgstamt),
            @SgstAmt = SUM(sgstamt),
            @IgstAmt = SUM(igstamt)
        FROM dbo.PO_ORDL
        WHERE DIVCODE = @DivCode AND PORDNO = @PoNo;

        UPDATE dbo.PO_ORDH
        SET CGSTAMT  = ISNULL(@CgstAmt, 0),
            SGSTAMT  = ISNULL(@SgstAmt, 0),
            IGSTAMT  = ISNULL(@IgstAmt, 0)
        WHERE DIVCODE = @DivCode AND PORDNO = @PoNo;

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

        -- CR-014: Scheduled qty cannot exceed PO line ordered qty (item-specific message).
        DECLARE @OverScheduleError NVARCHAR(500);
        SELECT TOP 1 @OverScheduleError =
            'Scheduled quantity exceeds PO quantity for item ' + RTRIM(l.ItemCode)
        FROM #Lines l
        CROSS APPLY (
            SELECT SUM(s.qty) AS SlotTotal
            FROM OPENJSON(l.SlotsJson) WITH (qty NUMERIC(12,3) '$.qty') s
            WHERE s.qty > 0
        ) st
        WHERE l.SlotsJson IS NOT NULL
          AND st.SlotTotal IS NOT NULL
          AND st.SlotTotal > l.Qty + 0.001;
        IF @OverScheduleError IS NOT NULL
            RAISERROR(@OverScheduleError, 16, 1);

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

        -- CR-016: Duplicate delivery date — same line, same date within this save batch.
        IF EXISTS (
            SELECT 1
            FROM #Lines l
            CROSS APPLY OPENJSON(l.SlotsJson)
            WITH (shDate NVARCHAR(10) '$.shDate', qty NUMERIC(12,3) '$.qty') s
            WHERE l.SlotsJson IS NOT NULL
              AND s.qty > 0
              AND TRY_CAST(s.shDate AS DATE) IS NOT NULL
            GROUP BY l.PORDSNO, TRY_CAST(s.shDate AS DATE)
            HAVING COUNT(*) > 1
        )
            RAISERROR('Duplicate delivery date: the same delivery date cannot appear more than once for an order line.', 16, 1);

        -- OA-03: 400 reject — qty > 0 with no date (reversed from silent-skip per Sasi/CEO 17-Jun-2026)
        IF EXISTS (
            SELECT 1
            FROM #Lines l
            CROSS APPLY OPENJSON(l.SlotsJson)
            WITH (shDate NVARCHAR(10) '$.shDate', qty NUMERIC(12,3) '$.qty') s
            WHERE l.SlotsJson IS NOT NULL
              AND s.qty > 0
              AND (s.shDate IS NULL
                   OR RTRIM(ISNULL(s.shDate, '')) = ''
                   OR TRY_CAST(s.shDate AS DATE) IS NULL)
        )
            RAISERROR('Delivery slot date is required when quantity is specified.', 16, 1);

        INSERT INTO dbo.PO_ORDL_DETL
        (divcode, pordno, porddt, pordsno, pogrp, itemcode, shdate, Quantity)
        SELECT
            @DivCode, @PoNo, @ActualPoDt,
            l.PORDSNO,
            @OrderType,
            l.ItemCode,
            TRY_CAST(s.shDate AS DATE),
            s.qty
        FROM #Lines l
        CROSS APPLY OPENJSON(l.SlotsJson)
        WITH (
            shDate  NVARCHAR(10)  '$.shDate',
            qty     NUMERIC(12,3) '$.qty'
        ) s
        WHERE s.qty > 0
          AND TRY_CAST(s.shDate AS DATE) IS NOT NULL;

        -- ── 11. UPDATE PO_PRL — increment QTYORD, conditionally mark as ordered ──
        -- BR-05B: PRSTATUS='O' and FClosed='Y' set only when fully ordered
        -- (QTYORD + ordered qty >= QTYREQD). Partial orders keep the current
        -- PRSTATUS so the line remains visible in the PR picker with its balance qty.
        UPDATE prl
        SET
            QTYORD   = ISNULL(prl.QTYORD, 0) + l.Qty,
            PRSTATUS = CASE
                           WHEN (ISNULL(prl.QTYORD, 0) + l.Qty) >= ISNULL(prl.QTYREQD, 0)
                           THEN 'O'
                           ELSE prl.PRSTATUS
                       END,
            FClosed  = CASE
                           WHEN (ISNULL(prl.QTYORD, 0) + l.Qty) >= ISNULL(prl.QTYREQD, 0)
                           THEN 'Y'
                           ELSE prl.FClosed
                       END
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
-- ksp_PO_DateWise_Report
-- Returns PO lines for the Date-Wise PDF report (JAT database).
-- Groups by PO date in the application layer (QuestPDF document).
-- Column names verified against the live schema (2026-07-03) — several
-- earlier aliases (TAX_AMT, ADVPER, ADVAMT, PAYMODE, DELINST, SPINST,
-- CARNAME) did not exist and would have failed to compile.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DateWise_Report
    @Divcode  VARCHAR(2),
    @FromDate DATETIME,
    @ToDate   DATETIME
AS
-- 07-Jul VB6-parity pass (task/abinandan/POList-DateWise-ItemWise-VB6-Parity):
-- BalanceAmount reverted to VB6's line-level conditional formula; PAYMENT reverted to
-- VB6's 2-way case; DeliveryInstructions reverted to DEL_INS2 only; CANFLG exclusion and
-- LEFT JOINs on FA_SLMAS/PO_CAR reverted to VB6's INNER JOINs (row-set parity, user-approved
-- deviation from the prior session's "defensive" version); ORDER BY reverted to PORDDT only.
-- GST/CarrierName/PrNo fixes from 06-Jul are genuine data-correctness fixes and are KEPT.
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.PORDDT                                           AS PoDate,
            RTRIM(ISNULL(h.PORDNO, ''))                       AS PoNo,
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            RTRIM(ISNULL(dep.DEPNAME, ''))                    AS DepName,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            -- 11-Jul true-source parity (Reports_Vb6\new\PO-Datewise.rpt +
            -- "Script for po reports.txt"): the report's "Order Value" column binds to
            -- {ORDVAL} = the HEADER order value (PO_ORDH.ORDVAL), shown once per PO; the
            -- "Item Value" column binds to {poitemvalue} = line ORDVAL (= LineValue above).
            ISNULL(h.ORDVAL, 0)                               AS HeaderOrderValue,
            -- 06-Jul: GST = cgstamt+sgstamt+igstamt summed — TAXAMT is under-populated
            -- on live JAT (216/662 nonzero for 2026 vs 622/662 for the components);
            -- same real-data finding as the Supplier-Wise reconciliation.
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            RTRIM(ISNULL(h.POGRP, ''))                        AS OrderType,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            -- Legacy balamt: no advance -> the LINE value; with an advance -> the HEADER value
            -- less the advance (the two branches deliberately read different tables).
            CASE
                WHEN ISNULL(h.ADV_AMT, 0) = 0 THEN l.ORDVAL
                ELSE (h.ORDVAL - h.ADV_AMT)
            END                                                AS BalanceAmount,
            CASE
                WHEN RTRIM(ISNULL(h.PAYMENT, '')) = 'D' THEN 'Direct'
                ELSE 'Bank'
            END                                                AS PaymentMode,
            0                                                   AS DelDays,
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            RTRIM(ISNULL(h.CARCODE, ''))                      AS CarrierCode,
            -- 06-Jul: CARNAME comes from the PO_CAR master — CARCODE was being echoed
            -- back as the name, so the print showed codes ("AAZ") instead of names.
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            -- PR No is the purchase-requisition number the PO LINE was raised from.
            -- It lives on the line table (PO_ORDL.PRNO), NOT the header — a single PO can
            -- pull lines from several PRs, so this must come from l.*, not h.*. (Previously
            -- this was mistakenly aliased from h.PORDNO, which just echoed the PO number.)
            -- TRY_CONVERT keeps the SP safe whether PRNO is stored numeric or varchar; a
            -- 0/NULL PRNO (direct PO, not raised from a PR) renders as blank.
            CASE
                WHEN ISNULL(TRY_CONVERT(BIGINT, l.PRNO), 0) = 0 THEN ''
                ELSE CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, l.PRNO))
            END                                                AS PrNo,
            RTRIM(ISNULL(h.DEL_INS2, ''))                     AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.Duedate                                          AS DueDate,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName
        FROM dbo.PO_ORDH h
        INNER JOIN dbo.PO_ORDL l
            ON  h.DIVCODE = l.DIVCODE
            AND h.PORDNO  = l.PORDNO
            AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
            AND h.POGRP   = l.POGRP
        INNER JOIN dbo.FA_SLMAS sl
            ON  RTRIM(sl.SLCODE) = RTRIM(h.SLCODE)
        INNER JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        LEFT  JOIN dbo.IN_DEP dep
            ON  l.DepCode = dep.DEPCODE
            AND h.DIVCODE = dep.DIVCODE
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
        ORDER BY h.PORDDT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PO_ItemWise_Report
-- Returns PO lines for the Item-Wise PDF report (JAT database).
-- Groups by item in the application layer (QuestPDF document).
-- @FItem/@TItem = 'A' means "all items" (matches the repository's
-- fetchAll convention); otherwise an alphabetical item-code range.
-- Column names mirror the confirmed-correct live schema used by
-- ksp_PO_DateWise_Report (TAXAMT, ADV_PER, ADV_AMT, PAYMENT, CARCODE,
-- DEL_INS1/DEL_INS2, SPL_INS) — the previous version of this SP was an
-- unimplemented placeholder (SELECT TOP 0 ... WHERE 1=0).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_ItemWise_Report
    @Divcode  VARCHAR(2),
    @FromDate VARCHAR(10),
    @ToDate   VARCHAR(10),
    @FItem    VARCHAR(20) = 'A',
    @TItem    VARCHAR(20) = 'A',
    -- VB6's @Opt confirm-status filter, restored: 'A'=all, 'Y'=confirmed, 'N'=not confirmed
    -- (PO_ORDH.CONFLG domain confirmed via ksp_PO_SetFinalApproval.sql / ksp_PO_GetApprovalStatus.sql).
    @Opt      VARCHAR(15) = 'A'
AS
-- 07-Jul VB6-parity pass (task/abinandan/POList-DateWise-ItemWise-VB6-Parity):
-- BalanceAmount reverted to VB6's line-level conditional formula; PAYMENT reverted to
-- VB6's 2-way case; DeliveryInstructions reverted to DEL_INS2 only; CANFLG exclusion and
-- LEFT JOINs on FA_SLMAS/PO_CAR reverted to VB6's INNER JOINs (row-set parity, user-approved
-- deviation from the prior session's "defensive" version); ORDER BY reverted to PORDDT only;
-- @Opt confirm-status filter restored (was dropped when this SP was rewritten from its
-- SELECT TOP 0 stub); PrNo added (confirmed real vs VB6). GST/CarrierName fixes from 06-Jul
-- are genuine data-correctness fixes and are KEPT.
-- 11-Jul true-source parity, per Reports_Vb6\new\ (PO-Itemwise.rpt bindings + the legacy SP in
-- "Script for po reports.txt"). The .rpt binds "Order Value"={ORDVAL} and "Item Value"=
-- {poitemvalue}; the legacy SP selects `PO_ORDh."ordval" as ORDVAL` + `isnull(po_ordl.ordval,0)
-- as poitemvalue` => Order Value = HEADER PO_ORDH.ORDVAL (once per PO), Item Value = LINE
-- PO_ORDL.ORDVAL (summed per line). NOTE: an earlier revision of that script aliased ORDVAL from
-- PO_ORDL.LANDCOST; the 11-Jul 12:31 update replaced it with the header value, so LANDCOST is NOT
-- used by this report. Same rule now holds across all three PO List reports.
-- balamt: ADV_AMT=0 -> line ORDVAL, else HEADER ORDVAL - ADV_AMT (matches the legacy CASE).
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            RTRIM(ISNULL(h.PORDNO, ''))                       AS PoNo,
            h.PORDDT                                           AS PoDate,
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            RTRIM(ISNULL(dep.DEPNAME, ''))                    AS DepName,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            -- 11-Jul true-source parity (Reports_Vb6\new\PO-Itemwise.rpt +
            -- "Script for po reports.txt"): the report's "Order Value" column binds to
            -- {ORDVAL}, which the legacy SP now aliases from the HEADER order value
            -- (`PO_ORDh."ordval" as ORDVAL`) — shown once per PO. The "Item Value" column
            -- binds to {poitemvalue} = line ORDVAL (= LineValue above), summed per line.
            ISNULL(h.ORDVAL, 0)                               AS HeaderOrderValue,
            -- 06-Jul: GST = cgstamt+sgstamt+igstamt summed — TAXAMT is under-populated
            -- on live JAT; same real-data finding as the Supplier-Wise reconciliation.
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            RTRIM(ISNULL(h.POGRP, ''))                        AS OrderType,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            -- Legacy balamt: no advance -> the LINE value; with an advance -> the HEADER value
            -- less the advance (the two branches deliberately read different tables).
            CASE
                WHEN ISNULL(h.ADV_AMT, 0) = 0 THEN l.ORDVAL
                ELSE (h.ORDVAL - h.ADV_AMT)
            END                                                AS BalanceAmount,
            CASE
                WHEN RTRIM(ISNULL(h.PAYMENT, '')) = 'D' THEN 'Direct'
                ELSE 'Bank'
            END                                                AS PaymentMode,
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            -- 06-Jul: CARNAME from the PO_CAR master — CARCODE was echoed as the name.
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            RTRIM(ISNULL(h.DEL_INS2, ''))                     AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.Duedate                                          AS DueDate,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName,
            -- PR No — same source/logic as ksp_PO_DateWise_Report (l.PRNO, not header).
            CASE
                WHEN ISNULL(TRY_CONVERT(BIGINT, l.PRNO), 0) = 0 THEN ''
                ELSE CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, l.PRNO))
            END                                                AS PrNo
        FROM dbo.PO_ORDH h
        INNER JOIN dbo.PO_ORDL l
            ON  h.DIVCODE = l.DIVCODE
            AND h.PORDNO  = l.PORDNO
            AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
            AND h.POGRP   = l.POGRP
        INNER JOIN dbo.FA_SLMAS sl
            ON  RTRIM(sl.SLCODE) = RTRIM(h.SLCODE)
        INNER JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        LEFT  JOIN dbo.IN_DEP dep
            ON  l.DepCode = dep.DEPCODE
            AND h.DIVCODE = dep.DIVCODE
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
          AND (@FItem = 'A' OR l.ITEMCODE BETWEEN @FItem AND @TItem)
          AND (@Opt = 'A' OR (@Opt <> 'A' AND ISNULL(h.CONFLG, 'N') = @Opt))
        ORDER BY h.PORDDT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PO_DeptWise_Report
-- Returns PO lines for the Department-Wise PDF report (JAT).
-- Groups by department in the application layer (QuestPDF document).
-- @DepCode = NULL returns all departments.
-- 06-Jul: implemented against LIVE JAT schema (the earlier draft used
-- columns that do not exist there — verified via sys.columns):
--   - Department lives on the LINE (PO_ORDL.DepCode), NOT PO_ORDH —
--     PO_ORDH has no DEPCODE column at all.
--   - Received qty column is PO_ORDL.RCVDQTY (not RECQTY).
--   - GST Amount is cgstamt+sgstamt+igstamt summed — PO_ORDL.TAXAMT is
--     under-populated on live data (216/662 nonzero for 2026 vs 622/662
--     for the components), same finding as the Supplier-Wise reconciliation.
--   - PO_ORDH/PO_ORDL join includes POGRP as a 4th key (PORDNO repeats
--     across POGRP series) and PoNo carries the POGRP prefix, matching
--     the Supplier-Wise reconciled SP.
--   - Header fields (Quotation, Carrier, Advance, Payment, Delivery/
--     Special instructions, Due date, Crd-Days) supplied because the
--     PoDeptwiseDocument row layout renders them.
--   - NOTE (data reality, not a defect): PO_ORDL.DepCode is NULL on most
--     recent JAT lines — those rows group under a blank department.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DeptWise_Report
    @Divcode  VARCHAR(2),
    @FromDate DATETIME,
    @ToDate   DATETIME,
    @DepCode  VARCHAR(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.DIVCODE                                          AS DivCode,
            RTRIM(ISNULL(l.DepCode, ''))                      AS DepCode,
            RTRIM(ISNULL(dep.DEPNAME, ''))                    AS DepName,
            CASE
                WHEN RTRIM(ISNULL(h.POGRP, '')) = '' THEN RTRIM(ISNULL(h.PORDNO, ''))
                ELSE RTRIM(h.POGRP) + '/' + RTRIM(ISNULL(h.PORDNO, ''))
            END                                                AS PoNo,
            h.PORDDT                                           AS PoDate,
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.RCVDQTY, 0)                              AS QtyReceived,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            RTRIM(ISNULL(h.POGRP, ''))                        AS OrderType,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            CASE
                WHEN RTRIM(ISNULL(h.PAYMENT, '')) = 'D' THEN 'Direct'
                ELSE 'Bank'
            END                                                AS PaymentMode,
            RTRIM(ISNULL(h.DEL_INS1, '')) + ' ' + RTRIM(ISNULL(h.DEL_INS2, '')) AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.Duedate                                          AS DueDate,
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            CASE
                WHEN ISNULL(h.Conflg, 'N') = 'Y'
                  THEN 'CONFIRMED'
                WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y'
                  THEN 'First Level Approved'
                ELSE 'PENDING'
            END                                                AS ApprovalStatus,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName
        FROM dbo.PO_ORDH h
        INNER JOIN dbo.PO_ORDL l
            ON  h.DIVCODE = l.DIVCODE
            AND h.PORDNO  = l.PORDNO
            AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
            AND h.POGRP   = l.POGRP
        LEFT  JOIN dbo.FA_SLMAS sl
            ON  RTRIM(sl.SLCODE) = RTRIM(h.SLCODE)
        LEFT  JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        LEFT  JOIN dbo.IN_DEP dep
            ON  l.DepCode  = dep.DEPCODE
            AND h.DIVCODE  = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
          AND ISNULL(h.CANFLG, '') = ''
          AND (@DepCode IS NULL OR RTRIM(l.DepCode) = RTRIM(@DepCode))
        ORDER BY RTRIM(ISNULL(dep.DEPNAME, '')), h.PORDDT DESC, h.PORDNO, l.ITEMCODE;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- ksp_PO_SupplierWise_Report
-- Returns PO lines for the Supplier-Wise PDF report (JAT).
-- Groups by supplier in the application layer (QuestPDF document).
-- @SupplierCode = NULL returns all suppliers.
-- 06-Jul: reconciled against the legacy Crystal Report source SP
-- (KSP_POLIST_SUPPLIERWISE, supplied by user) after real-data findings
-- showed Carrier Name blank and GST Amount always 0.00. Changes made to
-- match the legacy SP exactly:
--   - Carrier Name now comes from a PO_CAR master join on CARCODE (legacy
--     selects PO_CAR.CARNAME, not a PO_ORDH column - CARNAME doesn't
--     exist on PO_ORDH, confirmed by the earlier SSMS "Invalid column
--     name" error; the previous fix's fallback to CARCODE was still wrong).
--   - GST Amount is cgstamt+sgstamt+igstamt (three tax components summed),
--     not the single TAXAMT column.
--   - PO_ORDH/PO_ORDL join now includes POGRP as a 4th key (matches legacy) -
--     PORDNO repeats across POGRP series (AD/1254 vs CR/1254), so omitting
--     it risked matching the wrong PO_ORDL rows on a shared PORDNO+PORDDT.
--   - CANFLG filter removed - legacy has no cancelled-PO exclusion.
--   - Payment mode is now a strict 2-way map (PAYMENT='D' -> Direct, else
--     -> Bank), matching legacy exactly instead of a 3-way map with a
--     raw-value passthrough branch legacy doesn't have.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SupplierWise_Report
    @Divcode      VARCHAR(2),
    @FromDate     DATETIME,
    @ToDate       DATETIME,
    @SupplierCode VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            -- Matches the legacy Crystal formula exactly: POGRP + "/" + PORDNO when POGRP is set,
            -- else just PORDNO (06-Jul single-supplier finding - prefix was missing entirely).
            CASE
                WHEN RTRIM(ISNULL(h.POGRP, '')) = '' THEN RTRIM(ISNULL(h.PORDNO, ''))
                ELSE RTRIM(h.POGRP) + '/' + RTRIM(ISNULL(h.PORDNO, ''))
            END                                                AS PoNo,
            h.PORDDT                                           AS PoDate,
            CASE
                WHEN ISNULL(TRY_CONVERT(BIGINT, l.PRNO), 0) = 0 THEN ''
                ELSE CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, l.PRNO))
            END                                                AS PrNo,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            RTRIM(ISNULL(h.CARCODE, ''))                      AS CarrierCode,
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            -- Legacy selects DEL_INS2 only (the DEL_INS1 + ' ' + DEL_INS2 concatenation was a
            -- divergence — DateWise/ItemWise were already reverted to DEL_INS2 on 07-Jul).
            RTRIM(ISNULL(h.DEL_INS2, ''))                     AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.DUEDATE                                          AS DueDate,
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            ISNULL(h.ORDVAL, 0)                               AS OrderValue,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            -- Legacy balamt: no advance -> the LINE value; with an advance -> the HEADER value
            -- less the advance. Was an unconditional (h.ORDVAL - h.ADV_AMT), which diverged
            -- whenever ADV_AMT = 0.
            CASE
                WHEN ISNULL(h.ADV_AMT, 0) = 0 THEN l.ORDVAL
                ELSE (h.ORDVAL - h.ADV_AMT)
            END                                                AS BalanceAmount,
            CASE
                WHEN RTRIM(ISNULL(h.PAYMENT, '')) = 'D' THEN 'Direct'
                ELSE 'Bank'
            END                                                AS PaymentMode,
            0                                                   AS DelDays,
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName
        FROM dbo.PO_ORDH h
        INNER JOIN dbo.PO_ORDL l
            ON  h.DIVCODE = l.DIVCODE
            AND h.PORDNO  = l.PORDNO
            AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
            AND h.POGRP   = l.POGRP
        LEFT  JOIN dbo.FA_SLMAS sl
            ON  RTRIM(sl.SLCODE) = RTRIM(h.SLCODE)
        INNER JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
          AND (@SupplierCode IS NULL OR RTRIM(h.SLCODE) = RTRIM(@SupplierCode))
        ORDER BY RTRIM(ISNULL(sl.SLNAME, '')), h.PORDDT DESC, h.PORDNO, l.ITEMCODE;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


-- ============================================================
-- PO Cancellation & Foreclosure (Sprint 2B) — FN v1.4
-- Added 11-Jul-2026 (task/abinandan/po-cancel-foreclose-sp).
-- 6 NEW SPs. ⚠️ Deploy gated on LT-01 (G2): PO_ORDL cancel/foreclose columns
-- (LCANFLG/LCANDT/LCANCELCODE/CANQTY/FCLOSED/FCLOSEDDT) + PO_CANCELREASON table
-- unverified from repo — confirm on live JAT/SCMTS DDL before executing.
-- ============================================================

-- ============================================================
-- ksp_PO_GetCancelReasons
-- Reason dropdown for the PO Cancellation screen (FN-PO-Cancellation v1.4 §2 col 14-15).
-- Returns the Cancel Reason setup rows aliased to the FE wire contract
-- (CancellationReason { code, name }).
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): PO_CANCELREASON table + Code/Reason column
--    names are presumed legacy but unverified from the repo. Confirm on live
--    JAT/SCMTS DDL before running against production.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetCancelReasons
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(Code)   AS Code,
            RTRIM(Reason)  AS Name
    FROM    PO_CANCELREASON
    ORDER BY Reason;
END;
GO

-- ============================================================
-- ksp_PO_GetOpenPOList
-- Open-PO lookup for the PO Cancellation picker (FN-PO-Cancellation v1.4 §1).
-- Lists distinct POs that still have at least one open line:
--   ISNULL(RCVDQTY,0) + ISNULL(CANQTY,0) < ISNULL(ORDQTY,0)
--   AND LCANFLG <> 'C' AND ISNULL(FCLOSED,'N') <> 'Y'
-- Scoped to the caller's division. Optional FY-bound filter on PORDDT.
--
-- NOTE (11-Jul-2026): the shipped Cancellation picker (PoListModal.tsx) currently
-- reuses the generic ksp_PO_GetPOList endpoint, so this SP is not yet wired to a
-- C# endpoint — it is delivered per FN §5 as the correct open-only lookup source
-- for when the picker is retargeted. No frontend/controller change is made here
-- (frozen contract).
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): CANQTY / LCANFLG / FCLOSED on PO_ORDL presumed
--    legacy but unverified from the repo.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetOpenPOList
(
    @DivCode VARCHAR(2),
    @YFDate  DATE = NULL,
    @YLDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
            h.PORDNO                       AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120) AS PoDate,
            RTRIM(ISNULL(h.SLCODE, ''))    AS SlCode,
            RTRIM(ISNULL(s.SLNAME, ''))    AS SupplierName,
            RTRIM(ISNULL(h.POGRP, ''))     AS PoGrp
    FROM    PO_ORDH h
    INNER JOIN PO_ORDL l
            ON  l.DIVCODE = h.DIVCODE
            AND ISNULL(l.POGRP, '') = ISNULL(h.POGRP, '')
            AND l.PORDNO  = h.PORDNO
            AND l.PORDDT  = h.PORDDT
    LEFT JOIN FA_SLMAS s
            ON  s.SLCODE = h.SLCODE
    WHERE   h.DIVCODE = @DivCode
      AND   ISNULL(l.RCVDQTY, 0) + ISNULL(l.CANQTY, 0) < ISNULL(l.ORDQTY, 0)
      AND   ISNULL(l.LCANFLG, '') <> 'C'
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
      AND   (@YFDate IS NULL OR CAST(h.PORDDT AS DATE) >= @YFDate)
      AND   (@YLDate IS NULL OR CAST(h.PORDDT AS DATE) <= @YLDate)
    -- SELECT DISTINCT permits only select-list items in ORDER BY.
    -- PoDate is YYYY-MM-DD, so the string sort is chronological.
    ORDER BY PoDate DESC, PoNo DESC;
END;
GO

-- ============================================================
-- ksp_PO_GetPOLinesForCancel
-- Grid load for a selected PO on the Cancellation screen
-- (FN-PO-Cancellation v1.4 §2 / §3.3). Returns the open lines of one PO
-- mapped to POCancellationLineDto { slCode, itemCode, sNo, itemName, uom,
-- orderQty, receivedQty, rate, value }.
-- Open-line predicate identical to the picker:
--   ISNULL(RCVDQTY,0)+ISNULL(CANQTY,0) < ISNULL(ORDQTY,0)
--   AND LCANFLG <> 'C' AND ISNULL(FCLOSED,'N') <> 'Y'.
-- Balance is computed client- and server-side as ORDQTY-RCVDQTY-CANQTY;
-- receivedQty here is the raw RCVDQTY per the FN column map.
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): CANQTY / LCANFLG / FCLOSED on PO_ORDL unverified.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOLinesForCancel
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(ISNULL(h.SLCODE, ''))  AS SlCode,
            RTRIM(l.ITEMCODE)            AS ItemCode,
            CAST(l.PORDSNO AS INT)       AS SNo,
            RTRIM(ISNULL(i.ITEMNAME, '')) AS ItemName,
            RTRIM(ISNULL(i.UOM, ''))     AS Uom,
            ISNULL(l.ORDQTY, 0)          AS OrderQty,
            ISNULL(l.RCVDQTY, 0)         AS ReceivedQty,
            ISNULL(l.RATE, 0)            AS Rate,
            ISNULL(l.ORDVAL, 0)          AS Value
    FROM    PO_ORDL l
    INNER JOIN PO_ORDH h
            ON  h.DIVCODE = l.DIVCODE
            AND ISNULL(h.POGRP, '') = ISNULL(l.POGRP, '')
            AND h.PORDNO  = l.PORDNO
            AND h.PORDDT  = l.PORDDT
    LEFT JOIN IN_ITEM i
            ON  i.ITEMCODE = l.ITEMCODE
    WHERE   l.DIVCODE = @DivCode
      AND   l.PORDNO  = @PoNo
      AND   CAST(l.PORDDT AS DATE) = @PoDate
      AND   ISNULL(l.RCVDQTY, 0) + ISNULL(l.CANQTY, 0) < ISNULL(l.ORDQTY, 0)
      AND   ISNULL(l.LCANFLG, '') <> 'C'
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
    ORDER BY l.PORDSNO;
END;
GO

-- ============================================================
-- ksp_PO_GetOpenLinesForForeclose
-- Grid load for the PO Foreclosure screen (FN-PO-Foreclosure v1.4 §1/§2).
-- Loads ALL open PO lines across the division in one list (no PO picker),
-- ordered PORDDT, PORDNO, PORDSNO. Optional PO No. prefix filter.
-- Corrected load predicate (see FN §6 deviations):
--   Balance = ISNULL(ORDQTY,0)-ISNULL(RCVDQTY,0)-ISNULL(CANQTY,0) > 0
--   AND ISNULL(FCLOSED,'N') <> 'Y' AND ISNULL(LCANFLG,'') <> 'C'.
-- Returns POForeclosureLineDto { group, poNo, poDate, slCode, supplierName,
-- sNo, itemCode, itemName, balanceQty, prNo, prDate }.
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): CANQTY / LCANFLG / FCLOSED on PO_ORDL unverified.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetOpenLinesForForeclose
(
    @DivCode     VARCHAR(2),
    @PoNoPrefix  VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(ISNULL(h.POGRP, ''))    AS [Group],
            h.PORDNO                       AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120) AS PoDate,
            RTRIM(ISNULL(h.SLCODE, ''))    AS SlCode,
            RTRIM(ISNULL(s.SLNAME, ''))    AS SupplierName,
            CAST(l.PORDSNO AS INT)         AS SNo,
            RTRIM(l.ITEMCODE)              AS ItemCode,
            RTRIM(ISNULL(i.ITEMNAME, ''))  AS ItemName,
            ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0) - ISNULL(l.CANQTY, 0) AS BalanceQty,
            RTRIM(ISNULL(CONVERT(VARCHAR(20), l.PRNO), '')) AS PrNo,
            CONVERT(VARCHAR(10), l.PRDATE, 120)             AS PrDate
    FROM    PO_ORDL l
    INNER JOIN PO_ORDH h
            ON  h.DIVCODE = l.DIVCODE
            AND ISNULL(h.POGRP, '') = ISNULL(l.POGRP, '')
            AND h.PORDNO  = l.PORDNO
            AND h.PORDDT  = l.PORDDT
    LEFT JOIN FA_SLMAS s
            ON  s.SLCODE = h.SLCODE
    LEFT JOIN IN_ITEM i
            ON  i.ITEMCODE = l.ITEMCODE
    WHERE   l.DIVCODE = @DivCode
      AND   ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0) - ISNULL(l.CANQTY, 0) > 0
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
      AND   ISNULL(l.LCANFLG, '') <> 'C'
      AND   (@PoNoPrefix IS NULL
             OR CONVERT(VARCHAR(20), h.PORDNO) LIKE @PoNoPrefix + '%')
    ORDER BY h.PORDDT, h.PORDNO, l.PORDSNO;
END;
GO

-- ============================================================
-- ksp_PO_CancelLines
-- Save for the PO Cancellation screen (FN-PO-Cancellation v1.4 §4 A-G + E2).
-- Single transaction over a JSON array of ticked lines. Per line:
--   * resolve the full line key (POGRP resolved once from PO_ORDH);
--   * re-read Balance = ORDQTY-RCVDQTY-CANQTY server-side (never trust client);
--   * guard RCVDQTY+CANQTY+@CanQty <= ORDQTY, CanQty>0, Reason required;
--   * LCANFLG = 'C' when @CanQty = Balance else 'P';
--   * UPDATE PO_ORDL (LCANFLG/LCANDT/LCANCELCODE, CANQTY += @CanQty);
--   * @@ROWCOUNT=0 -> RAISERROR -> CATCH rollback (no silent success, §4C);
--   * LogDet_PO ADD row (Trans_date = GETUTCDATE(), Quantity = @CanQty);
--   * PR backflush with mandatory floor guard + PRSNO filter (CD-NEW-01, §4E);
--   * conditional LogDet_PO WARN row when the floor fires (§4E2).
-- @TransDate (LCANDT) = posting date from the API (X-Processing-Date header);
-- LogDet_PO.Trans_date stays GETUTCDATE() per CEO.
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): LCANFLG/LCANDT/LCANCELCODE/CANQTY/FCLOSED on
--    PO_ORDL and the PO_CANCELREASON table are presumed legacy but unverified
--    from the repo. Run the LT-01 verification script on live JAT/SCMTS first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_CancelLines
(
    @DivCode   VARCHAR(2),
    @PoNo      NUMERIC(10,0),
    @PoDate    DATE,
    @TransDate DATE,
    @UserId    VARCHAR(25),
    @HostName  VARCHAR(100)  = NULL,
    @IpAddress VARCHAR(50)   = NULL,
    @LinesJson NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Resolve POGRP once for the whole PO (§4G full key).
        DECLARE @PoGrp VARCHAR(20);
        IF NOT EXISTS (
            SELECT 1 FROM PO_ORDH
            WHERE DIVCODE = @DivCode AND PORDNO = @PoNo AND CAST(PORDDT AS DATE) = @PoDate
        )
            RAISERROR('Purchase Order not found for the given number and date.', 16, 1);

        SELECT TOP 1 @PoGrp = RTRIM(ISNULL(POGRP, ''))
        FROM   PO_ORDH
        WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo AND CAST(PORDDT AS DATE) = @PoDate;

        -- Parse ticked lines.
        DECLARE @Lines TABLE (
            RowId      INT IDENTITY(1,1) PRIMARY KEY,
            SNo        NUMERIC(5,0),
            ItemCode   VARCHAR(10),
            ReasonCode VARCHAR(20),
            CanQty     NUMERIC(18,3)
        );

        INSERT INTO @Lines (SNo, ItemCode, ReasonCode, CanQty)
        SELECT j.sNo, j.itemCode, j.reasonCode, j.cancelQty
        FROM OPENJSON(@LinesJson)
        WITH (
            sNo        NUMERIC(5,0)  '$.sNo',
            itemCode   VARCHAR(10)   '$.itemCode',
            reasonCode VARCHAR(20)   '$.reasonCode',
            cancelQty  NUMERIC(18,3) '$.cancelQty'
        ) j
        WHERE RTRIM(ISNULL(j.itemCode, '')) <> '';

        IF NOT EXISTS (SELECT 1 FROM @Lines)
            RAISERROR('Select at least one item to complete the transaction.', 16, 1);

        DECLARE @RowId INT = (SELECT MIN(RowId) FROM @Lines);
        DECLARE @SNo NUMERIC(5,0), @ItemCode VARCHAR(10), @ReasonCode VARCHAR(20), @CanQty NUMERIC(18,3);
        DECLARE @OrdQty NUMERIC(18,3), @RcvdQty NUMERIC(18,3), @ExistCanQty NUMERIC(18,3), @Balance NUMERIC(18,3);
        DECLARE @Flag CHAR(1), @Shortfall NUMERIC(18,3);
        DECLARE @PrNo NUMERIC(6,0), @PrDate DATE, @PrSno NUMERIC(5,0);
        DECLARE @BalanceError NVARCHAR(200);

        WHILE @RowId IS NOT NULL
        BEGIN
            SELECT @SNo = SNo, @ItemCode = ItemCode, @ReasonCode = RTRIM(ISNULL(ReasonCode, '')), @CanQty = CanQty
            FROM   @Lines WHERE RowId = @RowId;

            -- Per-line server-side validation (defence-in-depth, §3).
            IF @CanQty IS NULL OR @CanQty <= 0
                RAISERROR('Cancel quantity must be greater than zero.', 16, 1);
            IF @ReasonCode = ''
                RAISERROR('Cancellation reason is required.', 16, 1);

            -- Read the target line on the full key; recompute Balance server-side.
            SET @OrdQty = NULL; SET @RcvdQty = NULL; SET @ExistCanQty = NULL;
            SET @PrNo = NULL;   SET @PrDate = NULL;  SET @PrSno = NULL;

            SELECT @OrdQty      = ISNULL(ORDQTY, 0),
                   @RcvdQty     = ISNULL(RCVDQTY, 0),
                   @ExistCanQty = ISNULL(CANQTY, 0),
                   @PrNo        = PRNO,
                   @PrDate      = PRDATE,
                   @PrSno       = PRSNO
            FROM   PO_ORDL
            WHERE  DIVCODE = @DivCode
              AND  ISNULL(POGRP, '') = @PoGrp
              AND  PORDNO  = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo
              AND  ITEMCODE = @ItemCode;

            IF @@ROWCOUNT = 0
                RAISERROR('A selected cancellation line no longer exists. Reload the PO and retry.', 16, 1);

            SET @Balance = @OrdQty - @RcvdQty - @ExistCanQty;

            IF (@RcvdQty + @ExistCanQty + @CanQty) > @OrdQty
            BEGIN
                SET @BalanceError =
                    'Cancel quantity exceeds the available balance for a selected line. Available balance: ' +
                    LTRIM(STR(@Balance, 12, 3));
                RAISERROR(@BalanceError, 16, 1);
            END

            SET @Flag = CASE WHEN @CanQty = @Balance THEN 'C' ELSE 'P' END;

            -- A/B: apply cancellation on the full key.
            UPDATE PO_ORDL
            SET    LCANFLG     = @Flag,
                   LCANDT      = @TransDate,
                   LCANCELCODE = @ReasonCode,
                   CANQTY      = ISNULL(CANQTY, 0) + @CanQty
            WHERE  DIVCODE = @DivCode
              AND  ISNULL(POGRP, '') = @PoGrp
              AND  PORDNO  = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo
              AND  ITEMCODE = @ItemCode;

            IF @@ROWCOUNT = 0
                RAISERROR('Cancellation update matched no row — a selected line was changed by another user.', 16, 1);

            -- D: audit ADD row.
            INSERT INTO LogDet_PO
                (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                 Quantity, username, Trans_UserId, Trans_date,
                 Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo, Reason)
            VALUES
                (@DivCode, @PoNo, @PoDate, @PrNo, @PrDate, @PrSno, @ItemCode,
                 @CanQty, @UserId, @UserId, GETUTCDATE(),
                 'Purchase Order Cancellation', 'ADD',
                 ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1, @ReasonCode);

            -- E: PR backflush with mandatory floor guard + PRSNO filter (CD-NEW-01).
            -- Skip cleanly when the PO line has no PR link.
            IF @PrNo IS NOT NULL AND @PrNo > 0
            BEGIN
                SET @Shortfall = NULL;
                UPDATE PO_PRL
                SET    @Shortfall = ISNULL(QTYORD, 0) - @CanQty,
                       QTYORD     = CASE WHEN ISNULL(QTYORD, 0) - @CanQty < 0
                                         THEN 0
                                         ELSE ISNULL(QTYORD, 0) - @CanQty END
                WHERE  PRNO = @PrNo
                  AND  PRDATE = @PrDate
                  AND  DIVCODE = @DivCode
                  AND  ITEMCODE = @ItemCode
                  AND  PRSNO = @PrSno;

                -- E2: clamp logging — one WARN row only when the floor actually fired.
                IF @Shortfall < 0
                    INSERT INTO LogDet_PO
                        (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                         Quantity, username, Trans_UserId, Trans_date,
                         Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo, Reason)
                    VALUES
                        (@DivCode, @PoNo, @PoDate, @PrNo, @PrDate, @PrSno, @ItemCode,
                         @Shortfall, @UserId, @UserId, GETUTCDATE(),
                         'Purchase Order Cancellation', 'WARN',
                         ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1, @ReasonCode);
            END

            SET @RowId = (SELECT MIN(RowId) FROM @Lines WHERE RowId > @RowId);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================
-- ksp_PO_ForeCloseLines
-- Save for the PO Foreclosure screen (FN-PO-Foreclosure v1.4 §4 A-E + C2).
-- Single transaction over a JSON array of ticked lines spanning many POs.
-- Per line (full key incl. per-line POGRP from the payload):
--   * re-read the row and recompute Balance = ORDQTY-RCVDQTY-CANQTY server-side
--     (never trust the client-sent balance, §4A);
--   * UPDATE PO_ORDL SET FCLOSED='Y', FCLOSEDDT=@TransDate, guarded by
--     FCLOSED<>'Y' AND LCANFLG<>'C' AND Balance>0;
--   * @@ROWCOUNT=0 -> RAISERROR -> CATCH rollback (stale line, §4B);
--   * LogDet_PO ADD row (Trans_date = GETUTCDATE(), Quantity = @Balance);
--   * PR backflush with mandatory floor guard + PRSNO filter (CD-NEW-01, §4C),
--     using the PR key read from PO_ORDL (server-authoritative, not client);
--   * conditional LogDet_PO WARN row when the floor fires (§4C2).
-- @TransDate (FCLOSEDDT) = posting date from the API (X-Processing-Date header);
-- LogDet_PO.Trans_date stays GETUTCDATE() per CEO.
--
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): FCLOSED/FCLOSEDDT/LCANFLG/CANQTY on PO_ORDL
--    presumed legacy but unverified from the repo.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_ForeCloseLines
(
    @DivCode   VARCHAR(2),
    @TransDate DATE,
    @UserId    VARCHAR(25),
    @HostName  VARCHAR(100)  = NULL,
    @IpAddress VARCHAR(50)   = NULL,
    @LinesJson NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Lines TABLE (
            RowId    INT IDENTITY(1,1) PRIMARY KEY,
            PoNo     NUMERIC(10,0),
            PoDate   DATE,
            PoGrp    VARCHAR(20),
            SNo      NUMERIC(5,0),
            ItemCode VARCHAR(10)
        );

        INSERT INTO @Lines (PoNo, PoDate, PoGrp, SNo, ItemCode)
        SELECT j.poNo, j.poDate, RTRIM(ISNULL(j.[group], '')), j.sNo, j.itemCode
        FROM OPENJSON(@LinesJson)
        WITH (
            poNo     NUMERIC(10,0) '$.poNo',
            poDate   DATE          '$.poDate',
            [group]  VARCHAR(20)   '$.group',
            sNo      NUMERIC(5,0)  '$.sNo',
            itemCode VARCHAR(10)   '$.itemCode'
        ) j
        WHERE RTRIM(ISNULL(j.itemCode, '')) <> '';

        IF NOT EXISTS (SELECT 1 FROM @Lines)
            RAISERROR('Select at least one item to complete the transaction.', 16, 1);

        DECLARE @RowId INT = (SELECT MIN(RowId) FROM @Lines);
        DECLARE @PoNo NUMERIC(10,0), @PoDate DATE, @PoGrp VARCHAR(20), @SNo NUMERIC(5,0), @ItemCode VARCHAR(10);
        DECLARE @OrdQty NUMERIC(18,3), @RcvdQty NUMERIC(18,3), @ExistCanQty NUMERIC(18,3), @Balance NUMERIC(18,3);
        DECLARE @Shortfall NUMERIC(18,3);
        DECLARE @PrNo NUMERIC(6,0), @PrDate DATE, @PrSno NUMERIC(5,0);

        WHILE @RowId IS NOT NULL
        BEGIN
            SELECT @PoNo = PoNo, @PoDate = PoDate, @PoGrp = RTRIM(ISNULL(PoGrp, '')),
                   @SNo = SNo, @ItemCode = ItemCode
            FROM   @Lines WHERE RowId = @RowId;

            -- Read the target line on the full key; recompute Balance server-side.
            SET @OrdQty = NULL; SET @RcvdQty = NULL; SET @ExistCanQty = NULL;
            SET @PrNo = NULL;   SET @PrDate = NULL;  SET @PrSno = NULL;

            SELECT @OrdQty      = ISNULL(ORDQTY, 0),
                   @RcvdQty     = ISNULL(RCVDQTY, 0),
                   @ExistCanQty = ISNULL(CANQTY, 0),
                   @PrNo        = PRNO,
                   @PrDate      = PRDATE,
                   @PrSno       = PRSNO
            FROM   PO_ORDL
            WHERE  DIVCODE = @DivCode
              AND  ISNULL(POGRP, '') = @PoGrp
              AND  PORDNO  = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo
              AND  ITEMCODE = @ItemCode;

            IF @@ROWCOUNT = 0
                RAISERROR('A selected foreclosure line no longer exists. Reload the list and retry.', 16, 1);

            SET @Balance = @OrdQty - @RcvdQty - @ExistCanQty;

            -- A: close the line, guarded so a since-closed/cancelled/received line
            -- forces a 0-rowcount error rather than a silent no-op.
            UPDATE PO_ORDL
            SET    FCLOSED   = 'Y',
                   FCLOSEDDT = @TransDate
            WHERE  DIVCODE = @DivCode
              AND  ISNULL(POGRP, '') = @PoGrp
              AND  PORDNO  = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo
              AND  ITEMCODE = @ItemCode
              AND  ISNULL(FCLOSED, 'N') <> 'Y'
              AND  ISNULL(LCANFLG, '') <> 'C'
              AND  (ISNULL(ORDQTY, 0) - ISNULL(RCVDQTY, 0) - ISNULL(CANQTY, 0)) > 0;

            IF @@ROWCOUNT = 0
                RAISERROR('A selected line is already closed, cancelled or fully received.', 16, 1);

            -- D: audit ADD row.
            INSERT INTO LogDet_PO
                (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                 Quantity, username, Trans_UserId, Trans_date,
                 Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo, Reason)
            VALUES
                (@DivCode, @PoNo, @PoDate, @PrNo, @PrDate, @PrSno, @ItemCode,
                 @Balance, @UserId, @UserId, GETUTCDATE(),
                 'Purchase Order Foreclosure', 'ADD',
                 ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1, 'Foreclosed');

            -- C: PR backflush with mandatory floor guard + PRSNO filter (CD-NEW-01),
            -- using @Balance (server-recomputed). Skip cleanly when no PR link.
            IF @PrNo IS NOT NULL AND @PrNo > 0
            BEGIN
                SET @Shortfall = NULL;
                UPDATE PO_PRL
                SET    @Shortfall = ISNULL(QTYORD, 0) - @Balance,
                       QTYORD     = CASE WHEN ISNULL(QTYORD, 0) - @Balance < 0
                                         THEN 0
                                         ELSE ISNULL(QTYORD, 0) - @Balance END
                WHERE  PRNO = @PrNo
                  AND  PRDATE = @PrDate
                  AND  DIVCODE = @DivCode
                  AND  ITEMCODE = @ItemCode
                  AND  PRSNO = @PrSno;

                -- C2: clamp logging — one WARN row only when the floor actually fired.
                IF @Shortfall < 0
                    INSERT INTO LogDet_PO
                        (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                         Quantity, username, Trans_UserId, Trans_date,
                         Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo, Reason)
                    VALUES
                        (@DivCode, @PoNo, @PoDate, @PrNo, @PrDate, @PrSno, @ItemCode,
                         @Shortfall, @UserId, @UserId, GETUTCDATE(),
                         'Purchase Order Foreclosure', 'WARN',
                         ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1, 'Foreclosed');
            END

            SET @RowId = (SELECT MIN(RowId) FROM @Lines WHERE RowId > @RowId);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


-- ============================================================
-- PO AMENDMENT (FN-PO-Amendment v1.2) — 6 SPs, added 13-Jul-2026 (T-0166)
-- amdmnt.frm had NO stored procedures: the VB6 form did all of this with
-- inline ADO recordsets + UpdateBatch, no transaction. These are all NEW.
-- ============================================================

-- ============================================================
-- ksp_PO_GetAmendablePOList
-- Amendable-PO lookup for the PO Amendment picker (FN-PO-Amendment v1.2 §1).
--
-- Predicate is AmdAfterGRN-driven (PO_PARA.AmdAfterGRN), resolved INSIDE the SP —
-- the client never sends it:
--   AmdAfterGRN = 'Y'  → line-level: Balance > 0
--                        AND ISNULL(FCLOSED,'N') <> 'Y'
--                        AND ISNULL(LCANFLG,'')  <> 'C'
--                        AND header CANFLG IS NULL AND CANDT IS NULL
--        where Balance = ISNULL(ORDQTY,0) - ISNULL(RCVDQTY,0) - ISNULL(CANQTY,0)
--        (same corrected formula as Foreclosure §1; VB6 omitted the LCANFLG
--         exclusion — FN §6 deviation, deliberately NOT reproduced).
--   else               → only POs with NO receipts at all on any line
--                        (ISNULL(RCVDQTY,0) = 0) AND ISNULL(FCLOSED,'N') <> 'Y'.
--
-- Result maps to AmendablePoSummaryDto { DivCode, PoNo, PoDate, PoGroup,
-- Supplier, SupplierName, OrderValue, TotalLines } — Dapper binds BY NAME, so the
-- aliases below are a contract: do not rename without changing the DTO.
--
-- Date is returned as CONVERT(VARCHAR(10),...,120) and counts as INT — the DTOs
-- expect string/int. (T-0156: a DATE/NUMERIC column against a string/int property
-- fails Dapper materialisation at runtime.)
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm used inline ADO
-- SQL, not a procedure.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT — the read-only SQL login is down. Run
--    PARSEONLY / deploy on JAT before use.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAmendablePOList
(
    @DivCode VARCHAR(2),
    @YFDate  DATE = NULL,
    @YLDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_PARA is division-scoped; default to 'N' (stricter branch) when absent,
    -- so a missing parameter row can never widen the eligible set by accident.
    DECLARE @AmdAfterGRN CHAR(1);
    SELECT TOP 1 @AmdAfterGRN = UPPER(RTRIM(ISNULL(AmdAfterGRN, 'N')))
    FROM   PO_PARA
    WHERE  DIVCODE = @DivCode;
    SET @AmdAfterGRN = ISNULL(@AmdAfterGRN, 'N');

    SELECT  RTRIM(h.DIVCODE)                    AS DivCode,
            h.PORDNO                            AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120) AS PoDate,
            RTRIM(ISNULL(h.POGRP, ''))          AS PoGroup,
            RTRIM(ISNULL(h.SLCODE, ''))         AS Supplier,
            RTRIM(ISNULL(s.SLNAME, ''))         AS SupplierName,
            ISNULL(h.ORDVAL, 0)                 AS OrderValue,
            -- CAST to INT: the DTO property is int. COUNT_BIG/BIGINT here would
            -- fail Dapper materialisation at runtime (the T-0156 failure class).
            CAST(COUNT(l.PORDSNO) AS INT)       AS TotalLines
    FROM    PO_ORDH h
    INNER JOIN PO_ORDL l
            ON  l.DIVCODE = h.DIVCODE
            AND ISNULL(l.POGRP, '') = ISNULL(h.POGRP, '')
            AND l.PORDNO  = h.PORDNO
            AND l.PORDDT  = h.PORDDT
    LEFT JOIN FA_SLMAS s
            ON  s.SLCODE = h.SLCODE
    WHERE   h.DIVCODE = @DivCode
      -- Header-level exclusion: a cancelled PO is never amendable (both branches).
      AND   h.CANFLG IS NULL
      AND   h.CANDT  IS NULL
      AND   ISNULL(l.FCLOSED, 'N') <> 'Y'
      AND   (
              (   @AmdAfterGRN = 'Y'
              AND ISNULL(l.LCANFLG, '') <> 'C'
              AND ISNULL(l.ORDQTY, 0) - ISNULL(l.RCVDQTY, 0) - ISNULL(l.CANQTY, 0) > 0
              )
              OR
              (   @AmdAfterGRN <> 'Y'
              AND ISNULL(l.RCVDQTY, 0) = 0
              )
            )
      AND   (@YFDate IS NULL OR CAST(h.PORDDT AS DATE) >= @YFDate)
      AND   (@YLDate IS NULL OR CAST(h.PORDDT AS DATE) <= @YLDate)
    GROUP BY h.DIVCODE, h.PORDNO, h.PORDDT, h.POGRP, h.SLCODE, s.SLNAME, h.ORDVAL
    ORDER BY h.PORDDT DESC, h.PORDNO DESC;
END;
GO

-- ============================================================
-- ksp_PO_GetPOForAmend
-- Loads ONE Purchase Order for amendment (FN-PO-Amendment v1.2 §1 / §2).
--
-- THREE result sets, consumed by PoAmendmentRepository.GetPOForAmendAsync via
-- QueryMultipleAsync in this exact order:
--   1. header   → PoAmendmentHeaderDto
--   2. lines    → PoAmendmentLineDto        (attached as header.Lines)
--   3. delivery → PoAmendmentDeliverySlotDto(attached as header.Delivery)
--
-- Dapper binds BY NAME. Every alias below is a contract with the DTO — do not
-- rename one without changing the other.
--
-- Type conventions (T-0156 — a DATE/NUMERIC column against a string/int property
-- fails Dapper materialisation at RUNTIME, not compile time):
--   * dates  → CONVERT(VARCHAR(10), col, 120)   (DTO holds string)
--   * SNo    → CAST(... AS INT)                 (DTO holds int)
--   * SlotNo → CAST(... AS INT)
--
-- Line key throughout: DIVCODE + POGRP + PORDNO + PORDDT + PORDSNO + ITEMCODE,
-- matching POGRP as ISNULL(POGRP,'') = ISNULL(@PoGrp,'') per FN §4 (T-0119 item
-- (c) confirmed POGRP is never NULL/blank on live JAT, but the ISNULL match is
-- kept for consistency with the other five PO SPs).
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm used inline ADO.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOForAmend
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE,
    @PoGrp   VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Header ────────────────────────────────────────────────────────────
    SELECT  RTRIM(h.DIVCODE)                            AS DivCode,
            h.PORDNO                                    AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120)         AS PoDate,
            RTRIM(ISNULL(h.POGRP, ''))                  AS PoGroup,
            RTRIM(ISNULL(h.POGRP, ''))                  AS OrderType,
            RTRIM(ISNULL(t.TYPNAME, ''))                AS OrderTypeDesc,
            RTRIM(ISNULL(h.SLCODE, ''))                 AS Supplier,
            RTRIM(ISNULL(s.SLNAME, ''))                 AS SupplierName,
            RTRIM(ISNULL(h.cust_gstinno, ''))           AS Gstin,
            RTRIM(ISNULL(CAST(h.cust_gststcode AS VARCHAR(10)), '')) AS GstState,
            -- Amendment (read-only on the screen)
            h.AMDORDNO                                  AS AmdOrderNo,
            CONVERT(VARCHAR(10), h.AMDORDDT, 120)       AS AmdDate,
            h.REFORDNO                                  AS RefOrderNo,
            CONVERT(VARCHAR(10), h.REFORDDT, 120)       AS RefOrderDate,
            -- Order details
            RTRIM(ISNULL(h.INSPECT, ''))                AS Inspect,
            ISNULL(h.roff, 0)                           AS RoundOff,
            ISNULL(h.ORDVAL, 0)                         AS OrderValue,
            RTRIM(ISNULL(h.Form_type, ''))              AS FormType,
            RTRIM(ISNULL(h.refno, ''))                  AS RefNo,
            CONVERT(VARCHAR(10), h.refDate, 120)        AS RefDate,
            RTRIM(ISNULL(h.CurrCode, ''))               AS Currency,
            ISNULL(h.FCurRate, 0)                       AS CurrRate,
            RTRIM(ISNULL(h.REMARKS, ''))                AS Remarks,
            -- Tax / discount (header)
            0                                           AS CgstPer,   -- header GST % is not stored on PO_ORDH (line-level only)
            0                                           AS SgstPer,
            0                                           AS IgstPer,
            ISNULL(h.htcs_amt, 0)                       AS TcsPer,
            ISNULL(h.DISPER, 0)                         AS DiscPer,
            ISNULL(h.PCKPER, 0)                         AS PackPer,
            ISNULL(h.INSPER, 0)                         AS InsurPer,
            0                                           AS FreightPer, -- PO_ORDH stores the freight AMOUNT, not a %
            ISNULL(h.FREIGHT, 0)                        AS FreightAmt,
            ISNULL(h.Pack_Amt, 0)                       AS PackingAmt,
            ISNULL(h.Ins_Amt, 0)                        AS InsuranceAmt,
            ISNULL(h.ADDTAXPER, 0)                      AS AddTaxPer,
            RTRIM(ISNULL(h.FILENO, ''))                 AS FileNo,
            ISNULL(h.FCACharg, 0)                       AS FcaFob,
            CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
            CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
            CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
            CASE WHEN UPPER(RTRIM(ISNULL(h.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPosition,
            CASE WHEN UPPER(RTRIM(ISNULL(h.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsurancePosition,
            -- Payment
            CASE WHEN RTRIM(ISNULL(h.PAYMENT,'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
            RTRIM(ISNULL(h.DIRECT_INS, ''))             AS DirectInstr,
            RTRIM(ISNULL(h.BANK_CODE, ''))              AS BankCode,
            RTRIM(ISNULL(h.PAYTERMS, ''))               AS PaymentTerms,
            RTRIM(ISNULL(h.paytermcode, ''))            AS PaymentTermCode,
            ISNULL(h.ADV_PER, 0)                        AS AdvPer,
            ISNULL(h.ADV_AMT, 0)                        AS AdvAmt,
            RTRIM(ISNULL(h.advpaymenttype, ''))         AS ModeOfPayment,
            RTRIM(ISNULL(h.CHQNO, ''))                  AS PayRef,     -- same column as ChequeNo; two display labels, one physical value (matches ksp_PO_GetPOHeader)
            CONVERT(VARCHAR(10), h.CHQDT, 120)          AS PayRefDate,
            RTRIM(ISNULL(h.CHQNO, ''))                  AS ChequeNo,
            CONVERT(VARCHAR(10), h.CHQDT, 120)          AS ChequeDate,
            -- Instructions
            RTRIM(ISNULL(h.CARCODE, ''))                AS Carrier,
            CAST(ISNULL(h.CRDDAYS, 0) AS INT)           AS CreditDays,
            CONVERT(VARCHAR(10), h.Duedate, 120)        AS DueDate,
            RTRIM(ISNULL(h.DEL_INS1, ''))               AS DeliveryLocation,
            RTRIM(ISNULL(h.Billadd, ''))                AS BillingAddress,
            RTRIM(ISNULL(h.SPL_INS, ''))                AS SpecialInstr,
            RTRIM(ISNULL(h.DEL_INS2, ''))               AS Despatch,
            RTRIM(ISNULL(h.Note, ''))                   AS Purpose,
            RTRIM(ISNULL(h.Note2, ''))                  AS OtherLevies,
            RTRIM(ISNULL(h.PriceTerm, ''))               AS PricingTerms,
            RTRIM(ISNULL(h.RemarksPF, ''))               AS PackForwarding,
            RTRIM(ISNULL(h.RemarksIns, ''))              AS Insurance,
            RTRIM(ISNULL(h.RemarksFrt, ''))              AS Freight,
            -- Cancel / status (read-only context)
            RTRIM(ISNULL(h.CANFLG, ''))                 AS CancelFlag,
            CONVERT(VARCHAR(10), h.CANDT, 120)          AS CancelDate,
            RTRIM(ISNULL(h.REMINDER, ''))               AS Reminder,
            RTRIM(ISNULL(h.approved, ''))               AS Approved,
            RTRIM(ISNULL(h.appby, ''))                  AS ApprovedBy,
            RTRIM(ISNULL(h.Conflg, ''))                 AS Conflg,
            -- Audit
            RTRIM(ISNULL(u.user_name, h.createdby))     AS CreatedBy,
            ISNULL(CONVERT(VARCHAR(19), h.createddt, 103), '') AS CreatedDt
    FROM    PO_ORDH h
    LEFT JOIN FA_SLMAS s ON s.SLCODE = h.SLCODE
    -- PO_TYPE's key column is TYPE_CODE. (ksp_PO_GetOrderTypes exposes it as the
    -- alias "PoGrp", which is an OUTPUT name, not the column — do not join on POGRP.)
    LEFT JOIN PO_TYPE  t ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    OUTER APPLY (
        SELECT TOP 1 u.user_name
        FROM   PP_PASSWD u
        WHERE  RTRIM(u.user_id) = RTRIM(h.createdby)
          AND  RTRIM(u.divcode)  = RTRIM(h.DIVCODE)
    ) u
    WHERE   h.DIVCODE = @DivCode
      AND   h.PORDNO  = @PoNo
      AND   CAST(h.PORDDT AS DATE) = @PoDate
      AND   (@PoGrp IS NULL OR ISNULL(h.POGRP, '') = ISNULL(@PoGrp, ''));

    -- ── 2. Lines ─────────────────────────────────────────────────────────────
    SELECT  CAST(l.PORDSNO AS INT)                      AS SNo,
            RTRIM(l.ITEMCODE)                           AS ItemCode,
            RTRIM(ISNULL(i.ITEMNAME, ''))               AS ItemName,
            RTRIM(ISNULL(i.UOM, ''))                    AS Uom,
            RTRIM(ISNULL(CAST(l.QUOTNO AS VARCHAR(20)), '')) AS QuotNo,
            ISNULL(CONVERT(VARCHAR(10), l.QUOTDT, 120), '')  AS QuotDate,
            ISNULL(l.PRNO, 0)                           AS PrNo,
            ISNULL(CONVERT(VARCHAR(10), l.PRDATE, 120), '')  AS PrDate,
            ISNULL(l.PRSNO, 0)                          AS PrSno,
            ISNULL(l.Rate, 0)                           AS Rate,
            ISNULL(l.ORDqty, 0)                         AS Qty,
            ISNULL(l.Weight, 0)                         AS Weight,
            ISNULL(l.ORDVAL, 0)                         AS Value,
            ISNULL(l.FRate, 0)                          AS FRate,
            ISNULL(l.FValue, 0)                         AS FValue,
            ISNULL(l.disper, 0)                         AS DiscPer,
            ISNULL(l.disamt, 0)                         AS DiscAmt,
            ISNULL(l.PACKPER, 0)                        AS PackingPer,
            ISNULL(l.Packamt, 0)                        AS PackingAmt,
            ISNULL(l.Frgt1per, 0)                       AS FreightPer,
            ISNULL(l.Frgt1Amt, 0)                       AS FreightAmt,
            ISNULL(l.Ins_per, 0)                        AS InsurancePer,
            ISNULL(l.Ins_amt, 0)                        AS InsuranceAmt,
            ISNULL(l.OTHCHGS, 0)                        AS OtherCharges,
            ISNULL(l.FCACharg, 0)                       AS FcaFob,
            CASE WHEN UPPER(RTRIM(ISNULL(l.DISFLG,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
            CASE WHEN UPPER(RTRIM(ISNULL(l.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
            CASE WHEN UPPER(RTRIM(ISNULL(l.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPos,
            CASE WHEN UPPER(RTRIM(ISNULL(l.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsuranceDuty,
            RTRIM(ISNULL(l.hsncode, ''))                AS HsnCode,
            RTRIM(ISNULL(l.Tax_code, ''))               AS TaxCode,
            ISNULL(l.taxper, 0)                         AS TaxPer,
            ISNULL(l.Taxamt, 0)                         AS TaxAmt,
            RTRIM(ISNULL(l.cgst_tax_code, ''))          AS CgstCode,
            ISNULL(l.cgstper, 0)                        AS CgstPer,
            ISNULL(l.cgstamt, 0)                        AS CgstAmt,
            RTRIM(ISNULL(l.sgst_tax_code, ''))          AS SgstCode,
            ISNULL(l.sgstper, 0)                        AS SgstPer,
            ISNULL(l.sgstamt, 0)                        AS SgstAmt,
            RTRIM(ISNULL(l.igst_tax_code, ''))          AS IgstCode,
            ISNULL(l.igstper, 0)                        AS IgstPer,
            ISNULL(l.igstamt, 0)                        AS IgstAmt,
            ISNULL(l.Tcs_per, 0)                        AS TcsPer,
            ISNULL(l.Tcs_amt, 0)                        AS TcsAmt,
            RTRIM(ISNULL(l.ADDTAX_CODE, ''))            AS AddTaxCode,
            ISNULL(l.ADDTAXPER, 0)                      AS AddTaxPer,
            ISNULL(l.ADDTAXAMT, 0)                      AS AddTaxAmt,
            ISNULL(l.LANDCOST, 0)                       AS LandingCost,
            ISNULL(l.modvat, 0)                         AS Cenvat,
            ISNULL(l.RCVDQTY, 0)                        AS ReceivedQty,
            ISNULL(l.CANQTY, 0)                         AS CancelQty,
            -- PR remaining balance (qtyreqd - qtyord). Feeds the client-side amend
            -- ceiling (Gap #5): max new qty = current qty + this balance. NULL PR
            -- link → no PR ceiling, returned as a large sentinel so the UI does not
            -- clamp a non-PR line.
            ISNULL(( SELECT ISNULL(p.qtyreqd, 0) - ISNULL(p.QTYORD, 0)
                     FROM PO_PRL p
                     WHERE p.PRNO = l.PRNO AND p.PRDATE = l.PRDATE
                       AND p.DIVCODE = l.DIVCODE AND p.ITEMCODE = l.ITEMCODE
                       AND p.PRSNO = l.PRSNO ), 999999999)  AS PrBalance,
            RTRIM(ISNULL(l.AmedReason, ''))             AS AmendReason,
            RTRIM(ISNULL(l.Remarks, ''))                AS Remarks,
            RTRIM(ISNULL(l.ITEMMEMO, ''))               AS ItemMemo,
            RTRIM(ISNULL(l.reqidpo, ''))                AS RequesterId,
            RTRIM(ISNULL(l.reqnamepo, ''))              AS RequesterName,
            RTRIM(ISNULL(l.DepCode, ''))                AS DepCode
    FROM    PO_ORDL l
    LEFT JOIN IN_ITEM i ON i.ITEMCODE = l.ITEMCODE
    WHERE   l.DIVCODE = @DivCode
      AND   l.PORDNO  = @PoNo
      AND   CAST(l.PORDDT AS DATE) = @PoDate
      AND   (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''))
    ORDER BY l.PORDSNO;

    -- ── 3. Delivery schedule (PO_ORDL_DETL) ──────────────────────────────────
    -- Flat rows keyed by SNo+ItemCode; the client groups them under their line.
    SELECT  CAST(d.pordsno AS INT)                      AS SNo,
            RTRIM(d.itemcode)                           AS ItemCode,
            CAST(ROW_NUMBER() OVER (
                    PARTITION BY d.pordsno, d.itemcode
                    ORDER BY d.shdate) AS INT)          AS SlotNo,
            ISNULL(CONVERT(VARCHAR(10), d.shdate, 120), '') AS ShDate,
            ISNULL(d.Quantity, 0)                       AS Qty
    FROM    PO_ORDL_DETL d
    WHERE   d.divcode = @DivCode
      AND   d.pordno  = @PoNo
      AND   CAST(d.porddt AS DATE) = @PoDate
      AND   (@PoGrp IS NULL OR ISNULL(d.pogrp, '') = ISNULL(@PoGrp, ''))
    ORDER BY d.pordsno, d.shdate;
END;
GO

-- ============================================================
-- ksp_PO_GetAmendmentList
-- Find mode (FN-PO-Amendment v1.2 §1): lists SAVED amendments for the year,
-- view-only. Sourced from the amendment SNAPSHOT header PO_AORDH — one row per
-- amendment EVENT (a PO amended three times has three rows here), which is what
-- makes the AMDORDNO MAX(...)+1 allocation in ksp_PO_AmendOrder meaningful.
--
-- Result maps to AmendmentSummaryDto { DivCode, PoNo, PoDate, PoGroup, AmdNo,
-- AmdDate, Supplier, SupplierName, OrderValue } — Dapper binds BY NAME.
--
-- AMDORDNO is stored as a character column in legacy data (hence the SP's use of
-- CONVERT(INT, ...) when allocating). T-0119 addendum item (d) verified on both
-- JAT and SCMTS that ZERO non-numeric AMDORDNO values exist, so the TRY_CONVERT
-- below cannot silently drop rows on current data; TRY_ (not CONVERT) is used so
-- that a future bad row degrades to NULL in the list rather than failing the
-- whole query.
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm used inline ADO.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAmendmentList
(
    @DivCode VARCHAR(2),
    @YFDate  DATE = NULL,
    @YLDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(a.DIVCODE)                            AS DivCode,
            a.PORDNO                                    AS PoNo,
            CONVERT(VARCHAR(10), a.PORDDT, 120)         AS PoDate,
            RTRIM(ISNULL(a.POGRP, ''))                  AS PoGroup,
            ISNULL(TRY_CONVERT(INT, a.AMDORDNO), 0)     AS AmdNo,
            CONVERT(VARCHAR(10), a.AMDORDDT, 120)       AS AmdDate,
            RTRIM(ISNULL(a.SLCODE, ''))                 AS Supplier,
            RTRIM(ISNULL(s.SLNAME, ''))                 AS SupplierName,
            ISNULL(a.ORDVAL, 0)                         AS OrderValue
    FROM    PO_AORDH a
    LEFT JOIN FA_SLMAS s ON s.SLCODE = a.SLCODE
    WHERE   a.DIVCODE = @DivCode
      AND   (@YFDate IS NULL OR CAST(a.PORDDT AS DATE) >= @YFDate)
      AND   (@YLDate IS NULL OR CAST(a.PORDDT AS DATE) <= @YLDate)
    ORDER BY a.AMDORDDT DESC, a.PORDNO DESC, TRY_CONVERT(INT, a.AMDORDNO) DESC;
END;
GO

-- ============================================================
-- ksp_PO_AmendOrder
-- PO Amendment save (FN-PO-Amendment v1.2 §4 A–H). ONE transaction.
--
--   A. Allocate AMDORDNO = MAX(CONVERT(INT,AMDORDNO))+1 per DIVCODE per FY,
--      INSIDE the transaction under SERIALIZABLE + UPDLOCK/HOLDLOCK.
--      (VB6 read it unlocked before save → duplicate numbers under concurrency,
--       FN §6. Sasi 9-Jul also asked for SERIALIZABLE explicitly, matching the
--       CEO-approved usp_GetNextAmendNo design already live for the PR module.)
--   B. Guard + RECOMPUTE server-side. Client-sent amounts are NEVER trusted
--      (FN §4.B): only Rate/Qty/percentages/codes are read from the payload; all
--      money is derived here. GST split is resolved from PP_DIVMAS vs FA_SLMAS
--      state codes, GST % from IG_TAX (active codes only, FN §3.5).
--      §3.6 (CEO-confirmed): a line whose stored values CHANGED must carry an
--      AmendReason — enforced here, not only in React.
--   C. Snapshot the AMENDED order into PO_AORDH / PO_AORDL.
--      CD-AMD-01: CESS_AMT gets the cess AMOUNT (VB6 copied CESS_PER into it).
--      CD-AMD-02: PRDATE gets the real PR date (VB6's duplicate "Date" alias
--                 stored the Quotation date there).
--   D. Update live PO_ORDH / PO_ORDL / PO_ORDL_DETL on the full line key.
--      @@ROWCOUNT = 0 → RAISERROR → ROLLBACK (VB6 had no row-count checks).
--   E. PR backflush by DELTA (@NewQty - @PrevOrdQty) with a MANDATORY floor guard
--      and the PRSNO filter (CD-NEW-01; VB6's SQL branch omitted PRSNO, and its
--      Oracle branch added the FULL qty instead of the delta — CD-AMD-05).
--   E2. Conditional LogDet_PO 'WARN' row when the floor actually fires.
--   F. Release/refresh the linked quotation (PO_QUOTH).
--   G. LogDet_PO audit row per line. Trans_date = GETUTCDATE() (CEO ruling).
--      Audit failure ROLLS BACK (VB6 swallowed audit errors and still reported
--      success — FN §6).
--   H. COMMIT and RETURN the allocated Amendment No. as a SCALAR.
--
-- ⚠️ CONTRACT: the repository calls this with ExecuteScalarAsync<int>, so the
--    final statement MUST be a single-value SELECT of the amendment number.
--    There is deliberately NO @Result OUTPUT parameter — RAISERROR bubbles up as
--    a SqlException and the middleware maps it to HTTP 400, exactly as the PO
--    Cancellation / Foreclosure SPs already do. (The PR-module amendment SP uses
--    the @Result convention; do NOT copy that here.)
--
-- AMDORDDT = @TransDate (posting date from the API's X-Processing-Date header),
-- matching the LCANDT / FCLOSEDDT ruling. LogDet_PO.Trans_date stays GETUTCDATE().
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm did all of this
-- with inline ADO recordsets and UpdateBatch, with no transaction at all.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_AmendOrder
(
    @DivCode    VARCHAR(2),
    @TransDate  DATE,
    @UserId     VARCHAR(25),
    @HostName   VARCHAR(100) = NULL,
    @IpAddress  VARCHAR(50)  = NULL,
    @HeaderJson NVARCHAR(MAX),
    @LinesJson  NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Sasi 9-Jul: pair the amend-no allocation lock with SERIALIZABLE.
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRY
        ---------------------------------------------------------------------
        -- Parse the header payload
        ---------------------------------------------------------------------
        DECLARE
            @PoNo           NUMERIC(10,0),
            @PoDate         DATE,
            @PoGrp          VARCHAR(20),
            @Carrier        VARCHAR(10),
            @RefNo          VARCHAR(50),
            @PaymentTerms   VARCHAR(100),
            @CreditDays     INT,
            @BankCode       VARCHAR(20),
            @PayMode        VARCHAR(20),
            @AdvPer         NUMERIC(18,2),
            @AdvAmt         NUMERIC(18,2),
            @DelIns1        VARCHAR(200),
            @DelIns2        VARCHAR(200),
            @SplIns         VARCHAR(200),
            @RoundOff       NUMERIC(18,2),
            -- 13-Jul ruling (Mariyaiya + Seenivasan/IST): FN §1's "locked identity"
            -- restriction applies to the LINE GRID only. The HEADER follows VB6, where
            -- ENABLCONTLS unlocks every field — so Supplier and the GST fields are
            -- amendable. PO No / PO Date remain the record key and are NOT amendable
            -- (VB6 "allows" editing them only because its save reuses them as the WHERE
            -- key, which silently retargets a different PO — a latent bug, not a feature).
            @Supplier       VARCHAR(20),
            @Gstin          VARCHAR(20),
            @GstState       VARCHAR(10),
            @Inspect        VARCHAR(10),
            @FormType       VARCHAR(10),
            @Currency       VARCHAR(5),
            @CurrRate       NUMERIC(18,4),
            @HdrRemarks     VARCHAR(500),   -- header remarks; the loop reuses @Remarks for the LINE remarks
            @RefDate        DATE,
            @FileNo         VARCHAR(50),
            @DirectInstr    VARCHAR(200),
            @ChequeNo       VARCHAR(50),
            @ChequeDate     DATE,
            @DueDate        DATE,
            @HdrDiscPer     NUMERIC(9,4),
            @HdrPackPer     NUMERIC(9,4),
            @HdrInsurPer    NUMERIC(9,4),
            @HdrFreightAmt  NUMERIC(18,2),
            @HdrPackAmt     NUMERIC(18,2),
            @HdrInsurAmt    NUMERIC(18,2),
            @HdrAddTaxPer   NUMERIC(9,4),
            @FreightType    VARCHAR(10),
            @HdrDiscApp     VARCHAR(10),
            @HdrPackApp     VARCHAR(10),
            @HdrFrtPos      VARCHAR(10),
            @HdrInsPos      VARCHAR(10);

        SELECT  @PoNo         = j.poNo,
                @PoDate       = TRY_CAST(j.poDate AS DATE),
                @PoGrp        = RTRIM(ISNULL(j.poGrp, '')),
                @Carrier      = RTRIM(ISNULL(j.carrier, '')),
                @RefNo        = ISNULL(j.refNo, ''),
                @PaymentTerms = ISNULL(j.paymentTerms, ''),
                @CreditDays   = ISNULL(j.creditDays, 0),
                @BankCode     = ISNULL(j.bankCode, ''),
                @PayMode      = ISNULL(NULLIF(RTRIM(j.payMode), ''), 'DIRECT'),
                @AdvPer       = ISNULL(j.advPer, 0),
                @AdvAmt       = ISNULL(j.advAmt, 0),
                @DelIns1      = ISNULL(j.deliveryInstr1, ''),
                @DelIns2      = ISNULL(j.deliveryInstr2, ''),
                @SplIns       = ISNULL(j.specialInstr, ''),
                @RoundOff     = ISNULL(j.roundOff, 0),
                @Supplier     = RTRIM(ISNULL(j.supplier, '')),
                @Gstin        = ISNULL(j.gstin, ''),
                -- The UI shows GST state as "33 - Tamil Nadu"; store only the code.
                @GstState     = LEFT(RTRIM(LTRIM(ISNULL(j.gstState, ''))), 2),
                @Inspect      = ISNULL(j.inspect, ''),
                @FormType     = ISNULL(j.formType, ''),
                @Currency     = ISNULL(j.currency, ''),
                @CurrRate     = ISNULL(j.currRate, 0),
                @HdrRemarks   = ISNULL(j.remarks, ''),
                @RefDate      = TRY_CAST(j.refDate AS DATE),
                @FileNo       = ISNULL(j.fileNo, ''),
                @DirectInstr  = ISNULL(j.directInstr, ''),
                @ChequeNo     = ISNULL(j.chequeNo, ''),
                @ChequeDate   = TRY_CAST(j.chequeDate AS DATE),
                @DueDate      = TRY_CAST(j.dueDate AS DATE),
                @HdrDiscPer   = ISNULL(j.discPer, 0),
                @HdrPackPer   = ISNULL(j.packPer, 0),
                @HdrInsurPer  = ISNULL(j.insurPer, 0),
                @HdrFreightAmt= ISNULL(j.freightAmt, 0),
                @HdrPackAmt   = ISNULL(j.packingAmt, 0),
                @HdrInsurAmt  = ISNULL(j.insuranceAmt, 0),
                @HdrAddTaxPer = ISNULL(j.addTaxPer, 0),
                @FreightType  = ISNULL(NULLIF(RTRIM(j.freightType), ''), 'PAID'),
                @HdrDiscApp   = UPPER(ISNULL(NULLIF(RTRIM(j.discApp),           ''), 'BEFORE')),
                @HdrPackApp   = UPPER(ISNULL(NULLIF(RTRIM(j.packApp),           ''), 'BEFORE')),
                @HdrFrtPos    = UPPER(ISNULL(NULLIF(RTRIM(j.freightPosition),   ''), 'BEFORE')),
                @HdrInsPos    = UPPER(ISNULL(NULLIF(RTRIM(j.insurancePosition), ''), 'BEFORE'))
        FROM OPENJSON(@HeaderJson)
        WITH (
            poNo           NUMERIC(10,0) '$.poNo',
            poDate         NVARCHAR(10)  '$.poDate',
            poGrp          VARCHAR(20)   '$.poGrp',
            carrier        VARCHAR(10)   '$.carrier',
            refNo          VARCHAR(50)   '$.refNo',
            paymentTerms   VARCHAR(100)  '$.paymentTerms',
            creditDays     INT           '$.creditDays',
            bankCode       VARCHAR(20)   '$.bankCode',
            payMode        VARCHAR(20)   '$.payMode',
            advPer         NUMERIC(18,2) '$.advPer',
            advAmt         NUMERIC(18,2) '$.advAmt',
            deliveryInstr1 VARCHAR(200)  '$.deliveryInstr1',
            deliveryInstr2 VARCHAR(200)  '$.deliveryInstr2',
            specialInstr   VARCHAR(200)  '$.specialInstr',
            roundOff       NUMERIC(18,2) '$.roundOff',
            supplier       VARCHAR(20)   '$.supplier',
            gstin          VARCHAR(20)   '$.gstin',
            gstState       VARCHAR(50)   '$.gstState',
            inspect        VARCHAR(10)   '$.inspect',
            formType       VARCHAR(10)   '$.formType',
            currency       VARCHAR(5)    '$.currency',
            currRate       NUMERIC(18,4) '$.currRate',
            remarks        VARCHAR(500)  '$.remarks',
            refDate        NVARCHAR(10)  '$.refDate',
            fileNo         VARCHAR(50)   '$.fileNo',
            directInstr    VARCHAR(200)  '$.directInstr',
            chequeNo       VARCHAR(50)   '$.chequeNo',
            chequeDate     NVARCHAR(10)  '$.chequeDate',
            dueDate        NVARCHAR(10)  '$.dueDate',
            discPer        NUMERIC(9,4)  '$.discPer',
            packPer        NUMERIC(9,4)  '$.packPer',
            insurPer       NUMERIC(9,4)  '$.insurPer',
            freightAmt     NUMERIC(18,2) '$.freightAmt',
            packingAmt     NUMERIC(18,2) '$.packingAmt',
            insuranceAmt   NUMERIC(18,2) '$.insuranceAmt',
            addTaxPer      NUMERIC(9,4)  '$.addTaxPer',
            freightType    VARCHAR(10)   '$.freightType',
            discApp        VARCHAR(10)   '$.discApp',
            packApp        VARCHAR(10)   '$.packApp',
            freightPosition   VARCHAR(10) '$.freightPosition',
            insurancePosition VARCHAR(10) '$.insurancePosition'
        ) j;

        -- §3.2 / §3.3 — defence in depth behind the service layer.
        IF @Carrier  = '' RAISERROR('Carrier cannot be empty.', 16, 1);
        IF @PoGrp    = '' RAISERROR('Order Type cannot be empty.', 16, 1);
        IF @Supplier = '' RAISERROR('Supplier cannot be empty.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM FA_SLMAS WHERE RTRIM(SLCODE) = @Supplier)
            RAISERROR('The selected supplier does not exist.', 16, 1);

        -- Gap #1/#2 (VB6 parity) — CORRECTED after live /verify against real JAT data
        -- (13-Jul): 366 of 1444 live suppliers (25%) have NO GSTIN in FA_SLMAS,
        -- including suppliers already in active use on real POs. VB6 only enforces
        -- "GST No. / GST state code not available" at the moment a NEW supplier is
        -- being SELECTED (Command1_Click / txtFields_Validate idx 4) — it is not a
        -- standing save-time constraint on a PO's already-stored, unchanged supplier.
        -- Enforcing it unconditionally would have made ~1 in 4 real POs unamendable
        -- for ANY reason, including changes that have nothing to do with GST. So this
        -- only fires when @Supplier is actually DIFFERENT from what PO_ORDH already
        -- has — i.e., the user is genuinely changing the supplier, which is exactly
        -- the VB6 moment being reproduced.
        DECLARE @OrigSupplier VARCHAR(20) = '';
        SELECT TOP 1 @OrigSupplier = RTRIM(ISNULL(SLCODE, ''))
        FROM   PO_ORDH
        WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate
          AND  ISNULL(POGRP, '') = ISNULL(@PoGrp, '');

        IF @OrigSupplier <> @Supplier
        BEGIN
            DECLARE @SupGstin VARCHAR(20) = '', @SupGstState VARCHAR(10) = '';
            SELECT TOP 1 @SupGstin    = RTRIM(ISNULL(CAST(gstinno       AS VARCHAR(20)), '')),
                         @SupGstState = RTRIM(ISNULL(CAST(gststatecode  AS VARCHAR(10)), ''))
            FROM   FA_SLMAS WHERE RTRIM(SLCODE) = @Supplier;

            IF @SupGstin = ''
                RAISERROR('The GST No. is not available for the selected supplier.', 16, 1);
            IF @SupGstState = ''
                RAISERROR('The GST state code is not available for the selected supplier.', 16, 1);
        END

        -- Gap #10 (VB6 parity): a foreign currency needs a conversion rate. VB6
        -- reads it from PO_ConvFactT and blocks ("Selected dollar rate is empty");
        -- SPINRISE carries the rate on the header, so require it to be > 0 here.
        IF @Currency <> '' AND UPPER(@Currency) <> 'INR' AND ISNULL(@CurrRate, 0) <= 0
            RAISERROR('A currency conversion rate is required for a foreign-currency Purchase Order.', 16, 1);

        ---------------------------------------------------------------------
        -- Parse the line payload
        ---------------------------------------------------------------------
        DECLARE @Lines TABLE (
            RowId         INT IDENTITY(1,1) PRIMARY KEY,
            SNo           NUMERIC(5,0),
            ItemCode      VARCHAR(10),
            PrNo          NUMERIC(6,0),
            PrDate        DATE,
            PrSno         NUMERIC(5,0),
            Rate          NUMERIC(18,4),
            Qty           NUMERIC(18,3),
            Weight        NUMERIC(18,3),
            DiscPer       NUMERIC(9,4),
            PackingPer    NUMERIC(9,4),
            FreightPer    NUMERIC(9,4),
            InsurancePer  NUMERIC(9,4),
            OtherCharges  NUMERIC(18,2),
            DiscApp       VARCHAR(10),
            PackApp       VARCHAR(10),
            FreightPos    VARCHAR(10),
            InsuranceDuty VARCHAR(10),
            TaxCode       VARCHAR(10),
            HsnCode       VARCHAR(10),
            CgstCode      VARCHAR(10),
            SgstCode      VARCHAR(10),
            IgstCode      VARCHAR(10),
            TcsPer        NUMERIC(9,4),
            AddTaxCode    VARCHAR(10),
            AddTaxPer     NUMERIC(9,4),
            Remarks       VARCHAR(200),
            ItemMemo      VARCHAR(200),
            AmendReason   VARCHAR(200),
            SlotsJson     NVARCHAR(MAX)
        );

        INSERT INTO @Lines (SNo, ItemCode, PrNo, PrDate, PrSno, Rate, Qty, Weight,
                            DiscPer, PackingPer, FreightPer, InsurancePer, OtherCharges,
                            DiscApp, PackApp, FreightPos, InsuranceDuty,
                            TaxCode, HsnCode, CgstCode, SgstCode, IgstCode,
                            TcsPer, AddTaxCode, AddTaxPer, Remarks, ItemMemo,
                            AmendReason, SlotsJson)
        SELECT  j.sNo, j.itemCode, j.prNo, TRY_CAST(j.prDate AS DATE), j.prSno,
                j.rate, j.qty, ISNULL(j.weight, 0),
                ISNULL(j.discPer, 0), ISNULL(j.packingPer, 0), ISNULL(j.freightPer, 0),
                ISNULL(j.insurancePer, 0), ISNULL(j.otherCharges, 0),
                UPPER(ISNULL(NULLIF(RTRIM(j.discApp),       ''), 'BEFORE')),
                UPPER(ISNULL(NULLIF(RTRIM(j.packApp),       ''), 'BEFORE')),
                UPPER(ISNULL(NULLIF(RTRIM(j.freightPos),    ''), 'BEFORE')),
                UPPER(ISNULL(NULLIF(RTRIM(j.insuranceDuty), ''), 'BEFORE')),
                ISNULL(j.taxCode, ''), ISNULL(j.hsnCode, ''),
                ISNULL(j.cgstCode, ''), ISNULL(j.sgstCode, ''), ISNULL(j.igstCode, ''),
                ISNULL(j.tcsPer, 0), ISNULL(j.addTaxCode, ''), ISNULL(j.addTaxPer, 0),
                ISNULL(j.remarks, ''), ISNULL(j.itemMemo, ''),
                RTRIM(ISNULL(j.amendReason, '')),
                j.slots
        FROM OPENJSON(@LinesJson)
        WITH (
            sNo           NUMERIC(5,0)  '$.sNo',
            itemCode      VARCHAR(10)   '$.itemCode',
            prNo          NUMERIC(6,0)  '$.prNo',
            prDate        NVARCHAR(10)  '$.prDate',
            prSno         NUMERIC(5,0)  '$.prSno',
            rate          NUMERIC(18,4) '$.rate',
            qty           NUMERIC(18,3) '$.qty',
            weight        NUMERIC(18,3) '$.weight',
            discPer       NUMERIC(9,4)  '$.discPer',
            packingPer    NUMERIC(9,4)  '$.packingPer',
            freightPer    NUMERIC(9,4)  '$.freightPer',
            insurancePer  NUMERIC(9,4)  '$.insurancePer',
            otherCharges  NUMERIC(18,2) '$.otherCharges',
            discApp       VARCHAR(10)   '$.discApp',
            packApp       VARCHAR(10)   '$.packApp',
            freightPos    VARCHAR(10)   '$.freightPos',
            insuranceDuty VARCHAR(10)   '$.insuranceDuty',
            taxCode       VARCHAR(10)   '$.taxCode',
            hsnCode       VARCHAR(10)   '$.hsnCode',
            cgstCode      VARCHAR(10)   '$.cgstCode',
            sgstCode      VARCHAR(10)   '$.sgstCode',
            igstCode      VARCHAR(10)   '$.igstCode',
            tcsPer        NUMERIC(9,4)  '$.tcsPer',
            addTaxCode    VARCHAR(10)   '$.addTaxCode',
            addTaxPer     NUMERIC(9,4)  '$.addTaxPer',
            remarks       VARCHAR(200)  '$.remarks',
            itemMemo      VARCHAR(200)  '$.itemMemo',
            amendReason   VARCHAR(200)  '$.amendReason',
            slots         NVARCHAR(MAX) '$.slots' AS JSON
        ) j
        -- §3.7 — blank-item rows are dropped before save, not an error.
        WHERE RTRIM(ISNULL(j.itemCode, '')) <> '';

        IF NOT EXISTS (SELECT 1 FROM @Lines)
            RAISERROR('No changes to amend — modify at least one item to complete the transaction.', 16, 1);

        BEGIN TRANSACTION;

        ---------------------------------------------------------------------
        -- Header guard — the PO must exist and must not be cancelled (§1).
        ---------------------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM PO_ORDH WITH (UPDLOCK, HOLDLOCK)
            WHERE DIVCODE = @DivCode AND PORDNO = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND ISNULL(POGRP, '') = ISNULL(@PoGrp, '')
              AND CANFLG IS NULL AND CANDT IS NULL
        )
            RAISERROR('Purchase Order not found, or it has been cancelled and cannot be amended.', 16, 1);

        ---------------------------------------------------------------------
        -- A. Allocate the Amendment No. — per DIVCODE per FINANCIAL YEAR.
        --    Indian FY: 1-Apr → 31-Mar, derived from the posting date.
        ---------------------------------------------------------------------
        DECLARE @FyStart DATE = DATEFROMPARTS(
                    YEAR(@TransDate) - CASE WHEN MONTH(@TransDate) < 4 THEN 1 ELSE 0 END, 4, 1);
        DECLARE @FyEnd   DATE = DATEADD(DAY, -1, DATEADD(YEAR, 1, @FyStart));

        DECLARE @AmdNo INT;

        -- UPDLOCK+HOLDLOCK under SERIALIZABLE: serialises concurrent allocations
        -- so two users cannot read the same MAX and both write it (the VB6 defect).
        -- T-0119 addendum item (d) confirmed ZERO non-numeric AMDORDNO on JAT and
        -- SCMTS, so CONVERT(INT, ...) is safe on current data; TRY_CONVERT is used
        -- anyway so a future bad row cannot take the save down with a cast error.
        SELECT @AmdNo = ISNULL(MAX(TRY_CONVERT(INT, AMDORDNO)), 0) + 1
        FROM   PO_AORDH WITH (UPDLOCK, HOLDLOCK)
        WHERE  DIVCODE = @DivCode
          AND  CAST(AMDORDDT AS DATE) BETWEEN @FyStart AND @FyEnd;

        SET @AmdNo = ISNULL(@AmdNo, 1);

        ---------------------------------------------------------------------
        -- GST route — server-decided (FN §4.B): division state = supplier state
        -- ⇒ CGST+SGST, else IGST. The client's route is never trusted.
        --
        -- ⚠️ Resolved from the INCOMING @Supplier, not the one currently stored on
        -- PO_ORDH. Since the 13-Jul ruling the supplier is amendable, and changing it
        -- can flip the route (CGST+SGST ⇄ IGST) — in which case EVERY line's tax must
        -- re-base. Reading the stored supplier here would silently recompute the new
        -- supplier's PO against the OLD supplier's state.
        --
        -- The header GST state (@GstState) is what the user sees/edits and is stored on
        -- PO_ORDH, but it is NOT used to decide the route: the route is a fact about the
        -- supplier master (FA_SLMAS), and taking it from an editable header field would
        -- let a typo re-route the tax.
        ---------------------------------------------------------------------
        DECLARE @DivState VARCHAR(10) = '', @SupState VARCHAR(10) = '';
        SELECT TOP 1 @DivState = RTRIM(ISNULL(CAST(d.gststatecode AS VARCHAR(10)), ''))
        FROM   pp_divmas d WHERE RTRIM(d.divcode) = RTRIM(@DivCode);
        SELECT TOP 1 @SupState = RTRIM(ISNULL(CAST(s.gststatecode AS VARCHAR(10)), ''))
        FROM   FA_SLMAS s WHERE RTRIM(s.SLCODE) = @Supplier;

        DECLARE @IsLocal BIT =
            CASE WHEN @DivState <> '' AND @DivState = @SupState THEN 1 ELSE 0 END;

        ---------------------------------------------------------------------
        -- Per-line loop: B (guard + recompute) → D (update) → E/E2 → F → G
        ---------------------------------------------------------------------
        DECLARE @RowId INT = (SELECT MIN(RowId) FROM @Lines);
        DECLARE @SNo NUMERIC(5,0), @ItemCode VARCHAR(10),
                @PrNo NUMERIC(6,0), @PrDate DATE, @PrSno NUMERIC(5,0),
                @Rate NUMERIC(18,4), @Qty NUMERIC(18,3), @Weight NUMERIC(18,3),
                @DiscPer NUMERIC(9,4), @PackPer NUMERIC(9,4), @FrgtPer NUMERIC(9,4),
                @InsPer NUMERIC(9,4), @OthChgs NUMERIC(18,2),
                @DiscApp VARCHAR(10), @PackApp VARCHAR(10),
                @FrtPos VARCHAR(10), @InsPos VARCHAR(10),
                @TaxCode VARCHAR(10), @HsnCode VARCHAR(10),
                @CgstCode VARCHAR(10), @SgstCode VARCHAR(10), @IgstCode VARCHAR(10),
                @TcsPer NUMERIC(9,4), @AddTaxCode VARCHAR(10), @AddTaxPer NUMERIC(9,4),
                @Remarks VARCHAR(200), @ItemMemo VARCHAR(200), @AmendReason VARCHAR(200),
                @SlotsJson NVARCHAR(MAX);

        DECLARE @PrevQty NUMERIC(18,3), @RcvdQty NUMERIC(18,3), @CanQty NUMERIC(18,3),
                @PrevRate NUMERIC(18,4), @PrevDiscPer NUMERIC(9,4), @PrevPackPer NUMERIC(9,4),
                @PrevFrgtPer NUMERIC(9,4), @PrevInsPer NUMERIC(9,4), @PrevOthChgs NUMERIC(18,2),
                @PrevTaxCode VARCHAR(10), @PrevCgstCode VARCHAR(10),
                @PrevSgstCode VARCHAR(10), @PrevIgstCode VARCHAR(10),
                @PrevTcsPer NUMERIC(9,4), @PrevHsnCode VARCHAR(10),
                @LinePrNo NUMERIC(6,0), @LinePrDate DATE, @LinePrSno NUMERIC(5,0),
                @QuotNo NUMERIC(10,0);

        DECLARE @GstPer NUMERIC(9,4), @CgstPer NUMERIC(9,4), @SgstPer NUMERIC(9,4),
                @IgstPer NUMERIC(9,4), @ResolvedCode VARCHAR(10);
        DECLARE @Gross NUMERIC(18,2), @DiscAmt NUMERIC(18,2), @NetAfterDisc NUMERIC(18,2),
                @PackAmt NUMERIC(18,2), @FrgtAmt NUMERIC(18,2), @InsAmt NUMERIC(18,2),
                @GstBase NUMERIC(18,2), @CgstAmt NUMERIC(18,2), @SgstAmt NUMERIC(18,2),
                @IgstAmt NUMERIC(18,2), @TcsAmt NUMERIC(18,2), @AddTaxAmt NUMERIC(18,2),
                @LandCost NUMERIC(18,2);
        DECLARE @Delta NUMERIC(18,3), @Shortfall NUMERIC(18,3), @Changed BIT;
        DECLARE @PrReqd NUMERIC(18,3), @PrOrd NUMERIC(18,3), @PrRemaining NUMERIC(18,3);
        DECLARE @ErrMsg NVARCHAR(300);

        WHILE @RowId IS NOT NULL
        BEGIN
            SELECT @SNo = SNo, @ItemCode = ItemCode, @PrNo = PrNo, @PrDate = PrDate,
                   @PrSno = PrSno, @Rate = Rate, @Qty = Qty, @Weight = Weight,
                   @DiscPer = DiscPer, @PackPer = PackingPer, @FrgtPer = FreightPer,
                   @InsPer = InsurancePer, @OthChgs = OtherCharges,
                   @DiscApp = DiscApp, @PackApp = PackApp,
                   @FrtPos = FreightPos, @InsPos = InsuranceDuty,
                   @TaxCode = TaxCode, @HsnCode = HsnCode,
                   @CgstCode = CgstCode, @SgstCode = SgstCode, @IgstCode = IgstCode,
                   @TcsPer = TcsPer, @AddTaxCode = AddTaxCode, @AddTaxPer = AddTaxPer,
                   @Remarks = Remarks, @ItemMemo = ItemMemo, @AmendReason = AmendReason,
                   @SlotsJson = SlotsJson
            FROM   @Lines WHERE RowId = @RowId;

            -- §3.4 static half
            IF @Rate IS NULL OR @Rate <= 0
                RAISERROR('Rate must be greater than zero on every amended line.', 16, 1);
            IF @Qty IS NULL OR @Qty <= 0
                RAISERROR('Order Quantity is required on every amended line.', 16, 1);

            -- B. Re-read the LIVE line on the full key (never trust the grid).
            SET @PrevQty = NULL;
            SELECT @PrevQty      = ISNULL(ORDqty, 0),
                   @RcvdQty      = ISNULL(RCVDQTY, 0),
                   @CanQty       = ISNULL(CANQTY, 0),
                   @PrevRate     = ISNULL(Rate, 0),
                   @PrevDiscPer  = ISNULL(disper, 0),
                   @PrevPackPer  = ISNULL(PACKPER, 0),
                   @PrevFrgtPer  = ISNULL(Frgt1per, 0),
                   @PrevInsPer   = ISNULL(Ins_per, 0),
                   @PrevOthChgs  = ISNULL(OTHCHGS, 0),
                   @PrevTaxCode  = RTRIM(ISNULL(Tax_code, '')),
                   @PrevCgstCode = RTRIM(ISNULL(cgst_tax_code, '')),
                   @PrevSgstCode = RTRIM(ISNULL(sgst_tax_code, '')),
                   @PrevIgstCode = RTRIM(ISNULL(igst_tax_code, '')),
                   @PrevTcsPer   = ISNULL(Tcs_per, 0),
                   @PrevHsnCode  = RTRIM(ISNULL(hsncode, '')),
                   @LinePrNo     = PRNO,
                   @LinePrDate   = PRDATE,
                   @LinePrSno    = PRSNO,
                   @QuotNo       = QUOTNO
            FROM   PO_ORDL WITH (UPDLOCK, HOLDLOCK)
            WHERE  DIVCODE = @DivCode
              AND  ISNULL(POGRP, '') = ISNULL(@PoGrp, '')
              AND  PORDNO  = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo
              AND  ITEMCODE = @ItemCode
              -- Still-open guard (§4.B): protects against stale grid data.
              AND  ISNULL(FCLOSED, 'N') <> 'Y'
              AND  ISNULL(LCANFLG, '')  <> 'C';

            IF @PrevQty IS NULL
                RAISERROR('An amended line no longer exists, or has been cancelled/foreclosed. Reload the Purchase Order and retry.', 16, 1);

            -- §3.4 dynamic half — the amended qty may not drop below what has
            -- already been received + cancelled. (VB6 did not check this at all.)
            IF @Qty < (@RcvdQty + @CanQty)
            BEGIN
                SET @ErrMsg = 'Amended quantity cannot be less than the received plus cancelled quantity ('
                            + LTRIM(STR(@RcvdQty + @CanQty, 18, 3)) + ') for a selected line.';
                RAISERROR(@ErrMsg, 16, 1);
            END

            -- Gap #5 (VB6 parity): the INCREASE in order qty may not exceed the PR's
            -- remaining unordered balance. VB6 grid rule: newqty - modqty >
            -- (qtyreqd - qtyord). PO_PRL.QTYORD already includes this PO's current
            -- contribution (@PrevQty), so the remaining balance is (qtyreqd - qtyord)
            -- and the allowed increase is exactly that. Only checked when the qty goes
            -- UP and the line has a PR link; lines with no PR link are uncapped.
            IF @LinePrNo IS NOT NULL AND @LinePrNo > 0 AND @Qty > @PrevQty
            BEGIN
                SET @PrReqd = NULL;
                SELECT @PrReqd = ISNULL(qtyreqd, 0),
                       @PrOrd  = ISNULL(QTYORD, 0)
                FROM   PO_PRL
                WHERE  PRNO = @LinePrNo AND PRDATE = @LinePrDate
                  AND  DIVCODE = @DivCode AND ITEMCODE = @ItemCode AND PRSNO = @LinePrSno;

                IF @PrReqd IS NOT NULL
                BEGIN
                    SET @PrRemaining = @PrReqd - @PrOrd;   -- may be 0 if fully ordered
                    IF (@Qty - @PrevQty) > @PrRemaining
                    BEGIN
                        SET @ErrMsg = 'Amended quantity exceeds the Purchase Requisition balance for a selected line. '
                                    + 'Maximum allowed quantity: '
                                    + LTRIM(STR(@PrevQty + @PrRemaining, 18, 3)) + '.';
                        RAISERROR(@ErrMsg, 16, 1);
                    END
                END
            END

            -- §3.6 — CEO-confirmed: ANY changed line needs a reason. Determined
            -- HERE against the live row, so a tampered client cannot bypass it.
            SET @Changed =
                CASE WHEN @Rate     <> @PrevRate
                       OR @Qty      <> @PrevQty
                       OR @DiscPer  <> @PrevDiscPer
                       OR @PackPer  <> @PrevPackPer
                       OR @FrgtPer  <> @PrevFrgtPer
                       OR @InsPer   <> @PrevInsPer
                       OR @OthChgs  <> @PrevOthChgs
                       OR @TaxCode  <> @PrevTaxCode
                       OR @CgstCode <> @PrevCgstCode
                       OR @SgstCode <> @PrevSgstCode
                       OR @IgstCode <> @PrevIgstCode
                       OR @TcsPer   <> @PrevTcsPer
                       OR @HsnCode  <> @PrevHsnCode
                     THEN 1 ELSE 0 END;

            IF @Changed = 1 AND @AmendReason = ''
            BEGIN
                SET @ErrMsg = 'Amendment Reason is required on every changed line (line '
                            + LTRIM(STR(@SNo, 6, 0)) + ').';
                RAISERROR(@ErrMsg, 16, 1);
            END

            -- §3.5 — GST codes must be ACTIVE in IG_TAX. Resolve the % from the
            -- master; never take a percentage from the client.
            --
            -- CGST/SGST and IGST all derive from the SAME IG_TAX row
            -- (ksp_PO_GetGstTaxCodes: CGST = SGST = ST_PER/2, IGST = ST_PER), so the
            -- tax code is route-independent. That matters now that the supplier is
            -- amendable: if the route flips LOCAL → IGST, a line that only ever carried
            -- a CGST code would otherwise resolve 0% and SILENTLY ZERO ITS TAX.
            -- So resolve from whichever code the line actually has, preferring the
            -- route's own, and mirror the frontend's applyGstRouteToLine by rewriting
            -- the code columns to match the new route.
            SET @ResolvedCode = RTRIM(COALESCE(
                NULLIF(CASE WHEN @IsLocal = 1 THEN @CgstCode ELSE @IgstCode END, ''),
                NULLIF(@TaxCode,  ''),
                NULLIF(@CgstCode, ''),
                NULLIF(@SgstCode, ''),
                NULLIF(@IgstCode, ''),
                ''));

            SET @GstPer = NULL;
            IF @ResolvedCode <> ''
            BEGIN
                SELECT TOP 1 @GstPer = ISNULL(t.ST_PER, 0)
                FROM   IG_TAX t
                WHERE  RTRIM(t.TAX_CODE) = @ResolvedCode
                  AND  UPPER(ISNULL(t.TAXSTATUS, 'Y')) = 'Y';

                IF @GstPer IS NULL
                BEGIN
                    SET @ErrMsg = 'GST tax code "' + @ResolvedCode + '" is not an active code.';
                    RAISERROR(@ErrMsg, 16, 1);
                END
            END
            SET @GstPer = ISNULL(@GstPer, 0);

            IF @IsLocal = 1
            BEGIN
                SET @CgstPer  = ROUND(@GstPer / 2.0, 2);
                SET @SgstPer  = ROUND(@GstPer / 2.0, 2);
                SET @IgstPer  = 0;
                SET @CgstCode = @ResolvedCode;
                SET @SgstCode = @ResolvedCode;
                SET @IgstCode = '';
            END
            ELSE
            BEGIN
                SET @CgstPer  = 0;
                SET @SgstPer  = 0;
                SET @IgstPer  = @GstPer;
                SET @CgstCode = '';
                SET @SgstCode = '';
                SET @IgstCode = @ResolvedCode;
            END
            SET @TaxCode = @ResolvedCode;

            -- B. RECOMPUTE all money server-side. Formulas mirror ksp_PO_SaveEntry
            -- (POT-TC-01: packing/freight/insurance are on net-of-discount, NOT gross).
            SET @Gross        = ROUND(@Rate * @Qty, 2);
            SET @DiscAmt      = ROUND(@Gross * @DiscPer / 100.0, 2);
            SET @NetAfterDisc = ROUND(@Gross - @DiscAmt, 2);
            SET @PackAmt      = ROUND(@NetAfterDisc * @PackPer / 100.0, 2);
            SET @FrgtAmt      = ROUND(@NetAfterDisc * @FrgtPer / 100.0, 2);
            SET @InsAmt       = ROUND(@NetAfterDisc * @InsPer  / 100.0, 2);

            -- GST assessable base shifts with the BEFORE/AFTER position flags.
            SET @GstBase = ROUND(
                  @Gross
                - CASE WHEN @DiscApp = 'BEFORE' THEN @DiscAmt ELSE 0 END
                + CASE WHEN @FrtPos  = 'BEFORE' THEN @FrgtAmt ELSE 0 END
                + CASE WHEN @PackApp = 'BEFORE' THEN @PackAmt ELSE 0 END
                + CASE WHEN @InsPos  = 'BEFORE' THEN @InsAmt  ELSE 0 END, 2);

            SET @CgstAmt   = ROUND(@GstBase * @CgstPer / 100.0, 2);
            SET @SgstAmt   = ROUND(@GstBase * @SgstPer / 100.0, 2);
            SET @IgstAmt   = ROUND(@GstBase * @IgstPer / 100.0, 2);
            SET @TcsAmt    = ROUND(@Gross   * @TcsPer  / 100.0, 2);
            SET @AddTaxAmt = ROUND(@Gross   * @AddTaxPer / 100.0, 2);

            SET @LandCost  = ROUND(@Gross - @DiscAmt + @PackAmt + @FrgtAmt + @InsAmt
                                 + @CgstAmt + @SgstAmt + @IgstAmt
                                 + @TcsAmt + @AddTaxAmt + @OthChgs, 2);

            -- D. Update the LIVE line on the full key.
            UPDATE PO_ORDL
            SET    Rate          = @Rate,
                   ORDqty        = @Qty,
                   ORDVAL        = @Gross,
                   Weight        = @Weight,
                   FRate         = @Rate,
                   FValue        = @Gross,
                   disper        = @DiscPer,
                   disamt        = @DiscAmt,
                   PACKPER       = @PackPer,
                   Packamt       = @PackAmt,
                   Frgt1per      = @FrgtPer,
                   Frgt1Amt      = @FrgtAmt,
                   Ins_per       = @InsPer,
                   Ins_amt       = @InsAmt,
                   OTHCHGS       = @OthChgs,
                   -- DISFLG/PACK_FLG/FRT_FLG/Ins_Flg store single-char 'B'/'A' codes, not
                   -- the 'BEFORE'/'AFTER' words @DiscApp etc. hold — writing the word
                   -- directly truncates (Msg 8152). Reverse-map exactly as ksp_PO_SaveEntry does.
                   DISFLG        = CASE WHEN UPPER(RTRIM(ISNULL(@DiscApp,''))) = 'AFTER' THEN 'A' ELSE 'B' END,
                   PACK_FLG      = CASE WHEN UPPER(RTRIM(ISNULL(@PackApp,'')))  = 'AFTER' THEN 'A' ELSE 'B' END,
                   FRT_FLG       = CASE WHEN UPPER(RTRIM(ISNULL(@FrtPos,'')))   = 'AFTER' THEN 'A' ELSE 'B' END,
                   Ins_Flg       = CASE WHEN UPPER(RTRIM(ISNULL(@InsPos,'')))   = 'AFTER' THEN 'A' ELSE 'B' END,
                   Tax_code      = LEFT(@TaxCode, 5),
                   taxper        = @CgstPer + @SgstPer + @IgstPer,
                   Taxamt        = @CgstAmt + @SgstAmt + @IgstAmt,
                   hsncode       = LEFT(@HsnCode, 8),
                   cgstper       = @CgstPer,
                   cgstamt       = @CgstAmt,
                   cgst_tax_code = LEFT(@CgstCode, 5),
                   sgstper       = @SgstPer,
                   sgstamt       = @SgstAmt,
                   sgst_tax_code = LEFT(@SgstCode, 5),
                   igstper       = @IgstPer,
                   igstamt       = @IgstAmt,
                   igst_tax_code = LEFT(@IgstCode, 5),
                   Tcs_per       = @TcsPer,
                   Tcs_amt       = @TcsAmt,
                   ADDTAX_CODE   = LEFT(@AddTaxCode, 5),
                   ADDTAXPER     = @AddTaxPer,
                   ADDTAXAMT     = @AddTaxAmt,
                   LANDCOST      = @LandCost,
                   Remarks       = @Remarks,
                   ITEMMEMO      = @ItemMemo,
                   AmedReason    = @AmendReason
            WHERE  DIVCODE = @DivCode
              AND  ISNULL(POGRP, '') = ISNULL(@PoGrp, '')
              AND  PORDNO  = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo
              AND  ITEMCODE = @ItemCode;

            -- Mandatory row-count check (§4.D) — VB6 had none.
            IF @@ROWCOUNT = 0
                RAISERROR('Amendment update matched no row — a line was changed by another user. Reload and retry.', 16, 1);

            -- Delivery schedule (§4.D): replace this line's slots wholesale.
            DELETE FROM PO_ORDL_DETL
            WHERE  divcode = @DivCode
              AND  ISNULL(pogrp, '') = ISNULL(@PoGrp, '')
              AND  pordno  = @PoNo
              AND  CAST(porddt AS DATE) = @PoDate
              AND  pordsno = @SNo
              AND  itemcode = @ItemCode;

            IF @SlotsJson IS NOT NULL AND LTRIM(RTRIM(@SlotsJson)) NOT IN ('', '[]')
                INSERT INTO PO_ORDL_DETL
                    (divcode, pordno, porddt, pordsno, pogrp, itemcode, shdate, Quantity)
                SELECT @DivCode, @PoNo, @PoDate, @SNo, @PoGrp, @ItemCode,
                       TRY_CAST(s.shDate AS DATE), ISNULL(s.qty, 0)
                FROM OPENJSON(@SlotsJson)
                WITH (shDate NVARCHAR(10) '$.shDate', qty NUMERIC(18,3) '$.qty') s
                WHERE ISNULL(s.qty, 0) > 0;

            -- E. PR backflush by DELTA, with the MANDATORY floor guard and the
            --    PRSNO filter (CD-NEW-01). Lines with no PR link skip cleanly.
            IF @LinePrNo IS NOT NULL AND @LinePrNo > 0
            BEGIN
                SET @Delta     = @Qty - @PrevQty;     -- server-computed (CD-AMD-05)
                SET @Shortfall = NULL;

                UPDATE PO_PRL
                SET    PRSTATUS  = 'O',
                       @Shortfall = ISNULL(QTYORD, 0) + @Delta,
                       QTYORD     = CASE WHEN ISNULL(QTYORD, 0) + @Delta < 0
                                         THEN 0
                                         ELSE ISNULL(QTYORD, 0) + @Delta END
                WHERE  PRNO     = @LinePrNo
                  AND  PRDATE   = @LinePrDate
                  AND  DIVCODE  = @DivCode
                  AND  ITEMCODE = @ItemCode
                  AND  PRSNO    = @LinePrSno;

                -- E2. Clamp logging — one WARN row ONLY when the floor actually fired.
                IF @Shortfall < 0
                    INSERT INTO LogDet_PO
                        (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                         Quantity, username, Trans_UserId, Trans_date,
                         Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo, Reason)
                    VALUES
                        (@DivCode, @PoNo, @PoDate, @LinePrNo, @LinePrDate, @LinePrSno, @ItemCode,
                         @Shortfall, @UserId, @UserId, GETUTCDATE(),
                         'Purchase Order Amendment', 'WARN',
                         ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1, @AmendReason);
            END

            -- F. Quotation refresh when the line carries one.
            IF @QuotNo IS NOT NULL AND @QuotNo > 0
                UPDATE PO_QUOTH
                SET    QSTATUS    = 'O',
                       NOOFORDERS = ISNULL(NOOFORDERS, 0) + 1
                WHERE  DIVCODE = @DivCode AND QUOTNO = @QuotNo;

            -- G. Audit row per line. Failure here ROLLS BACK (VB6 swallowed it).
            INSERT INTO LogDet_PO
                (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                 Quantity, rate, value, username, Trans_UserId, Trans_date,
                 Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo, Reason)
            VALUES
                (@DivCode, @PoNo, @PoDate, @LinePrNo, @LinePrDate, @LinePrSno, @ItemCode,
                 @Qty, @Rate, @Gross, @UserId, @UserId, GETUTCDATE(),
                 'Purchase Order Amendment', 'ADD',
                 ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1, @AmendReason);

            SET @RowId = (SELECT MIN(RowId) FROM @Lines WHERE RowId > @RowId);
        END

        ---------------------------------------------------------------------
        -- D (header). Amendable header fields + the new amendment pointer.
        ---------------------------------------------------------------------
        UPDATE PO_ORDH
        SET    CARCODE    = @Carrier,
               refno      = @RefNo,
               refDate    = @RefDate,
               PAYTERMS   = @PaymentTerms,
               CRDDAYS    = @CreditDays,
               BANK_CODE  = @BankCode,
               -- PAYMENT stores 'D'/'B', not the 'DIRECT'/'BANK' word @PayMode holds —
               -- same truncation risk as the flag columns below; same reverse-map fix.
               PAYMENT    = CASE WHEN UPPER(RTRIM(ISNULL(@PayMode,''))) = 'BANK' THEN 'B' ELSE 'D' END,
               DIRECT_INS = @DirectInstr,
               ADV_PER    = @AdvPer,
               ADV_AMT    = @AdvAmt,
               CHQNO      = @ChequeNo,
               CHQDT      = @ChequeDate,
               DEL_INS1   = @DelIns1,
               DEL_INS2   = @DelIns2,
               SPL_INS    = @SplIns,
               Duedate    = @DueDate,
               roff       = @RoundOff,
               -- Amendable header fields (13-Jul ruling: header follows VB6).
               -- Supplier + GSTIN + GST state are the ones this ruling unlocked; the
               -- GST ROUTE is re-derived from FA_SLMAS above, not from these columns.
               SLCODE         = @Supplier,
               cust_gstinno   = @Gstin,
               cust_gststcode = @GstState,
               INSPECT        = @Inspect,
               Form_type      = @FormType,
               CurrCode       = @Currency,
               FCurRate       = CASE WHEN @CurrRate > 0 THEN @CurrRate ELSE 1 END,
               REMARKS        = @HdrRemarks,
               FILENO         = @FileNo,
               DISPER         = @HdrDiscPer,
               PCKPER         = @HdrPackPer,
               INSPER         = @HdrInsurPer,
               FREIGHT        = @HdrFreightAmt,
               Pack_Amt       = @HdrPackAmt,
               Ins_Amt        = @HdrInsurAmt,
               ADDTAXPER      = @HdrAddTaxPer,
               -- Same class of defect as the line-level flags above: FRTFLG stores 'Y'/'N'
               -- (ksp_PO_SaveEntry's proven convention), disflg/PACK_FLG/FRT_FLG/Ins_Flg
               -- store 'B'/'A' — not the words @FreightType/@HdrDiscApp etc. hold.
               FRTFLG         = CASE WHEN UPPER(RTRIM(ISNULL(@FreightType,''))) = 'TOPAY' THEN 'Y' ELSE 'N' END,
               disflg         = CASE WHEN UPPER(RTRIM(ISNULL(@HdrDiscApp,'')))  = 'AFTER' THEN 'A' ELSE 'B' END,
               PACK_FLG       = CASE WHEN UPPER(RTRIM(ISNULL(@HdrPackApp,'')))  = 'AFTER' THEN 'A' ELSE 'B' END,
               FRT_FLG        = CASE WHEN UPPER(RTRIM(ISNULL(@HdrFrtPos,'')))   = 'AFTER' THEN 'A' ELSE 'B' END,
               Ins_Flg        = CASE WHEN UPPER(RTRIM(ISNULL(@HdrInsPos,'')))   = 'AFTER' THEN 'A' ELSE 'B' END,
               AMDORDNO   = @AmdNo,
               AMDORDDT   = @TransDate,
               -- Recompute the header order value from the amended lines.
               ORDVAL     = (SELECT ISNULL(SUM(ISNULL(LANDCOST, 0)), 0)
                             FROM   PO_ORDL
                             WHERE  DIVCODE = @DivCode
                               AND  ISNULL(POGRP, '') = ISNULL(@PoGrp, '')
                               AND  PORDNO  = @PoNo
                               AND  CAST(PORDDT AS DATE) = @PoDate) + @RoundOff
        WHERE  DIVCODE = @DivCode
          AND  ISNULL(POGRP, '') = ISNULL(@PoGrp, '')
          AND  PORDNO  = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate;

        IF @@ROWCOUNT = 0
            RAISERROR('Purchase Order header update matched no row.', 16, 1);

        ---------------------------------------------------------------------
        -- C. SNAPSHOT the AMENDED order into PO_AORDH / PO_AORDL.
        --    Taken AFTER the live update so the snapshot IS the amended state
        --    (FN §4C) and the column mapping is not duplicated.
        --    CD-AMD-01: cess_amt takes the cess AMOUNT (VB6 wrote CESS_PER here).
        --    CD-AMD-02: PRDATE takes the real PR date (VB6 wrote the quotation date).
        ---------------------------------------------------------------------
        INSERT INTO PO_AORDH
        (
            DIVCODE, PORDNO, PORDDT, POGRP, SLCODE, AMDORDNO, AMDORDDT,
            QUOTNO, QUOTDT, ORDVAL, ADV_PER, ADV_AMT, CARCODE,
            DEL_INS1, DEL_INS2, SPL_INS, DIRECT_INS, refordno, REFORDDT,
            CANFLG, CANDT, REMINDER, Tax_code, TaxPer, ADDTAX_CODE, ADDTAXPER,
            SURPER, disper, PCKPER, appby, approved, INSPECT, INSPER,
            FRTFLG, FREIGHT, PAYTERMS, CRDDAYS, PAYMENT, BANK_CODE, FILENO,
            roff, Cessper, Form_type, Ins_Amt, Pack_Amt, CHQNO, CHQDT,
            cust_gstinno, cust_gststcode
        )
        SELECT
            h.DIVCODE, h.PORDNO, h.PORDDT, h.POGRP, h.SLCODE, @AmdNo, @TransDate,
            h.QUOTNO, h.QUOTDT, h.ORDVAL, h.ADV_PER, h.ADV_AMT, h.CARCODE,
            h.DEL_INS1, h.DEL_INS2, h.SPL_INS, h.DIRECT_INS, h.refordno, h.REFORDDT,
            h.CANFLG, h.CANDT, h.REMINDER, h.Tax_code, h.TaxPer, h.ADDTAX_CODE, h.ADDTAXPER,
            h.SURPER, h.DISPER, h.PCKPER, h.appby, h.approved, h.INSPECT, h.INSPER,
            h.FRTFLG, h.FREIGHT, h.PAYTERMS, h.CRDDAYS, h.PAYMENT, h.BANK_CODE, h.FILENO,
            h.roff, h.Cessper, h.Form_type, h.Ins_Amt, h.Pack_Amt, h.CHQNO, h.CHQDT,
            h.cust_gstinno, h.cust_gststcode
        FROM   PO_ORDH h
        WHERE  h.DIVCODE = @DivCode
          AND  ISNULL(h.POGRP, '') = ISNULL(@PoGrp, '')
          AND  h.PORDNO  = @PoNo
          AND  CAST(h.PORDDT AS DATE) = @PoDate;

        INSERT INTO PO_AORDL
        (
            DIVCODE, PORDNO, PORDDT, PORDSNO, POGRP, AMDORDNO, AMDORDDT,
            ITEMCODE, QUOTNO, QUOTDT, UNIT, PRNO, PRDATE, PRSNO,
            Rate, ORDqty, ORDVAL, Weight, FRate, FValue,
            disper, disamt, PACKPER, Packamt, Frgt1per, Frgt1Amt,
            Ins_per, Ins_amt, OTHCHGS,
            cess_per, cess_amt,
            Tax_code, taxper, Taxamt, hsncode,
            cgstper, cgstamt, cgst_tax_code,
            sgstper, sgstamt, sgst_tax_code,
            igstper, igstamt, igst_tax_code,
            -- ⚠️ PO_AORDL names its TCS columns atcs_per / atcs_amt — NOT the
            -- Tcs_per / Tcs_amt used on PO_ORDL. The two tables genuinely differ;
            -- VB6 proves it (UpdateAmmendment writes RSAMDDET!atcs_per to PO_AORDL,
            -- while assigntodatabase writes RSDET1!Tcs_per to PO_ORDL).
            atcs_per, atcs_amt, ADDTAX_CODE, ADDTAXPER, ADDTAXAMT,
            LANDCOST, modvat, Remarks, ITEMMEMO, AmedReason
        )
        SELECT
            l.DIVCODE, l.PORDNO, l.PORDDT, l.PORDSNO, l.POGRP, @AmdNo, @TransDate,
            l.ITEMCODE, l.QUOTNO,
            -- CD-AMD-02 fix: blank quotation date → NULL (VB6 stored 0 = 1899-12-30).
            NULLIF(l.QUOTDT, '1899-12-30'),
            l.UNIT,
            l.PRNO,
            l.PRDATE,          -- CD-AMD-02: the REAL PR date, not the quotation date
            l.PRSNO,
            l.Rate, l.ORDqty, l.ORDVAL, l.Weight, l.FRate, l.FValue,
            l.disper, l.disamt, l.PACKPER, l.Packamt, l.Frgt1per, l.Frgt1Amt,
            l.Ins_per, l.Ins_amt, l.OTHCHGS,
            l.cess_per,
            l.cess_amt,        -- CD-AMD-01: the cess AMOUNT (VB6 copied CESS_PER here)
            l.Tax_code, l.taxper, l.Taxamt, l.hsncode,
            l.cgstper, l.cgstamt, l.cgst_tax_code,
            l.sgstper, l.sgstamt, l.sgst_tax_code,
            l.igstper, l.igstamt, l.igst_tax_code,
            l.Tcs_per, l.Tcs_amt, l.ADDTAX_CODE, l.ADDTAXPER, l.ADDTAXAMT,
            l.LANDCOST, l.modvat, l.Remarks, l.ITEMMEMO, l.AmedReason
        FROM   PO_ORDL l
        WHERE  l.DIVCODE = @DivCode
          AND  ISNULL(l.POGRP, '') = ISNULL(@PoGrp, '')
          AND  l.PORDNO  = @PoNo
          AND  CAST(l.PORDDT AS DATE) = @PoDate;

        COMMIT TRANSACTION;

        -- H. Scalar result — the repository reads this with ExecuteScalarAsync<int>.
        SELECT @AmdNo AS AmendNo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================
-- ksp_PO_DeleteOrder
-- Whole-PO cascade delete from the PO Amendment screen
-- (FN-PO-Amendment v1.2 §4 "Deletion").
--
--   1. Receipt guard — block if any GRN exists against this PO in its FY
--      (IN_TRNTAIL): "SDR already raised for this Purchase Order".
--   2. AUDIT BEFORE THE PHYSICAL DELETE (Sasi, 9-Jul). The FN's deletion spec
--      covers the PR reversal, the quotation release and the cascade, but does
--      NOT record WHAT was deleted. One LogDet_PO 'DELETE' row per line is written
--      FIRST — once PO_ORDL is gone the values are unrecoverable.
--   3. Reverse PO_PRL by SUBTRACTING the PO line qty, with the SAME floor guard
--      and WARN clamp logging as the amend backflush (§4E/E2).
--      CD-AMD-03: VB6's SQL-Server branch set QTYORD = NULL outright, wiping the
--      PR's ordered-qty history. We subtract and floor at zero.
--      CD-AMD-04: VB6's Oracle branch filtered on the LITERAL string 'divcode'.
--      CD-NEW-01: the PRSNO filter is mandatory.
--   4. Release the linked quotation (PO_QUOTH).
--   5. Cascade: PO_ORDL_DETL → PO_ORDL → PO_ORDH, with @@ROWCOUNT checks.
--
-- All in ONE transaction. No @Result output param — RAISERROR bubbles as a
-- SqlException → HTTP 400 (the PCF convention).
--
-- NEW SP (FN §5) — no legacy SP owns this name. Distinct from ksp_PO_DeletePO,
-- which serves the PR→PO Transfer screen (BR-03/BR-04, delete-reason payload).
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DeleteOrder
(
    @DivCode   VARCHAR(2),
    @PoNo      NUMERIC(10,0),
    @PoDate    DATE,
    @PoGrp     VARCHAR(20)  = NULL,
    @TransDate DATE,
    @UserId    VARCHAR(25),
    @HostName  VARCHAR(100) = NULL,
    @IpAddress VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1 FROM PO_ORDH
            WHERE DIVCODE = @DivCode AND PORDNO = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND (@PoGrp IS NULL OR ISNULL(POGRP, '') = ISNULL(@PoGrp, ''))
        )
            RAISERROR('Purchase Order not found for the given number and date.', 16, 1);

        -- 1. Receipt guard, FY-scoped (the same PORDNO can recur in a later FY).
        DECLARE @FyStart DATE = DATEFROMPARTS(
                    YEAR(@PoDate) - CASE WHEN MONTH(@PoDate) < 4 THEN 1 ELSE 0 END, 4, 1);
        DECLARE @FyEnd   DATE = DATEADD(DAY, -1, DATEADD(YEAR, 1, @FyStart));

        IF EXISTS (
            SELECT 1 FROM IN_TRNTAIL
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND DOCDT BETWEEN @FyStart AND @FyEnd
        )
            RAISERROR('SDR already raised for this Purchase Order — it cannot be deleted.', 16, 1);

        BEGIN TRANSACTION;

        -- 2. AUDIT FIRST — one DELETE row per line, while the values still exist.
        INSERT INTO LogDet_PO
            (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
             Quantity, rate, value, username, Trans_UserId, Trans_date,
             Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo)
        SELECT
            l.DIVCODE, l.PORDNO, l.PORDDT, l.PRNO, l.PRDATE, l.PRSNO, l.ITEMCODE,
            ISNULL(l.ORDqty, 0), ISNULL(l.Rate, 0), ISNULL(l.ORDVAL, 0),
            @UserId, @UserId, GETUTCDATE(),
            'Purchase Order Amendment Delete', 'DELETE',
            ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1
        FROM PO_ORDL l
        WHERE l.DIVCODE = @DivCode
          AND l.PORDNO  = @PoNo
          AND CAST(l.PORDDT AS DATE) = @PoDate
          AND (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''));

        -- 3. Reverse PO_PRL, line by line, with the mandatory floor guard.
        --    Looped (not set-based) so the clamp can be detected and logged per line.
        DECLARE @Lines TABLE (
            RowId    INT IDENTITY(1,1) PRIMARY KEY,
            ItemCode VARCHAR(10),
            PrNo     NUMERIC(6,0),
            PrDate   DATE,
            PrSno    NUMERIC(5,0),
            OrdQty   NUMERIC(18,3),
            QuotNo   NUMERIC(10,0)
        );

        INSERT INTO @Lines (ItemCode, PrNo, PrDate, PrSno, OrdQty, QuotNo)
        SELECT l.ITEMCODE, l.PRNO, l.PRDATE, l.PRSNO, ISNULL(l.ORDqty, 0), l.QUOTNO
        FROM   PO_ORDL l
        WHERE  l.DIVCODE = @DivCode
          AND  l.PORDNO  = @PoNo
          AND  CAST(l.PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''));

        DECLARE @RowId INT = (SELECT MIN(RowId) FROM @Lines);
        DECLARE @ItemCode VARCHAR(10), @PrNo NUMERIC(6,0), @PrDate DATE,
                @PrSno NUMERIC(5,0), @OrdQty NUMERIC(18,3), @QuotNo NUMERIC(10,0),
                @Shortfall NUMERIC(18,3);

        WHILE @RowId IS NOT NULL
        BEGIN
            SELECT @ItemCode = ItemCode, @PrNo = PrNo, @PrDate = PrDate,
                   @PrSno = PrSno, @OrdQty = OrdQty, @QuotNo = QuotNo
            FROM   @Lines WHERE RowId = @RowId;

            IF @PrNo IS NOT NULL AND @PrNo > 0
            BEGIN
                SET @Shortfall = NULL;

                -- CD-AMD-03: SUBTRACT (VB6 set QTYORD = NULL). Floor at zero.
                -- CD-NEW-01: PRSNO in the WHERE clause is mandatory.
                UPDATE PO_PRL
                SET    PRSTATUS   = '',
                       FClosed    = 'N',
                       @Shortfall = ISNULL(QTYORD, 0) - @OrdQty,
                       QTYORD     = CASE WHEN ISNULL(QTYORD, 0) - @OrdQty < 0
                                         THEN 0
                                         ELSE ISNULL(QTYORD, 0) - @OrdQty END
                WHERE  PRNO     = @PrNo
                  AND  PRDATE   = @PrDate
                  AND  DIVCODE  = @DivCode
                  AND  ITEMCODE = @ItemCode
                  AND  PRSNO    = @PrSno;

                -- WARN row only when the floor actually fired (§4E2 pattern).
                IF @Shortfall < 0
                    INSERT INTO LogDet_PO
                        (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                         Quantity, username, Trans_UserId, Trans_date,
                         Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo)
                    VALUES
                        (@DivCode, @PoNo, @PoDate, @PrNo, @PrDate, @PrSno, @ItemCode,
                         @Shortfall, @UserId, @UserId, GETUTCDATE(),
                         'Purchase Order Amendment Delete', 'WARN',
                         ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1);
            END

            -- 4. Release the quotation.
            IF @QuotNo IS NOT NULL AND @QuotNo > 0
                UPDATE PO_QUOTH
                SET    QSTATUS    = 'P',
                       NOOFORDERS = CASE WHEN ISNULL(NOOFORDERS, 0) - 1 < 0
                                         THEN 0
                                         ELSE ISNULL(NOOFORDERS, 0) - 1 END
                WHERE  DIVCODE = @DivCode AND QUOTNO = @QuotNo;

            SET @RowId = (SELECT MIN(RowId) FROM @Lines WHERE RowId > @RowId);
        END

        -- 5. Cascade delete, child → parent.
        DELETE FROM PO_ORDL_DETL
        WHERE  divcode = @DivCode AND pordno = @PoNo
          AND  CAST(porddt AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(pogrp, '') = ISNULL(@PoGrp, ''));

        DELETE FROM PO_ORDL
        WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(POGRP, '') = ISNULL(@PoGrp, ''));

        IF @@ROWCOUNT = 0
            RAISERROR('Purchase Order line delete matched no row.', 16, 1);

        DELETE FROM PO_ORDH
        WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(POGRP, '') = ISNULL(@PoGrp, ''));

        IF @@ROWCOUNT = 0
            RAISERROR('Purchase Order header delete matched no row.', 16, 1);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ============================================================
-- ksp_PO_DeleteLines
-- LINE-LEVEL delete from the PO Amendment screen
-- (FN-PO-Amendment v1.2 §4 "Deletion" — the non-cascade branch).
--
-- Same rules as ksp_PO_DeleteOrder, applied only to the listed lines, and the
-- PO_ORDH header is KEPT:
--   1. Receipt guard (IN_TRNTAIL, FY-scoped).
--   2. AUDIT BEFORE the physical delete (Sasi, 9-Jul) — one LogDet_PO 'DELETE'
--      row per line, written while the values still exist.
--   3. Reverse PO_PRL by SUBTRACTING the line qty, floor-guarded, with the
--      conditional WARN clamp row (CD-AMD-03 / CD-NEW-01).
--   4. Release the linked quotation.
--   5. Delete PO_ORDL_DETL → PO_ORDL for those lines, with @@ROWCOUNT checks.
--   6. Recompute PO_ORDH.ORDVAL from the surviving lines.
--
-- Deleting the LAST line of a PO is rejected: that is a whole-PO delete and must
-- go through ksp_PO_DeleteOrder, which also removes the header. Silently leaving
-- a headerless-but-lineless PO behind would be a worse outcome than an error.
--
-- NEW SP (FN §5) — no legacy SP owns this name.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DeleteLines
(
    @DivCode   VARCHAR(2),
    @PoNo      NUMERIC(10,0),
    @PoDate    DATE,
    @PoGrp     VARCHAR(20)  = NULL,
    @TransDate DATE,
    @UserId    VARCHAR(25),
    @HostName  VARCHAR(100) = NULL,
    @IpAddress VARCHAR(50)  = NULL,
    @LinesJson NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Parse the target line keys.
        DECLARE @Keys TABLE (
            RowId    INT IDENTITY(1,1) PRIMARY KEY,
            SNo      NUMERIC(5,0),
            ItemCode VARCHAR(10)
        );

        INSERT INTO @Keys (SNo, ItemCode)
        SELECT j.sNo, j.itemCode
        FROM OPENJSON(@LinesJson)
        WITH (
            sNo      NUMERIC(5,0) '$.sNo',
            itemCode VARCHAR(10)  '$.itemCode'
        ) j
        WHERE RTRIM(ISNULL(j.itemCode, '')) <> '';

        IF NOT EXISTS (SELECT 1 FROM @Keys)
            RAISERROR('Select at least one line to delete.', 16, 1);

        -- 1. Receipt guard, FY-scoped.
        DECLARE @FyStart DATE = DATEFROMPARTS(
                    YEAR(@PoDate) - CASE WHEN MONTH(@PoDate) < 4 THEN 1 ELSE 0 END, 4, 1);
        DECLARE @FyEnd   DATE = DATEADD(DAY, -1, DATEADD(YEAR, 1, @FyStart));

        IF EXISTS (
            SELECT 1 FROM IN_TRNTAIL
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND DOCDT BETWEEN @FyStart AND @FyEnd
        )
            RAISERROR('SDR already raised for this Purchase Order — its lines cannot be deleted.', 16, 1);

        -- Refuse to empty the PO via the line-delete path (see header note).
        DECLARE @TotalLines INT, @ToDelete INT;

        SELECT @TotalLines = COUNT(*)
        FROM   PO_ORDL l
        WHERE  l.DIVCODE = @DivCode AND l.PORDNO = @PoNo
          AND  CAST(l.PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''));

        SELECT @ToDelete = COUNT(*)
        FROM   PO_ORDL l
        INNER JOIN @Keys k ON k.SNo = l.PORDSNO AND k.ItemCode = l.ITEMCODE
        WHERE  l.DIVCODE = @DivCode AND l.PORDNO = @PoNo
          AND  CAST(l.PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''));

        IF @ToDelete = 0
            RAISERROR('No matching line was found to delete. Reload the Purchase Order and retry.', 16, 1);

        IF @ToDelete >= @TotalLines
            RAISERROR('Deleting every line would empty the Purchase Order — delete the whole order instead.', 16, 1);

        BEGIN TRANSACTION;

        -- 2. AUDIT FIRST, while the values still exist.
        INSERT INTO LogDet_PO
            (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
             Quantity, rate, value, username, Trans_UserId, Trans_date,
             Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo)
        SELECT
            l.DIVCODE, l.PORDNO, l.PORDDT, l.PRNO, l.PRDATE, l.PRSNO, l.ITEMCODE,
            ISNULL(l.ORDqty, 0), ISNULL(l.Rate, 0), ISNULL(l.ORDVAL, 0),
            @UserId, @UserId, GETUTCDATE(),
            'Purchase Order Amendment Line Delete', 'DELETE',
            ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1
        FROM PO_ORDL l
        INNER JOIN @Keys k ON k.SNo = l.PORDSNO AND k.ItemCode = l.ITEMCODE
        WHERE l.DIVCODE = @DivCode AND l.PORDNO = @PoNo
          AND CAST(l.PORDDT AS DATE) = @PoDate
          AND (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''));

        -- 3/4. Reverse PO_PRL (floor-guarded) and release the quotation, per line.
        DECLARE @Lines TABLE (
            RowId    INT IDENTITY(1,1) PRIMARY KEY,
            SNo      NUMERIC(5,0),
            ItemCode VARCHAR(10),
            PrNo     NUMERIC(6,0),
            PrDate   DATE,
            PrSno    NUMERIC(5,0),
            OrdQty   NUMERIC(18,3),
            QuotNo   NUMERIC(10,0)
        );

        INSERT INTO @Lines (SNo, ItemCode, PrNo, PrDate, PrSno, OrdQty, QuotNo)
        SELECT l.PORDSNO, l.ITEMCODE, l.PRNO, l.PRDATE, l.PRSNO,
               ISNULL(l.ORDqty, 0), l.QUOTNO
        FROM   PO_ORDL l
        INNER JOIN @Keys k ON k.SNo = l.PORDSNO AND k.ItemCode = l.ITEMCODE
        WHERE  l.DIVCODE = @DivCode AND l.PORDNO = @PoNo
          AND  CAST(l.PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''));

        DECLARE @RowId INT = (SELECT MIN(RowId) FROM @Lines);
        DECLARE @SNo NUMERIC(5,0), @ItemCode VARCHAR(10), @PrNo NUMERIC(6,0),
                @PrDate DATE, @PrSno NUMERIC(5,0), @OrdQty NUMERIC(18,3),
                @QuotNo NUMERIC(10,0), @Shortfall NUMERIC(18,3);

        WHILE @RowId IS NOT NULL
        BEGIN
            SELECT @SNo = SNo, @ItemCode = ItemCode, @PrNo = PrNo, @PrDate = PrDate,
                   @PrSno = PrSno, @OrdQty = OrdQty, @QuotNo = QuotNo
            FROM   @Lines WHERE RowId = @RowId;

            IF @PrNo IS NOT NULL AND @PrNo > 0
            BEGIN
                SET @Shortfall = NULL;

                UPDATE PO_PRL
                SET    PRSTATUS   = '',
                       FClosed    = 'N',
                       @Shortfall = ISNULL(QTYORD, 0) - @OrdQty,
                       QTYORD     = CASE WHEN ISNULL(QTYORD, 0) - @OrdQty < 0
                                         THEN 0
                                         ELSE ISNULL(QTYORD, 0) - @OrdQty END
                WHERE  PRNO     = @PrNo
                  AND  PRDATE   = @PrDate
                  AND  DIVCODE  = @DivCode
                  AND  ITEMCODE = @ItemCode
                  AND  PRSNO    = @PrSno;

                IF @Shortfall < 0
                    INSERT INTO LogDet_PO
                        (divcode, pordno, porddt, prno, prdate, prsno, itemcode,
                         Quantity, username, Trans_UserId, Trans_date,
                         Trans_Name, Trans_Mod, Trans_IPADD, Trans_Host, moduleNo)
                    VALUES
                        (@DivCode, @PoNo, @PoDate, @PrNo, @PrDate, @PrSno, @ItemCode,
                         @Shortfall, @UserId, @UserId, GETUTCDATE(),
                         'Purchase Order Amendment Line Delete', 'WARN',
                         ISNULL(@IpAddress, ''), ISNULL(@HostName, ''), 1);
            END

            IF @QuotNo IS NOT NULL AND @QuotNo > 0
                UPDATE PO_QUOTH
                SET    NOOFORDERS = CASE WHEN ISNULL(NOOFORDERS, 0) - 1 < 0
                                         THEN 0
                                         ELSE ISNULL(NOOFORDERS, 0) - 1 END
                WHERE  DIVCODE = @DivCode AND QUOTNO = @QuotNo;

            -- 5. Delete this line's schedule, then the line itself.
            DELETE FROM PO_ORDL_DETL
            WHERE  divcode = @DivCode AND pordno = @PoNo
              AND  CAST(porddt AS DATE) = @PoDate
              AND  pordsno = @SNo AND itemcode = @ItemCode
              AND  (@PoGrp IS NULL OR ISNULL(pogrp, '') = ISNULL(@PoGrp, ''));

            DELETE FROM PO_ORDL
            WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo
              AND  CAST(PORDDT AS DATE) = @PoDate
              AND  PORDSNO = @SNo AND ITEMCODE = @ItemCode
              AND  (@PoGrp IS NULL OR ISNULL(POGRP, '') = ISNULL(@PoGrp, ''));

            IF @@ROWCOUNT = 0
                RAISERROR('A line delete matched no row — it was changed by another user. Reload and retry.', 16, 1);

            SET @RowId = (SELECT MIN(RowId) FROM @Lines WHERE RowId > @RowId);
        END

        -- 6. Recompute the header order value from the SURVIVING lines.
        UPDATE PO_ORDH
        SET    ORDVAL = (SELECT ISNULL(SUM(ISNULL(LANDCOST, 0)), 0)
                         FROM   PO_ORDL
                         WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo
                           AND  CAST(PORDDT AS DATE) = @PoDate
                           AND  (@PoGrp IS NULL OR ISNULL(POGRP, '') = ISNULL(@PoGrp, '')))
                        + ISNULL(roff, 0)
        WHERE  DIVCODE = @DivCode AND PORDNO = @PoNo
          AND  CAST(PORDDT AS DATE) = @PoDate
          AND  (@PoGrp IS NULL OR ISNULL(POGRP, '') = ISNULL(@PoGrp, ''));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
