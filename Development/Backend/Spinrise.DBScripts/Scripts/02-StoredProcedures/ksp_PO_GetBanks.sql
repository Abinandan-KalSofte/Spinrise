-- ============================================================
-- ksp_PO_GetBanks
-- Returns bank lookup for the Payment tab (BR-15).
-- ⚠ VERIFY: table name FA_BANKMAS and column names BANKCODE, BANKNAME.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetBanks
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(b.BANKCODE) AS BankCode,  -- ⚠ VERIFY: column name BANKCODE
        RTRIM(b.BANKNAME) AS BankName   -- ⚠ VERIFY: column name BANKNAME
    FROM dbo.FA_BANKMAS b               -- ⚠ VERIFY: table name FA_BANKMAS
    WHERE @Search IS NULL
       OR RTRIM(b.BANKCODE) LIKE @Search + '%'
       OR RTRIM(b.BANKNAME) LIKE '%' + @Search + '%'
    ORDER BY b.BANKNAME;
END;
GO
