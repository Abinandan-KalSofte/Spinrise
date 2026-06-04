CREATE OR ALTER PROCEDURE ksp_PR_GetDeptForUser
    @DivCode VARCHAR(2),
    @UserId  VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_IndentAppUser.UserID is varchar(6) — no PP_PASSWD join needed
    -- FY bounds computed server-side for PendingCount (April–March)
    DECLARE @YFDate DATETIME =
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()),     4, 1) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()) - 1, 4, 1) AS DATETIME) END;

    DECLARE @YLDate DATETIME =
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()) + 1, 3, 31) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()),     3, 31) AS DATETIME) END;

    SELECT DISTINCT
        d.DEPCODE AS DepCode,
        d.DEPNAME AS DepName,
        (
            SELECT COUNT(DISTINCT h.prno)
            FROM   PO_PRH h
            WHERE  h.divcode = @DivCode
              AND  h.depcode = d.DEPCODE
              AND  h.prdate BETWEEN @YFDate AND @YLDate
              AND  ISNULL(h.cancelflag, 'N') <> 'Y'
              AND  EXISTS (
                       SELECT 1 FROM PO_PRL l
                       WHERE  l.divcode   = h.divcode
                         AND  l.prno      = h.prno
                         AND  l.prdate    = h.prdate
                         AND  l.FirstApp  IS NULL
                         AND  l.SecondApp IS NULL
                         AND  l.ThirdApp  IS NULL
                         AND  l.DirectApp IS NULL
                         AND  ISNULL(l.FClosed, 'N') <> 'Y'
                   )
        ) AS PendingCount
    FROM PO_IndentAppUser u
    INNER JOIN IN_DEP d
        ON  d.DEPCODE = u.Depcode
        AND d.divcode = u.Divcode
    WHERE u.Divcode = @DivCode
      AND u.UserID  = @UserId
    ORDER BY d.DEPNAME;
END;
