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
