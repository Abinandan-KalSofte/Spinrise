-- ============================================================
-- ksp_PO_GetSuppliers
-- Returns supplier lookup for the Order Details tab (BR-12).
-- FA_SLMAS is company-wide (no divcode column).
-- Active filter: active = 'Y'.
-- GstStateName composed from gststatecode + state field.
-- ⚠ VERIFY: 'active' = 'Y' is the correct active supplier filter.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetSuppliers
(
    @DivCode VARCHAR(2),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(s.slcode)                                         AS SlCode,
        RTRIM(ISNULL(s.slname, ''))                             AS SlName,
        RTRIM(ISNULL(s.gstinno, ''))                            AS GstinNo,
        RTRIM(ISNULL(s.gststatecode, ''))                       AS GstStateCode,
        RTRIM(ISNULL(s.gststatecode, '')) +
            CASE WHEN RTRIM(ISNULL(s.state, '')) <> ''
                 THEN ' - ' + RTRIM(s.state)
                 ELSE '' END                                    AS GstStateName
    FROM dbo.FA_SLMAS s
    WHERE UPPER(ISNULL(s.active, 'Y')) = 'Y'
      AND (@Search IS NULL
           OR RTRIM(s.slcode) LIKE @Search + '%'
           OR RTRIM(s.slname) LIKE '%' + @Search + '%')
    ORDER BY s.slname;
END;
GO
