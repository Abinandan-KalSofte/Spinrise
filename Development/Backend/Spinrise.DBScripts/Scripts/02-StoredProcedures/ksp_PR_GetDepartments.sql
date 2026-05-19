-- ============================================================
-- ksp_PR_GetDepartments
-- Returns active departments for the given division.
-- Supports type-ahead search by code or name.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetDepartments
(
    @DivCode   VARCHAR(2),
    @Search    VARCHAR(50) = NULL   -- partial code or name; NULL = all
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(d.depcode)  AS DepCode,
        RTRIM(d.depname)  AS DepName
    FROM dbo.IN_DEP d
    WHERE d.divcode = @DivCode
      AND (
            @Search IS NULL
            OR d.depcode  LIKE '%' + @Search + '%'
            OR d.depname  LIKE '%' + @Search + '%'
          )
    ORDER BY d.depcode;
END;
GO
