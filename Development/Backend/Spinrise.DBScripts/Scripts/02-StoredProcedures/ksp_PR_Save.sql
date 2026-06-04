-- ============================================================
-- ksp_PR_Save
-- Saves a PR (Add or Modify).
-- Add:    generates PR number, inserts header + lines + audit.
-- Modify: deletes all lines, reinserts, updates header.
-- Returns: new PrNo on success.
-- NOTE: Requires database compatibility level >= 130 for OPENJSON.
--       Run if needed: ALTER DATABASE JAT SET COMPATIBILITY_LEVEL = 130;
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_Save
(
    -- Operation
    @Mode           VARCHAR(6),     -- 'ADD' or 'MODIFY'

    -- Header
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

    -- Modify only — existing PR being edited
    @ExistingPrNo   NUMERIC(6,0)    = NULL,
    @ExistingPrDate DATE            = NULL,

    -- Lines JSON (parsed inside SP via OPENJSON)
    -- Each element: {"ItemCode","MacNo","QtyInd","ReqdDate","Rate","LpoRate","LpoDate","LpoFrom",
    --                "CurStock","CcCode","CatCode","BgrpCode","AppCost","Remarks","Sample"}
    @LinesJson      NVARCHAR(MAX),

    -- Financial year boundaries for doc number generation
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

        -- ── 0. Validate min / max order level per line ────────────────────────
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

        -- ── 1. Generate or retain PR number ───────────────────────────────
        DECLARE @PrNo NUMERIC(6,0);

        IF @Mode = 'ADD'
        BEGIN
            -- PO_DOC_PARA only has TC and STDOCNO columns
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

        -- ── 2. Header insert / update ──────────────────────────────────────
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

            -- Delete all lines (delete-and-reinsert per legacy business rule)
            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate;
        END

        -- ── 3. Insert lines ────────────────────────────────────────────────
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
            @DivCode,
            @PrNo,
            @PrDate,
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
            ItemCode            VARCHAR(10)     '$.ItemCode',
            MacNo               VARCHAR(5)      '$.MacNo',
            QtyInd              NUMERIC(12,3)   '$.QtyInd',
            ReqdDate            DATE            '$.ReqdDate',
            Rate                NUMERIC(13,4)   '$.Rate',
            LpoRate             NUMERIC(13,4)   '$.LpoRate',
            LpoDate             DATE            '$.LpoDate',
            LpoFrom             VARCHAR(40)     '$.LpoFrom',
            CurStock            NUMERIC(12,3)   '$.CurStock',
            CcCode              NUMERIC(4,0)    '$.CcCode',
            CatCode             VARCHAR(1)      '$.CatCode',
            BgrpCode            VARCHAR(4)      '$.BgrpCode',
            AppCost             NUMERIC(11,2)   '$.AppCost',
            Remarks             VARCHAR(100)    '$.Remarks',
            Sample              CHAR(1)         '$.Sample'
        ) j
        WHERE RTRIM(ISNULL(j.ItemCode, '')) <> '';

        -- ── 4. Audit log (LogDet_po) ───────────────────────────────────────
        DECLARE @SrSno INT = 1;
        DECLARE @LogItemCode VARCHAR(10), @LogMacNo VARCHAR(5),
                @LogQty NUMERIC(15,0), @LogRate NUMERIC(13,4);

        DECLARE audit_cur CURSOR FAST_FORWARD FOR
            SELECT itemcode, macno,
                   CAST(qtyind AS NUMERIC(15,0)),
                   RATE
            FROM dbo.PO_PRL
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate
            ORDER BY prsno;

        OPEN audit_cur;
        FETCH NEXT FROM audit_cur INTO
            @LogItemCode, @LogMacNo, @LogQty, @LogRate;

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
            FETCH NEXT FROM audit_cur INTO
                @LogItemCode, @LogMacNo, @LogQty, @LogRate;
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
