-- ============================================================
-- ksp_PO_GetOrderTypes
-- Returns purchase order type lookup.
-- PO_TYPE columns: TYPE_CODE, TYPNAME, active (varchar)
-- ⚠ VERIFY: MODULE = 5 for PO Entry (confirm in USERLEVEL data).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetOrderTypes
(
    @ActiveOnly INT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.TYPE_CODE) AS PoGrp,
        RTRIM(t.TYPNAME)   AS TypName
    FROM dbo.PO_TYPE t
    WHERE @ActiveOnly = 0
       OR UPPER(ISNULL(t.active, 'Y')) = 'Y'
    ORDER BY t.TYPE_CODE;
END;
GO
