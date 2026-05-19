CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetUserPermissions
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
            SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
            RETURN;
        END;

        SELECT TOP 1
            CAST(CASE WHEN UPPER(ISNULL(ADD_FLG, 'Y')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanAdd,
            CAST(CASE WHEN UPPER(ISNULL(MOD_FLG, 'Y')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanModify,
            CAST(CASE WHEN UPPER(ISNULL(DEL_FLG, 'Y')) = 'Y' THEN 1 ELSE 0 END AS INT) AS CanDelete
        FROM dbo.USERLEVEL
        WHERE RTRIM(DIVCODE) = RTRIM(@DivCode)
          AND MODULE          = 4
          AND ULEVEL          = @ULevel;

        IF @@ROWCOUNT = 0
            SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
    END TRY
    BEGIN CATCH
        SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
    END CATCH
END;
GO
