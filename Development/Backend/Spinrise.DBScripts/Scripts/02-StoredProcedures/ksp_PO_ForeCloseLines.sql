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
