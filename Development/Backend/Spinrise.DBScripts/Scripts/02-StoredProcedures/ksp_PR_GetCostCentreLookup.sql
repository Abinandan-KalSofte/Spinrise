-- ============================================================
-- ksp_PR_GetCostCentreLookup
-- Returns cost centres for the given division from IN_CC.
-- FSD Section 3 Col 11 / Section 4.3:
--   Cost Centre Code validates against IN_CC for division.
--   Lookup opens IN_CC listing for division.
-- Supports type-ahead search by cccode or ccname.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetCostCentreLookup
(
    @DivCode   VARCHAR(2),
    @Search    VARCHAR(50) = NULL   -- partial cccode or ccname; NULL = all
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.cccode          AS CcCode,
        RTRIM(c.ccname)   AS CcName
    FROM dbo.IN_CC c
    WHERE c.divcode = @DivCode
      AND (
            @Search IS NULL
            OR CAST(c.cccode AS VARCHAR(10)) LIKE '%' + @Search + '%'
            OR c.ccname LIKE '%' + @Search + '%'
          )
    ORDER BY c.cccode;
END;
GO
