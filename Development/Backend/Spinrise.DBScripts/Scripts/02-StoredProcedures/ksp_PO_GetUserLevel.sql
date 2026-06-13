-- ============================================================
-- ksp_PO_GetUserLevel
-- Returns PO Entry permissions for the given user/division.
-- Deny-by-default (D-12): no USERLEVEL row → all false.
-- ⚠ VERIFY: MODULE = 5 for PO Entry — confirm in USERLEVEL table.
-- ⚠ VERIFY: PRINT_FLG column name — may be PRT_FLG or similar.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetUserLevel
(
    @UserId  VARCHAR(50),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @ULevel DECIMAL;

        SELECT @ULevel = alevel
        FROM dbo.PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(@UserId)
          AND RTRIM(divcode)  = RTRIM(@DivCode)
          AND UPPER(ISNULL(activeflg, 'N')) = 'Y';

        IF @ULevel IS NULL
        BEGIN
            SELECT 0 AS CanAdd, 0 AS CanDelete, 0 AS CanPrint;
            RETURN;
        END;

        SELECT TOP 1
            CAST(CASE WHEN UPPER(ISNULL(ADD_FLG,   'N')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanAdd,
            CAST(CASE WHEN UPPER(ISNULL(DEL_FLG,   'N')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanDelete,
            CAST(CASE WHEN UPPER(ISNULL(ADD_FLG,   'N')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanPrint  -- no separate PRINT_FLG; CanPrint = CanAdd
        FROM dbo.USERLEVEL
        WHERE RTRIM(DIVCODE) = RTRIM(@DivCode)
          AND MODULE          = 5   -- ⚠ VERIFY: 5 = PO Entry module number
          AND ULEVEL          = @ULevel;

        IF @@ROWCOUNT = 0
            SELECT 0 AS CanAdd, 0 AS CanDelete, 0 AS CanPrint;
    END TRY
    BEGIN CATCH
        SELECT 0 AS CanAdd, 0 AS CanDelete, 0 AS CanPrint;
    END CATCH
END;
GO
