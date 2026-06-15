-- ============================================================
-- ksp_PO_GetGSTRouting
-- Server-decides LOCAL vs IGST by comparing division state vs
-- supplier GST state code (§3.10: pp_divmas vs fa_slmas).
-- ⚠ VERIFY: pp_divmas column gststatecode — may differ.
-- ⚠ VERIFY: FA_SLMAS column for GST state code.
-- ⚠ VERIFY: table name pp_divmas — may be PO_DIVMAS or similar.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetGSTRouting
(
    @DivCode VARCHAR(2),
    @SlCode  VARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DivStateCode  VARCHAR(10) = '';
    DECLARE @SupStateCode  VARCHAR(10) = '';

    SELECT TOP 1 @DivStateCode = RTRIM(ISNULL(d.gststatecode, ''))  -- ⚠ VERIFY: column gststatecode on pp_divmas
    FROM dbo.pp_divmas d                                              -- ⚠ VERIFY: table name pp_divmas
    WHERE RTRIM(d.divcode) = RTRIM(@DivCode);

    SELECT TOP 1 @SupStateCode = RTRIM(ISNULL(s.gststatecode, ''))  -- ⚠ VERIFY: column gststatecode on FA_SLMAS
    FROM dbo.FA_SLMAS s
    WHERE RTRIM(s.SLCODE) = RTRIM(@SlCode);

    SELECT
        CASE WHEN @DivStateCode = @SupStateCode AND @DivStateCode <> '' THEN 'LOCAL' ELSE 'IGST' END AS Route,
        @DivStateCode AS DivStateCode,
        @SupStateCode AS SupStateCode;
END;
GO
