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
