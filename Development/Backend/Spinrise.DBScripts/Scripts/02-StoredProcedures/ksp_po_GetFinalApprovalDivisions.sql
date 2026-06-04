-- ============================================================
-- SP: ksp_po_GetFinalApprovalDivisions
-- Purpose: Division dropdown for Final Level PR Approval filter bar
-- Source: pp_divmas — confirmed columns: DIVCODE, DIVNAME (from ksp_Auth_GetActiveDivisions)
-- NOTE: pp_divmas has no company/dbname filter column — returns all active divisions.
--       Division filtering by company is handled at the app layer if required.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_GetFinalApprovalDivisions]
    @DbName varchar(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(d.DIVCODE) AS divcode,
        RTRIM(d.DIVNAME) AS divisionName,
        RTRIM(d.DIVCODE) AS abbr        -- DIVCODE used as abbreviation (no separate abbr column)
    FROM dbo.pp_divmas d
    ORDER BY d.DIVCODE;

END;
GO
