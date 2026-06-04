-- ============================================================
-- usp_GetNextAmendNo
-- Generates next amendment number atomically.
-- SERIALIZABLE isolation + UPDLOCK + HOLDLOCK prevents race
-- condition on concurrent amendment entry.
-- Number derived from MAX(amendno)+1 in PO_APRH for the FY.
-- SP name CONFIRMED by Sasi (Stage 2, 23-May-2026).
-- FSD: M01 PR Amendment Entry v2.3 | AF-04
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[usp_GetNextAmendNo]
    @DivCode    VARCHAR(10),
    @FDate      DATE,
    @LDate      DATE,
    @NewDocNo   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        SELECT @NewDocNo = ISNULL(MAX(amendno), 0) + 1
        FROM   dbo.PO_APRH WITH (UPDLOCK, HOLDLOCK)
        WHERE  divcode  = @DivCode
          AND  CAST(amenddate AS DATE) BETWEEN @FDate AND @LDate;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @NewDocNo = -1;
        THROW;
    END CATCH
END;
GO
