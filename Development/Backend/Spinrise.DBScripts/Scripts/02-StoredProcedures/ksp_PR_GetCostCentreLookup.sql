-- ============================================================
-- ksp_PR_GetCostCentreLookup
-- Returns Sub Cost Centres for the given division from In_Scc.
-- Only active records (Active = 'Y') are returned.
-- Supports type-ahead search by SCCCODE or SCCNAME.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetCostCentreLookup
(
    @DivCode   VARCHAR(2),
    @Search    VARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SCCCODE           AS CcCode,
        RTRIM(s.SCCNAME)    AS CcName
    FROM dbo.In_Scc s
    WHERE s.Divcode = @DivCode
      AND ISNULL(s.Active, '') = 'Y'
      AND (
            @Search IS NULL
            OR CAST(s.SCCCODE AS VARCHAR(10)) LIKE '%' + @Search + '%'
            OR s.SCCNAME LIKE '%' + @Search + '%'
          )
    ORDER BY s.SCCCODE;
END;
GO
