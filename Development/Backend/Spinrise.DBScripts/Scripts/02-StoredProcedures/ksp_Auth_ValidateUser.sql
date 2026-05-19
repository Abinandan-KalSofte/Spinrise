CREATE OR ALTER PROCEDURE dbo.ksp_Auth_ValidateUser
(
    @DivCode  VARCHAR(2),
    @UserName VARCHAR(100),
    @Password VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.divcode   AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.divcode  = @DivCode
      AND p.user_name = @UserName
      AND dbo.DecryptString(p.password) = @Password
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
