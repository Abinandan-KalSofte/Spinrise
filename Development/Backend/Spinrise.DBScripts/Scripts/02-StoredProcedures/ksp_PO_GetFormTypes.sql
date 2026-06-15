-- ============================================================
-- ksp_PO_GetFormTypes
-- Returns form type lookup for the Order Details tab.
-- Table: PO_FormType (confirmed JAT schema).
-- Columns: TypeCode → FormCode, Description → FormName, active.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetFormTypes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(f.TypeCode)                  AS FormCode,
        RTRIM(ISNULL(f.Description, ''))   AS FormName
    FROM dbo.PO_FormType f
    WHERE UPPER(ISNULL(f.active, 'Y')) = 'Y'
    ORDER BY f.TypeCode;
END;
GO
