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
        p.divcode                            AS DivCode,
        p.user_id                            AS UserId,
        p.user_name                          AS UserName,
        p.alevel                             AS ALevel,
        RTRIM(ISNULL(d.DIVNAME, ''))         AS DivName
    FROM dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE p.divcode   = @DivCode
      AND p.user_name = @UserName
      AND dbo.DecryptString(p.password) = @Password
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
