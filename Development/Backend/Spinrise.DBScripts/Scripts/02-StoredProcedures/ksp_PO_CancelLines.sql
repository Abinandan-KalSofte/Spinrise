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
