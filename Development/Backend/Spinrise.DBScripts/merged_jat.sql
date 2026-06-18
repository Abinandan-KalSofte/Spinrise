-- ============================================================
-- merged_jat.sql — M01 PO (PR → PO Transfer + PO Approval)
-- Database: JAT (172.16.16.52\sql2016)
-- Contains ALL ksp_PO_* stored procedures.
-- ============================================================
USE [JAT];
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
        RTRIM(ISNULL(u.user_name, h.createdby))                     AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
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
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason,
        ISNULL(l.disper,    0)                                      AS DiscPer,
        ISNULL(l.disamt,    0)                                      AS DiscAmt,
        ISNULL(l.PACKPER,   0)                                      AS PackingPer,
        ISNULL(l.Packamt,   0)                                      AS PackingAmt,
        ISNULL(l.Frgt1per,  0)                                      AS FreightPer,
        ISNULL(l.Frgt1Amt,  0)                                      AS FreightAmt,
        ISNULL(l.Ins_per,   0)                                      AS InsurancePer,
        ISNULL(l.Ins_amt,   0)                                      AS InsuranceAmt,
        ISNULL(l.cess_per,  0)                                      AS CessPer,
        ISNULL(l.cess_amt,  0)                                      AS CessAmt,
        RTRIM(ISNULL(l.ADDTAX_CODE, ''))                            AS AddTaxCode,
        ISNULL(l.ADDTAXPER, 0)                                      AS AddTaxPer,
        ISNULL(l.ADDTAXAMT, 0)                                      AS AddTaxAmt,
        ISNULL(l.FCACharg,  0)                                      AS FcaFob
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
        RTRIM(ISNULL(u.user_name, h.createdby))                     AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
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
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason,
        ISNULL(l.disper,    0)                                      AS DiscPer,
        ISNULL(l.disamt,    0)                                      AS DiscAmt,
        ISNULL(l.PACKPER,   0)                                      AS PackingPer,
        ISNULL(l.Packamt,   0)                                      AS PackingAmt,
        ISNULL(l.Frgt1per,  0)                                      AS FreightPer,
        ISNULL(l.Frgt1Amt,  0)                                      AS FreightAmt,
        ISNULL(l.Ins_per,   0)                                      AS InsurancePer,
        ISNULL(l.Ins_amt,   0)                                      AS InsuranceAmt,
        ISNULL(l.cess_per,  0)                                      AS CessPer,
        ISNULL(l.cess_amt,  0)                                      AS CessAmt,
        RTRIM(ISNULL(l.ADDTAX_CODE, ''))                            AS AddTaxCode,
        ISNULL(l.ADDTAXPER, 0)                                      AS AddTaxPer,
        ISNULL(l.ADDTAXAMT, 0)                                      AS AddTaxAmt,
        ISNULL(l.FCACharg,  0)                                      AS FcaFob
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
    @FreightPer       NUMERIC(10,2)  = 0,    -- CR-009: derives FreightAmt when FreightAmt=0
    @PackPer          NUMERIC(10,2)  = 0,
    @InsurPer         NUMERIC(10,2)  = 0,
    @SurchargePer     NUMERIC(10,2)  = 0,
    @AddTaxPer        NUMERIC(10,2)  = 0,
    @RoundOff         NUMERIC(13,2)  = 0,
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
            RTRIM(ISNULL(j.AddTaxCode, ''))  AS AddTaxCode,
            ISNULL(j.AddTaxPer,    0)        AS AddTaxPer,
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
            AddTaxCode    VARCHAR(10)    '$.addTaxCode',
            AddTaxPer     NUMERIC(10,2)  '$.addTaxPer',
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

        -- CR-009: Derive FreightAmt from FreightPer when FreightAmt not supplied.
        IF @FreightPer > 0 AND @FreightAmt = 0
            SET @FreightAmt = ROUND(@OrdVal * @FreightPer / 100.0, 2);

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
            ISNULL(@RoundOff, 0),     -- roff: client-supplied round-off
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
            reqidpo,  reqnamepo,
            disper,   disamt,
            PACKPER,  Packamt,
            Frgt1per, Frgt1Amt,
            Ins_per,  Ins_amt,
            cess_per, cess_amt,
            ADDTAX_CODE, ADDTAXPER, ADDTAXAMT,
            FCACharg
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
            NULLIF(l.RequesterName, ''),
            l.DiscPer,
            ROUND((l.Rate * l.Qty) * l.DiscPer      / 100.0, 2),
            l.PackingPer,
            ROUND((l.Rate * l.Qty) * l.PackingPer   / 100.0, 2),
            l.FreightPer,
            ROUND((l.Rate * l.Qty) * l.FreightPer   / 100.0, 2),
            l.InsurancePer,
            ROUND((l.Rate * l.Qty) * l.InsurancePer / 100.0, 2),
            l.CessPer,
            ROUND((l.Rate * l.Qty) * l.CessPer      / 100.0, 2),
            NULLIF(l.AddTaxCode, ''),
            l.AddTaxPer,
            ROUND((l.Rate * l.Qty) * l.AddTaxPer    / 100.0, 2),
            l.FcaFob
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
-- ksp_PO_SaveLPORateHistory  (SP #15)
-- Records LPO rate history in PO_LPORATEAPP after every Add save.
-- Always active — no activation flag (FSD §8.4 / §1368).
-- Called once per PO line from PoEntryRepository after ksp_PO_SaveEntry.
-- CDOCNO = MAX+1 per division (D-14: non-atomic; medium impact).
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

    -- CDOCNO = MAX+1 for this division (D-14: use SEQUENCE in future sprint)
    SELECT @NewCDocNo = ISNULL(MAX(CDOCNO), 0) + 1
    FROM dbo.PO_LPORATEAPP
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
               AND d2.PORDSNO = d.PORDSNO), 0)                      AS BalanceQty,
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
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetFirstApproval
(
    @DivCode    VARCHAR(2),
    @PoNo       NUMERIC(10,0),
    @PoDate     DATE,
    @UserId     VARCHAR(25),
    @UserName   VARCHAR(50)   = NULL,
    @IpAddress  VARCHAR(50)   = NULL,
    @HostName   VARCHAR(100)  = NULL,
    @Remarks    VARCHAR(25)   = NULL,
    @RowVersion BINARY(8)     = NULL,
    @Result     INT           OUTPUT
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

        UPDATE dbo.PO_ORDH
        SET FirstlevelApp = 'Y'
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
             @UserId, GETDATE(),
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
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetSecondApproval
(
    @DivCode    VARCHAR(2),
    @PoNo       NUMERIC(10,0),
    @PoDate     DATE,
    @UserId     VARCHAR(25),
    @UserName   VARCHAR(50)   = NULL,
    @IpAddress  VARCHAR(50)   = NULL,
    @HostName   VARCHAR(100)  = NULL,
    @Remarks    VARCHAR(25)   = NULL,
    @RowVersion BINARY(8)     = NULL,
    @Result     INT           OUTPUT
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

        UPDATE dbo.PO_ORDH
        SET SecondlevelApp = 'Y'
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
             @UserId, GETDATE(),
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
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetFinalApproval
(
    @DivCode    VARCHAR(2),
    @PoNo       NUMERIC(10,0),
    @PoDate     DATE,
    @UserId     VARCHAR(25),
    @UserName   VARCHAR(50)   = NULL,
    @IpAddress  VARCHAR(50)   = NULL,
    @HostName   VARCHAR(100)  = NULL,
    @Remarks    VARCHAR(25)   = NULL,
    @RowVersion BINARY(8)     = NULL,
    @Result     INT           OUTPUT
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

        UPDATE dbo.PO_ORDH
        SET Conflg = 'Y'
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
             @UserId, GETDATE(),
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
