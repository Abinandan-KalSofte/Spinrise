-- ============================================================
-- ksp_PO_GetGstTaxCodes
-- Returns GST tax code lookup for the GST modal (BR-09).
-- Only active codes returned (TAXSTATUS = 'Y').
-- IG_TAX columns: TAX_CODE, DESCRIPTION, ST_PER, TAXSTATUS.
-- CGST/SGST = ST_PER / 2 (intra-state split); IGST = ST_PER (inter-state).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetGstTaxCodes
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.TAX_CODE)                    AS TaxCode,
        RTRIM(ISNULL(t.DESCRIPTION, ''))     AS TaxDesc,
        ROUND(ISNULL(t.ST_PER, 0) / 2, 2)   AS CgstPer,
        ROUND(ISNULL(t.ST_PER, 0) / 2, 2)   AS SgstPer,
        ISNULL(t.ST_PER, 0)                  AS IgstPer,
        ISNULL(t.TAXSTATUS, 'Y')             AS TaxStatus
    FROM dbo.IG_TAX t
    WHERE UPPER(ISNULL(t.TAXSTATUS, 'Y')) = 'Y'
      AND (@Search IS NULL
           OR RTRIM(t.TAX_CODE)    LIKE @Search + '%'
           OR RTRIM(t.DESCRIPTION) LIKE '%' + @Search + '%')
    ORDER BY t.TAX_CODE;
END;
GO
