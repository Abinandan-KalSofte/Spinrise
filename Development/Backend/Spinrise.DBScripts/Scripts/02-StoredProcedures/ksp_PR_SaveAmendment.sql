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
--   amdflg = 'Y' set on PO_APRL snapshot lines and PATH B new PO_PRL inserts
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
        -- Update PO_PRH refno and ITYPE
        IF EXISTS (SELECT 1 FROM dbo.PO_PRH WHERE divcode=@DivCode AND prno=@PrNo AND CAST(prdate AS DATE)=@PrDate)
        BEGIN
            UPDATE dbo.PO_PRH
            SET    refno = NULLIF(RTRIM(ISNULL(@RefNo, '')), ''),
                   ITYPE = ISNULL(@IType, ITYPE)
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
               -- FirstApp, SecondApp, ThirdApp, PRSTATUS, DirectApp, amdflg preserved
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
