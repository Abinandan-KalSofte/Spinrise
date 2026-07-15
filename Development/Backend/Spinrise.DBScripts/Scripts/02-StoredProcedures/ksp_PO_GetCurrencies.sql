-- ============================================================
-- ksp_PO_GetCurrencies
-- Returns active currency list with latest conversion rate.
-- Source: indenttopo.frm L12975; rate from PO_ConvFactT L12962
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetCurrencies
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(c.currcode) AS CurrCode,
        RTRIM(c.currname) AS CurrName,
        ISNULL((
            SELECT TOP 1 r.ConvFact
            FROM dbo.PO_ConvFactT r
            WHERE r.CurrCode = c.currcode
            ORDER BY r.FromDate DESC
        ), 0) AS CurrRate
    FROM dbo.FA_CURRENCY c
    WHERE ISNULL(c.Active, 'N') = 'Y'
      AND (@Search IS NULL
           OR RTRIM(c.currcode) LIKE @Search + '%'
           OR RTRIM(c.currname) LIKE '%' + @Search + '%')
    ORDER BY c.currcode;
END;
GO
