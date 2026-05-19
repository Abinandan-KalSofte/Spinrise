-- ============================================================
-- ksp_PR_GetEmployees
-- Returns employees for requester lookup.
-- EmpCommon = 'Y': company-wide (no divcode filter).
-- EmpCommon = 'N': division-filtered.
-- Supports type-ahead search by employee number or name.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetEmployees
(
    @DivCode    VARCHAR(2),
    @EmpCommon  CHAR(1)     = 'N',
    @Search     VARCHAR(50) = NULL   -- partial empno or name; NULL = all
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(e.empno AS VARCHAR(10)) AS EmpNo,
        RTRIM(e.ename)               AS EmpName
    FROM dbo.PR_EMP e
    WHERE (
            @EmpCommon = 'Y'
            OR e.divcode = @DivCode
          )
      AND (
            @Search IS NULL
            OR CAST(e.empno AS VARCHAR(10)) LIKE '%' + @Search + '%'
            OR e.ename                      LIKE '%' + @Search + '%'
          )
    ORDER BY e.ename;
END;
GO
