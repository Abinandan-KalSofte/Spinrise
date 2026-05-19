CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetUserPermissions
(
    @UserId  VARCHAR(50),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT TOP 1
            CAST(ISNULL(ADD_FLG, 1) AS INT) AS CanAdd,
            CAST(ISNULL(MOD_FLG, 1) AS INT) AS CanModify,
            CAST(ISNULL(DEL_FLG, 1) AS INT) AS CanDelete
        FROM dbo.USERLEVEL
        WHERE RTRIM(userid)  = RTRIM(@UserId)
          AND RTRIM(divcode) = RTRIM(@DivCode)
          AND sno = 4;

        IF @@ROWCOUNT = 0
            SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
    END TRY
    BEGIN CATCH
        SELECT 1 AS CanAdd, 1 AS CanModify, 1 AS CanDelete;
    END CATCH
END;
GO
