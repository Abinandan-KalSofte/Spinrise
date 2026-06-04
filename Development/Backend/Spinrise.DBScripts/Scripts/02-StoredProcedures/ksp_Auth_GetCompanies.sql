-- ============================================================
-- SP: ksp_Auth_GetCompanies
-- Purpose: Populate Company dropdown on Login page
-- Source: PP_Compmas — confirmed columns: compcode, compname
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetCompanies
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(c.compcode) AS compCode,
        RTRIM(c.compname) AS compName
    FROM dbo.compmas c
    ORDER BY c.compcode;

END;
GO
