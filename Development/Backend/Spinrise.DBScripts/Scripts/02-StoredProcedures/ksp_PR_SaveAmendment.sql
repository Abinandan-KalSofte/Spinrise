-- ============================================================
-- ksp_PR_SaveAmendment
-- FSD: M01 PR Amendment Entry v2.3  §4 Save Sequence
-- CR:  CR-M01-AM-001 — QA/CEO approved 31-May-2026 (T. Mani)
-- Business logic: PR_Amendment_Form.md (Mariyaiya) — implemented 02-Jun-2026
--
-- ADD:         INSERT PO_APRH + PO_APRL snapshot; UPDATE PO_PRH (refno);
--              delta-update PO_PRL — PATH A (UPDATE) / PATH B (INSERT) / PATH C (DELETE)
-- MODIFY:      UPDATE PO_APRH header, DELETE + re-INSERT PO_APRL, audit.
-- DELETE:      Dependency check; DELETE PO_APRL + PO_APRH, audit.
-- DELETE_LINE: Single-line DELETE from PO_APRL (deltype=2), dependency check, audit.
--
-- Business rules enforced:
--   BR-AMD-01: AmendDate must equal @PDate (processing date)
--   BR-AMD-03: PR eligibility checked in ksp_PR_GetAmendmentForNew
--   BR-AMD-04: Duplicate item codes rejected
--   Qty < ordered qty rejected on ADD
--   Required Date < pdate rejected on ADD
--   PATH C: guard PRSTATUS NOT IN ('O','E','C','Z','X')
--   PATH A: row_version concurrency per line; approval flags preserved
--   PATH B: MAX(prsno)+1 with UPDLOCK
--   DELETE/DELETE_LINE: PO_PRL dependency check (qtyord > 0 or status ordered/enquired)
--   amdflg = 'Y' set on PO_APRL snapshot lines and PATH B new PO_PRL inserts
--   No DELETE of PO_PRH or PO_PRL
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_SaveAmendment]
    @Mode               VARCHAR(15),        -- 'ADD' | 'MODIFY' | 'DELETE' | 'DELETE_LINE'
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
    @PrSno              INT             = NULL  -- used by DELETE_LINE mode only
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. FY Guard ──────────────────────────────────────────────────────
        IF @AmendDate < @FDate OR @AmendDate > @LDate
            RAISERROR('Amendment Date is outside the open financial year.', 16, 1);

        -- ── 2. BR-AMD-01: Amendment Date must equal processing date (ADD/MODIFY only) ──
        IF @Mode IN ('ADD', 'MODIFY') AND @AmendDate <> @PDate
            RAISERROR('Amendment Date must equal the current processing date.', 16, 1);

        -- ── 3. BR-AMD-04: Duplicate item codes ───────────────────────────────
        IF @Mode IN ('ADD', 'MODIFY') AND @LinesJson IS NOT NULL
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
        IF @Mode NOT IN ('DELETE', 'DELETE_LINE') AND @LinesJson IS NOT NULL
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

        -- ── 5. Concurrency check (MODIFY / DELETE / DELETE_LINE) ─────────────
        IF @Mode IN ('MODIFY', 'DELETE', 'DELETE_LINE')
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

        -- ── 6. Resolve AmendNo ────────────────────────────────────────────────
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

        -- ── 7. DELETE path ────────────────────────────────────────────────────
        IF @Mode = 'DELETE'
        BEGIN
            -- Dependency check: block if any PRL line has been ordered or enquired
            IF EXISTS (
                SELECT 1 FROM dbo.PO_PRL
                WHERE  divcode              = @DivCode
                  AND  prno                 = @PrNo
                  AND  CAST(prdate AS DATE) = @PrDate
                  AND  (ISNULL(qtyord, 0) > 0 OR ISNULL(prstatus, '') IN ('O', 'E', 'C'))
            )
                RAISERROR('Cannot delete amendment — one or more PR lines have been ordered or enquired.', 16, 1);

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

        -- ── 8. DELETE_LINE path (deltype=2 — single line from amendment) ──────
        IF @Mode = 'DELETE_LINE'
        BEGIN
            IF @PrSno IS NULL
                RAISERROR('PrSno is required for DELETE_LINE mode.', 16, 1);

            -- Cannot delete last line
            IF (SELECT COUNT(*) FROM dbo.PO_APRL
                WHERE divcode = @DivCode AND prno = @PrNo
                  AND CAST(prdate AS DATE) = @PrDate AND amendno = @ResolvedAmendNo) <= 1
                RAISERROR('Cannot delete the last line of an amendment.', 16, 1);

            -- Dependency check: block if the corresponding PO_PRL line is protected
            IF EXISTS (
                SELECT 1 FROM dbo.PO_PRL
                WHERE  divcode              = @DivCode
                  AND  prno                 = @PrNo
                  AND  CAST(prdate AS DATE) = @PrDate
                  AND  prsno                = @PrSno
                  AND  ISNULL(prstatus, '') IN ('O', 'E', 'C', 'Z', 'X')
            )
                RAISERROR('Line %d cannot be deleted — its status is beyond amendment scope.', 16, 1, @PrSno);

            DELETE FROM dbo.PO_APRL
            WHERE  divcode              = @DivCode
              AND  prno                 = @PrNo
              AND  CAST(prdate AS DATE) = @PrDate
              AND  amendno              = @ResolvedAmendNo
              AND  prsno                = @PrSno;

            INSERT INTO dbo.LogDet_po
                (divcode, prno, prdate, prsno, itemcode,
                 Trans_Name, Trans_Mod, Trans_Host, Trans_IPADD,
                 Trans_UserId, Trans_date, moduleNo)
            VALUES
                (@DivCode, @PrNo, @PrDate, @PrSno, '',
                 'PR Amendment', 'DELETE_LINE', @HostName, @IpAddress,
                 @UserId, GETDATE(), 4);

            COMMIT TRANSACTION;
            SELECT @ResolvedAmendNo AS AmendNo;
            RETURN;
        END

        -- ── 9. ADD: capture current header fields from PO_PRH ─────────────────
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
                -- Legacy fallback: PO_PRH absent (pre-CR save) — read from latest PO_APRH
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

        -- ── 10. ADD: insert amendment header snapshot ─────────────────────────
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

        -- ── 11. MODIFY: update amendment header ───────────────────────────────
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

        -- ── 12. Insert amendment lines snapshot (ADD and MODIFY) ─────────────
        --        amdflg = 'Y' flags all snapshot lines (BR from markdown §9)
        INSERT INTO dbo.PO_APRL
            (divcode, prno, prdate, amendno, amenddate, prsno,
             itemcode, macno, qtyind, reqddate, RATE,
             RATE_SOURCE, RATE_JUSTIFICATION,
             curstock, CCCODE, CATCODE, BGRPCODE,
             PLACE, APPCOST, remarks, amdflg)
        SELECT
            @DivCode,
            @PrNo,
            @PrDate,
            @ResolvedAmendNo,
            @AmendDate,
            j.PrSno,
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

        -- ── 13. ADD: delta-update PO_PRH and PO_PRL (CR-M01-AM-001) ──────────
        IF @Mode = 'ADD'
        BEGIN
            -- Update PO_PRH refno
            IF EXISTS (SELECT 1 FROM dbo.PO_PRH WHERE divcode=@DivCode AND prno=@PrNo AND CAST(prdate AS DATE)=@PrDate)
            BEGIN
                UPDATE dbo.PO_PRH
                SET    refno = NULLIF(RTRIM(ISNULL(@RefNo, '')), '')
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
                RowVersion        CHAR(18)
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
                j.RowVersion
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
                RowVersion         CHAR(18)        '$.RowVersion'
            ) j
            WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

            -- Required Date ≥ pdate validation
            IF EXISTS (
                SELECT 1 FROM @LineWork
                WHERE  ReqdDate IS NOT NULL
                  AND  TRY_CONVERT(DATE, NULLIF(ReqdDate, '')) < @PDate
            )
                RAISERROR('Required Date cannot be earlier than the current processing date.', 16, 1);

            -- Qty < ordered qty validation (cannot reduce below already-approved quantity)
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

            -- PATH C guard: RAISERROR before DELETE if any removed line has a protected status
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

            -- amdflg NOT set here — only PATH B (new inserts) gets amdflg = 'Y'
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
                AND p.row_version          = CONVERT(VARBINARY(8), lw.RowVersion, 1);

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
        END

        -- ── 14. Audit log ──────────────────────────────────────────────────────
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
