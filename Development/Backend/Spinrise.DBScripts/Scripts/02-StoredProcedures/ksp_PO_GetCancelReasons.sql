-- ============================================================
-- ksp_PO_GetCancelReasons
-- Reason dropdown for the PO Cancellation screen (FN-PO-Cancellation v1.4 §2 col 14-15).
-- Returns the Cancel Reason setup rows aliased to the FE wire contract
-- (CancellationReason { code, name }).
-- NEW SP (FN §5) — no existing legacy SP owns this name (G4).
-- ⚠️ Deploy gated on LT-01 (G2): PO_CANCELREASON table + Code/Reason column
--    names are presumed legacy but unverified from the repo. Confirm on live
--    JAT/SCMTS DDL before running against production.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetCancelReasons
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  RTRIM(Code)   AS Code,
            RTRIM(Reason)  AS Name
    FROM    PO_CANCELREASON
    ORDER BY Reason;
END;
GO
