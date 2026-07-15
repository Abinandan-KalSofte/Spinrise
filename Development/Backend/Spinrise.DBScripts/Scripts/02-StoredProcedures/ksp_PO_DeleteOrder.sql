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
