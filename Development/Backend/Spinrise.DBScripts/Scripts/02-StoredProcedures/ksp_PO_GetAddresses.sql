-- ============================================================
-- ksp_PO_GetAddresses
-- Returns delivery or billing address lookup (Instructions tab).
-- @Kind = 'delivery' or 'billing'
-- ⚠ VERIFY: address lookup table name and column names.
--   Possible tables: PO_ADDMAS, FA_ADDMAS, IN_ADDRESS.
-- ⚠ VERIFY: KIND column/filter logic — how delivery vs billing is distinguished.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAddresses
(
    @DivCode VARCHAR(2),
    @Kind    VARCHAR(20),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(a.ADDCODE) AS Code,   -- ⚠ VERIFY: column name ADDCODE
        RTRIM(a.ADDNAME) AS Name    -- ⚠ VERIFY: column name ADDNAME
    FROM dbo.PO_ADDMAS a            -- ⚠ VERIFY: table name PO_ADDMAS
    WHERE RTRIM(ISNULL(a.divcode, '')) = @DivCode
      AND UPPER(RTRIM(ISNULL(a.ADDTYPE, ''))) = UPPER(@Kind)  -- ⚠ VERIFY: KIND column ADDTYPE
      AND (@Search IS NULL
           OR RTRIM(a.ADDCODE) LIKE @Search + '%'
           OR RTRIM(a.ADDNAME) LIKE '%' + @Search + '%')
    ORDER BY a.ADDNAME;
END;
GO
