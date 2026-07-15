-- ============================================================
-- ksp_PO_GetPayTerms
-- Returns all payment term codes and descriptions from Ig_PayTerm.
-- Used to populate the Payment Term dropdown on the PO Entry screen.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPayTerms
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(PayTerm_Code)               AS PayTermCode,
        RTRIM(ISNULL(PayTerm_Desc, ''))   AS PayTermDesc
    FROM dbo.Ig_PayTerm
    ORDER BY PayTerm_Code;
END;
GO
