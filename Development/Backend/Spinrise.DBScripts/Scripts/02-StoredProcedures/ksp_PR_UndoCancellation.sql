-- ============================================================
-- ksp_PR_UndoCancellation
-- Reverses a PR cancellation:
--   1. Reads pre_cancel_status from PO_PRH header
--      (BR-UNDO-01 — read BEFORE the transaction begins)
--   2. Clears all cancel columns on the header
--      (SP-I1: row_version guard — RAISERROR on conflict)
--   3. Restores PO_PRL PRSTATUS to the pre-cancel value
--   4. Writes audit log entry (Trans_Mod='DELETE')
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_UndoCancellation
(
    @DivCode    VARCHAR(2),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE,
    @DepCode    VARCHAR(3),
    @RowVersion BINARY(8),
    @UserId     VARCHAR(50),
    @HostName   VARCHAR(100) = NULL,
    @IpAddress  VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- BR-UNDO-01: Read pre_cancel_status before clearing it
    DECLARE @PreStatus VARCHAR(5);
    SELECT @PreStatus = ISNULL(pre_cancel_status, '')
    FROM PO_PRH
    WHERE divcode = @DivCode AND prno = @PrNo AND prdate = @PrDate;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Clear all cancel columns from the header
        UPDATE PO_PRH
        SET    cancelflag        = NULL,
               canceldt          = NULL,
               canreason         = NULL,
               pre_cancel_status = NULL
        WHERE  divcode     = @DivCode
          AND  prno        = @PrNo
          AND  prdate      = @PrDate
          AND  depcode     = @DepCode
          AND  row_version = @RowVersion;   -- SP-I1: concurrency guard

        IF @@ROWCOUNT = 0
            RAISERROR('Concurrent update conflict — record has changed. Please refresh and retry.', 16, 1);

        -- Step 2: Restore PR lines to pre-cancel status (BR-UNDO-01)
        UPDATE PO_PRL
        SET    PRSTATUS = CASE WHEN @PreStatus = '' THEN NULL ELSE @PreStatus END
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate;

        -- Step 3: Audit log — Trans_Mod='DELETE' for undo
        INSERT INTO LogDet_PO
            (divcode, prno, prdate, depcode,
             username, Trans_date, Trans_UserId,
             Trans_Name, Trans_Mod,
             Trans_IPADD, Trans_Host)
        VALUES
            (@DivCode, @PrNo, @PrDate, @DepCode,
             @UserId, GETDATE(), @UserId,
             'Purchase Requisition Undo Cancellation', 'DELETE',
             @IpAddress, @HostName);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
