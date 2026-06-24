-- ============================================================
-- ksp_PO_DeletePO
-- Deletes a PO (FULL mode for PR→PO Transfer screen).
-- Flow:
--   1. BR-03: GRN guard — blocks delete if GRN raised (IN_TRNTAIL).
--      RAISERROR contains "GRN" — C# catches this and returns HTTP 409.
--   2. BR-04: All line delete reasons must be non-empty.
--   3. Write audit row to LogDet_PO.
--   4. Reverse QTYORD on PO_PRL (restore PR balance).
--   5. Reset PRSTATUS → '' and FClosed → 'N' on PO_PRL so PR lines reappear in picker (POT-LC-01).
--   6. Cascade delete: PO_ORDL_DETL → PO_ORDL → PO_ORDH.
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

    -- TC-06: block deletion if PO has been approved at any configured level.
    -- L1 check is skipped when PO_PARA.PoFirstLevelApp = 'N' for this division.
    -- SecondlevelApp and Conflg are always enforced regardless of PO_PARA setting.
    DECLARE @UseL1 CHAR(1) = 'N';
    SELECT @UseL1 = ISNULL(PoFirstLevelApp, 'N')
    FROM dbo.PO_PARA
    WHERE divcode = @DivCode;

    IF EXISTS (
        SELECT 1 FROM dbo.PO_ORDH
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND (   (@UseL1 = 'Y' AND RTRIM(ISNULL(FirstlevelApp,  'N')) = 'Y')
               OR RTRIM(ISNULL(SecondlevelApp, 'N')) = 'Y'
               OR RTRIM(ISNULL(Conflg,         'N')) = 'Y')
    )
    BEGIN
        RAISERROR('Cannot delete an approved Purchase Order.', 16, 1);
        RETURN;
    END

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

        -- POT-LC-01 / CD-NEW-01: Restore PR line visibility after PO delete.
        -- Reset PRSTATUS 'O' → '' so line passes the NOT IN ('O',...) filter in GetPRLines.
        -- Reset FClosed 'Y' → 'N' for fully-ordered lines (set by SaveEntry on full order).
        -- No FClosed='Y' guard — partial-order lines also carry PRSTATUS='O' before SaveEntry fix,
        -- so reset all affected lines unconditionally.
        UPDATE prl
        SET    prl.FClosed  = 'N',
               prl.PRSTATUS = CASE WHEN prl.PRSTATUS = 'O' THEN '' ELSE prl.PRSTATUS END
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
