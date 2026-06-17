-- ============================================================
-- ksp_PO_GetApprovalStatus  [SP #17]
-- Returns current PO approval flags for a given PO.
-- Scope: FirstlevelApp + SecondlevelApp + Conflg per FSD v1.1 §5.18
--        + PO_PARA flags so frontend knows which levels are required.
-- CEO task list: SP #17 (referred to as GetApprovalHistory — Sasi confirmed
--                name as GetApprovalStatus and scope as current flag return).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetApprovalStatus
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))   AS FirstLevelApp,
        RTRIM(ISNULL(h.SecondlevelApp, 'N'))  AS SecondLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))           AS Conflg,
        CAST(h.row_version AS BIGINT)          AS RowVersion,
        ISNULL(p.PoFirstLevelApp,   'N')       AS PoFirstLevelRequired,
        ISNULL(p.PoSecondLevelApp,  'N')       AS PoSecondLevelRequired,
        ISNULL(p.Po_Confirm,        'N')       AS PoConfirmRequired,
        RTRIM(ISNULL(h.poprintflg,  'N'))      AS PrintStatus,
        CAST(CASE WHEN ISNULL(h.CANFLG, '') <> '' THEN 1 ELSE 0 END AS BIT) AS Cancelled
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_PARA p
        ON p.divcode = h.DIVCODE
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;
END;
GO
