-- ============================================================
-- ksp_PR_GetMachineLookup
-- Returns machines for the given division + department where MACFLAG='M'.
-- FSD Section 3 Col 13 / Section 4.3 / Section 5.2:
--   Machine No validates against MM_MACMAS (DIVCODE + DEPCODE + MACFLAG='M').
--   Auto-fills: Machine Description (DESCRIPTION), Machine Model (MODEL).
-- Supports type-ahead search by MAC_NO or DESCRIPTION.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetMachineLookup
(
    @DivCode   VARCHAR(2),
    @DepCode   VARCHAR(10),
    @Search    VARCHAR(50) = NULL   -- partial MAC_NO or DESCRIPTION; NULL = all
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(m.MAC_NO)      AS MacNo,
        RTRIM(m.DESCRIPTION) AS MacDesc,
        RTRIM(m.MODEL)       AS MacModel
    FROM dbo.MM_MACMAS m
    WHERE m.DIVCODE = @DivCode
      AND m.DEPCODE = @DepCode
      AND m.MACFLAG = 'M'
      AND ISNULL(m.IsActive, 'Y') = 'Y'
      AND (
            @Search IS NULL
            OR m.MAC_NO      LIKE '%' + @Search + '%'
            OR m.DESCRIPTION LIKE '%' + @Search + '%'
          )
    ORDER BY m.MAC_NO;
END;
GO
