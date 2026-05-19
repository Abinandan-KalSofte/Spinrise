-- ============================================================
-- ksp_PR_GetPrTypes
-- Returns PR types from PO_INDENTTYPE.
-- ActiveOnly = 1 (Add/Modify mode): active types only.
-- ActiveOnly = 0 (View mode): all types (history display).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetPrTypes
(
    @ActiveOnly BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(t.ITYPE)  AS IType,
        RTRIM(t.IDESC)  AS IDesc
    FROM dbo.PO_INDENTTYPE t
    WHERE @ActiveOnly = 0
       OR ISNULL(t.active, 'Y') = 'Y'
    ORDER BY t.ITYPE;
END;
GO
