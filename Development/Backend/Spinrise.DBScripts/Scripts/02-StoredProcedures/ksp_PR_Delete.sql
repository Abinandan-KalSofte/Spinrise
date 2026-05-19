-- ============================================================
-- ksp_PR_Delete
-- Two modes per FSD Section 5.7:
--   FullDelete:  deletes entire PR (header + all lines).
--   LineDelete:  deletes a single line by prsno; reassigns
--                remaining line serial numbers from 1.
-- Guard: only unapproved, non-cancelled, non-amended PRs.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_Delete
(
    @DivCode      VARCHAR(2),
    @PrNo         NUMERIC(6,0),
    @PrDate       DATE,
    @DeleteMode   VARCHAR(10),   -- 'FULL' or 'LINE'
    @PrSno        NUMERIC(5,0)  = NULL,  -- required for LINE mode
    @UserId       VARCHAR(50),
    @DeleteReason VARCHAR(100)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Guard: PR must be unapproved, not cancelled, not amended
        IF NOT EXISTS (
            SELECT 1 FROM dbo.PO_PRH
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate
              AND ISNULL(APPFLG,     'N') <> 'Y'
              AND ISNULL(cancelflag, '')   = ''
              AND ISNULL(amendno,     0)   = 0
        )
        BEGIN
            RAISERROR('PR cannot be deleted: it is approved, cancelled, or amended.', 16, 1);
            RETURN;
        END

        IF @DeleteMode = 'FULL'
        BEGIN
            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate;

            DELETE FROM dbo.PO_PRH
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate;
        END
        ELSE IF @DeleteMode = 'LINE'
        BEGIN
            IF @PrSno IS NULL
            BEGIN
                RAISERROR('PrSno is required for LINE delete mode.', 16, 1);
                RETURN;
            END

            -- Record delete reason on the line before removing
            UPDATE dbo.PO_PRL
            SET deletereason = @DeleteReason
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate
              AND prsno   = @PrSno;

            DELETE FROM dbo.PO_PRL
            WHERE divcode = @DivCode
              AND prno    = @PrNo
              AND CAST(prdate AS DATE) = @PrDate
              AND prsno   = @PrSno;

            -- Reassign prsno from 1 for remaining lines
            WITH ranked AS (
                SELECT prsno,
                       ROW_NUMBER() OVER (ORDER BY prsno) AS NewSno
                FROM dbo.PO_PRL
                WHERE divcode = @DivCode
                  AND prno    = @PrNo
                  AND CAST(prdate AS DATE) = @PrDate
            )
            UPDATE l
            SET l.prsno = r.NewSno
            FROM dbo.PO_PRL l
            INNER JOIN ranked r
                ON r.prsno = l.prsno
               AND l.divcode = @DivCode
               AND l.prno    = @PrNo
               AND CAST(l.prdate AS DATE) = @PrDate;
        END

        COMMIT TRANSACTION;

        SELECT 1 AS Success;

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
