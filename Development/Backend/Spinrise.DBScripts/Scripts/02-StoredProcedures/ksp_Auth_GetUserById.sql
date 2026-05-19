CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetUserById
(
    @UserId  VARCHAR(100),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.div_code  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.user_id  = @UserId
      AND p.div_code = @DivCode
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
