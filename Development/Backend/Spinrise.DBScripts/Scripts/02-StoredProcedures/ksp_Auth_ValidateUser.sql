CREATE OR ALTER PROCEDURE dbo.ksp_Auth_ValidateUser
(
    @DivCode  VARCHAR(2),
    @UserName VARCHAR(100),
    @Password VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- A user can have multiple PP_PASSWD rows (one per module).
    -- TOP 1 anchors divcode/user_id/alevel; the subquery aggregates ALL active modules.
    SELECT TOP 1
        p.divcode                            AS DivCode,
        p.user_id                            AS UserId,
        p.user_name                          AS UserName,
        p.alevel                             AS ALevel,
        ISNULL(
            STUFF(
                (SELECT ',' + CAST(p2.module AS VARCHAR(10))
                 FROM   dbo.PP_PASSWD p2
                 WHERE  p2.user_id  = p.user_id
                   AND  p2.divcode  = p.divcode
                   AND  UPPER(ISNULL(p2.activeflg, 'N')) = 'Y'
                 ORDER BY p2.module
                 FOR XML PATH('')),
                1, 1, ''),
            '')                              AS Modules,
        RTRIM(ISNULL(d.DIVNAME, ''))         AS DivName
    FROM   dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE  p.divcode   = @DivCode
      AND  p.user_name = @UserName
      AND  dbo.DecryptString(p.password) = @Password
      AND  UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
