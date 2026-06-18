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

        -- ── 3. BR-01: Backdate check (FSD §4.6) ─────────────────────────────────
        -- When BACKDATE='N', PO date must strictly equal the system processing date.
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
