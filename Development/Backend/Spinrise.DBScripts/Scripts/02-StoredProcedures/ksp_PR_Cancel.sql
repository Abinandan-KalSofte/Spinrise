-- ============================================================
-- ksp_PR_Cancel
-- Cancels a PR:
--   1. Captures current line PRSTATUS as pre_cancel_status
--      (BR-UNDO-01 — read BEFORE the transaction begins)
--   2. Sets cancelflag='Y', stores cancel reason and pre-status
--      on the PR header
--   3. Sets PRSTATUS='X' on all PR lines
--   4. Writes audit log entry (Trans_Mod='ADD')
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_Cancel
(
    @DivCode      VARCHAR(2),
    @PrNo         NUMERIC(6,0),
    @PrDate       DATE,
    @DepCode      VARCHAR(3),
    @CancelReason VARCHAR(200),
    @UserId       VARCHAR(50),
    @HostName     VARCHAR(100) = NULL,
    @IpAddress    VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- BR-UNDO-01: Capture pre_cancel_status before the transaction
    DECLARE @PreStatus VARCHAR(5);
    SELECT TOP 1 @PreStatus = ISNULL(PRSTATUS, '')
    FROM PO_PRL
    WHERE divcode = @DivCode AND prno = @PrNo AND prdate = @PrDate
    ORDER BY prsno;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Update PR header with cancellation details
        UPDATE PO_PRH
        SET    cancelflag        = 'Y',
               canceldt          = GETDATE(),
               canreason         = UPPER(@CancelReason),
               pre_cancel_status = @PreStatus
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate
          AND  depcode = @DepCode;

        -- Step 2: Mark all PR lines as cancelled
        UPDATE PO_PRL
        SET    PRSTATUS = 'X'
        WHERE  divcode = @DivCode
          AND  prno    = @PrNo
          AND  prdate  = @PrDate;

        -- Step 3: Audit log
        INSERT INTO LogDet_PO
            (divcode, prno, prdate, depcode,
             username, Trans_date, Trans_UserId,
             Trans_Name, Trans_Mod,
             Trans_IPADD, Trans_Host)
        VALUES
            (@DivCode, @PrNo, @PrDate, @DepCode,
             @UserId, GETDATE(), @UserId,
             'Purchase Requisition Cancellation', 'ADD',
             @IpAddress, @HostName);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
