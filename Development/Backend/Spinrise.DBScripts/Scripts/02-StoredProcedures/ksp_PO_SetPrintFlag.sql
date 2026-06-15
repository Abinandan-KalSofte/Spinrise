-- ============================================================
-- ksp_PO_SetPrintFlag
-- Sets poprintflg='Y' on PO_ORDH after a successful PDF print.
-- Called by Print action (FSD §3.18) only after PDF bytes generated.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SetPrintFlag
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.PO_ORDH
    SET    poprintflg = 'Y'
    WHERE  DIVCODE = @DivCode
      AND  PORDNO  = @PoNo
      AND  CAST(PORDDT AS DATE) = @PoDate;
END;
GO
