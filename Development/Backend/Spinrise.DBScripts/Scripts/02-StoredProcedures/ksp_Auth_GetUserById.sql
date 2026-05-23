CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetUserById
(
    @UserId  VARCHAR(100),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.divcode                        AS DivCode,
        p.user_id                        AS UserId,
        p.user_name                      AS UserName,
        p.alevel                         AS ALevel,
        RTRIM(ISNULL(d.DIVNAME, ''))     AS DivName
    FROM dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE p.user_id  = @UserId
      AND p.divcode  = @DivCode
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
