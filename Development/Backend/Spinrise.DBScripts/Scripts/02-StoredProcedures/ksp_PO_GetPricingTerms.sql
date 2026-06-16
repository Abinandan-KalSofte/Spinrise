-- ============================================================
-- ksp_PO_GetPricingTerms
-- Returns pricing terms lookup for PO Instructions tab.
-- Source: indenttopo.frm L12344
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPricingTerms
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.SCode) AS Code,
        RTRIM(t.SName) AS Name
    FROM dbo.Ex_ShipTerm t
    WHERE (@Search IS NULL
           OR RTRIM(t.SCode) LIKE @Search + '%'
           OR RTRIM(t.SName) LIKE '%' + @Search + '%')
    ORDER BY t.SCode;
END;
GO
