-- ============================================================
-- ksp_PO_SetFinalApproval
-- Sets PO_ORDH.Conflg = 'Y' (Final Confirmation) for the given PO.
-- Prerequisites:
--   - FirstlevelApp = 'Y' (always required)
--   - SecondlevelApp = 'Y' if PO_PARA.PoSecondLevelApp = 'Y'
-- Optimistic concurrency guard via row_version (CD-08 FSD v3.1).
-- Inserts audit row into LogDet_PO (§7 column set, FSD v1.1).
-- Returns @Result OUTPUT: 0=success, 2=prerequisites not met,
--   3=concurrency conflict, 4=not found.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetFinalApproval
(
    @DivCode    VARCHAR(2),
    @PoNo       NUMERIC(10,0),
    @PoDate     DATE,
    @UserId     VARCHAR(25),
    @UserName   VARCHAR(50)   = NULL,
    @IpAddress  VARCHAR(50)   = NULL,
    @HostName   VARCHAR(100)  = NULL,
    @Remarks    VARCHAR(25)   = NULL,
    @RowVersion BINARY(8)     = NULL,
    @Result     INT           OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Result = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @PoSecondLevelApp CHAR(1);
        SELECT @PoSecondLevelApp = ISNULL(PoSecondLevelApp, 'N')
        FROM dbo.PO_PARA
        WHERE divcode = @DivCode;

        -- Prerequisite: first-level must be approved
        IF NOT EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(FirstlevelApp, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @Result = 2;
            RAISERROR('PO first-level approval is not complete.', 16, 1);
            RETURN;
        END

        -- Prerequisite: second-level must be approved (when required)
        IF @PoSecondLevelApp = 'Y'
           AND NOT EXISTS (
               SELECT 1 FROM dbo.PO_ORDH
               WHERE DIVCODE = @DivCode
                 AND PORDNO  = @PoNo
                 AND CAST(PORDDT AS DATE) = @PoDate
                 AND RTRIM(ISNULL(SecondlevelApp, 'N')) = 'Y'
           )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @Result = 2;
            RAISERROR('PO second-level approval is not complete.', 16, 1);
            RETURN;
        END

        -- Guard: must not already be confirmed
        IF EXISTS (
            SELECT 1 FROM dbo.PO_ORDH
            WHERE DIVCODE = @DivCode
              AND PORDNO  = @PoNo
              AND CAST(PORDDT AS DATE) = @PoDate
              AND RTRIM(ISNULL(Conflg, 'N')) = 'Y'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('PO is already confirmed.', 16, 1);
            RETURN;
        END

        UPDATE dbo.PO_ORDH
        SET Conflg = 'Y'
        WHERE DIVCODE = @DivCode
          AND PORDNO  = @PoNo
          AND CAST(PORDDT AS DATE) = @PoDate
          AND (@RowVersion IS NULL OR row_version = @RowVersion);

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            IF EXISTS (
                SELECT 1 FROM dbo.PO_ORDH
                WHERE DIVCODE = @DivCode
                  AND PORDNO  = @PoNo
                  AND CAST(PORDDT AS DATE) = @PoDate
            )
                SET @Result = 3; -- concurrency conflict
            ELSE
                SET @Result = 4; -- record not found
            RETURN;
        END

        -- Audit insert into LogDet_PO (§7 column set — lowercase convention)
        INSERT INTO dbo.LogDet_PO
            (divcode, pordno, porddt,
             Trans_Name, Trans_Mod,
             Trans_UserId, Trans_date,
             Trans_IPADD, Trans_Host,
             moduleNo, Reason)
        VALUES
            (@DivCode, @PoNo, @PoDate,
             'PO_FinalLevel', 'M01',
             @UserId, GETDATE(),
             ISNULL(@IpAddress, ''), ISNULL(@HostName, ''),
             1, LEFT(ISNULL(@Remarks, ''), 25));

        COMMIT TRANSACTION;
        SET @Result = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
