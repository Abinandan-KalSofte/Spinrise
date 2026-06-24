CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetUserById
(
    @UserId  VARCHAR(100),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        p.divcode                        AS DivCode,
        p.user_id                        AS UserId,
        p.user_name                      AS UserName,
        p.alevel                         AS ALevel,
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
            '')                          AS Modules,
        RTRIM(ISNULL(d.DIVNAME, ''))     AS DivName
    FROM   dbo.PP_PASSWD p
    LEFT JOIN dbo.PP_DIVMAS d ON d.DIVCODE = p.divcode
    WHERE  p.user_id  = @UserId
      AND  p.divcode  = @DivCode
      AND  UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
