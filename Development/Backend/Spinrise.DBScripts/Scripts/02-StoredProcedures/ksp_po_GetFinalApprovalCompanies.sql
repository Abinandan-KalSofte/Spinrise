-- ============================================================
-- SP: ksp_po_GetFinalApprovalCompanies
-- Purpose: Company dropdown for Final Level PR Approval filter bar
-- Source: pp_database — confirmed columns: Database_No, Database_Name
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_GetFinalApprovalCompanies]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.Database_Name AS dbname,        -- used as the filter key passed to main SP
        d.Database_Name AS companyName    -- display label in Company dropdown
    FROM dbo.pp_database d
    ORDER BY d.Database_No;

END;
GO
