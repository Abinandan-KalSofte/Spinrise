-- ============================================================
-- ksp_PO_GetCarriers
-- Returns carrier lookup for the Instructions tab.
-- Table: PO_CAR (confirmed JAT schema).
-- Columns: CARCODE, CARNAME, active.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetCarriers
(
    @Search VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(c.CARCODE)              AS CarCode,
        RTRIM(ISNULL(c.CARNAME, '')) AS CarName
    FROM dbo.PO_CAR c
    WHERE UPPER(ISNULL(c.active, 'Y')) = 'Y'
      AND (@Search IS NULL
           OR RTRIM(c.CARCODE) LIKE @Search + '%'
           OR RTRIM(c.CARNAME) LIKE '%' + @Search + '%')
    ORDER BY c.CARNAME;
END;
GO
