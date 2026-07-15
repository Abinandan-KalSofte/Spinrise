-- ============================================================
-- ksp_PO_GetAddresses
-- Returns delivery or billing address lookup (Instructions tab).
-- @Kind = 'DELIVERY' → in_deladd | 'BILLING' → in_billadd
-- Source: indenttopo.frm L12877 / L12899
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetAddresses
(
    @DivCode VARCHAR(2),
    @Kind    VARCHAR(20),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF UPPER(@Kind) = 'DELIVERY'
    BEGIN
        SELECT
            RTRIM(a.slcode) AS Code,
            RTRIM(a.slname) AS Name
        FROM dbo.in_deladd a
        WHERE RTRIM(a.divcode) = @DivCode
          AND ISNULL(a.Active, 'N') = 'Y'
          AND (@Search IS NULL
               OR RTRIM(a.slcode) LIKE @Search + '%'
               OR RTRIM(a.slname) LIKE '%' + @Search + '%')
        ORDER BY a.slname;
    END
    ELSE IF UPPER(@Kind) = 'BILLING'
    BEGIN
        SELECT
            RTRIM(a.slcode) AS Code,
            RTRIM(a.slname) AS Name
        FROM dbo.in_billadd a
        WHERE RTRIM(a.divcode) = @DivCode
          AND ISNULL(a.Active, 'N') = 'Y'
          AND (@Search IS NULL
               OR RTRIM(a.slcode) LIKE @Search + '%'
               OR RTRIM(a.slname) LIKE '%' + @Search + '%')
        ORDER BY a.slname;
    END
END;
GO
