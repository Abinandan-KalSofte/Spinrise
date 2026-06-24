-- ============================================================
-- ksp_PO_GetPOList
-- Paginated PO search for the Find modal and nav-index build.
-- Returns: divCode, poNo, poDate, orderType, supplier,
--          supplierName, orderValue, approvalStatus, totalLines.
-- Excludes cancelled POs. Ordered newest first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOList
(
    @DivCode   VARCHAR(2),
    @FDate     DATE,
    @LDate     DATE,
    @Search    VARCHAR(100) = NULL,
    @Supplier  VARCHAR(10)  = NULL,
    @Page      INT          = 1,
    @PageSize  INT          = 50
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS Supplier,
        RTRIM(ISNULL(sl.slname, ''))                                AS SupplierName,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        -- TC-07: reflect L1 approval state in list view too
        CASE
            WHEN ISNULL(h.Conflg,        'N') = 'Y' THEN 'CONFIRMED'
            WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y' THEN 'PENDING L1'
            ELSE                                          'PENDING'
        END AS ApprovalStatus,
        (
            SELECT COUNT(*) FROM dbo.PO_ORDL l
            WHERE l.DIVCODE = h.DIVCODE
              AND l.PORDNO  = h.PORDNO
              AND CAST(l.PORDDT AS DATE) = CAST(h.PORDDT AS DATE)
        )                                                           AS TotalLines
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.FA_SLMAS sl ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    WHERE h.DIVCODE = @DivCode
      AND CAST(h.PORDDT AS DATE) BETWEEN @FDate AND @LDate
      AND ISNULL(h.CANFLG, '') = ''
      AND (
            @Search IS NULL OR @Search = ''
            OR CAST(h.PORDNO AS VARCHAR(20)) LIKE '%' + @Search + '%'
            OR RTRIM(ISNULL(h.SLCODE,  '')) LIKE '%' + @Search + '%'
            OR RTRIM(ISNULL(sl.slname, '')) LIKE '%' + @Search + '%'
          )
      AND (@Supplier IS NULL OR @Supplier = '' OR RTRIM(h.SLCODE) = RTRIM(@Supplier))
    ORDER BY h.PORDDT DESC, h.PORDNO DESC
    OFFSET (@Page - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
