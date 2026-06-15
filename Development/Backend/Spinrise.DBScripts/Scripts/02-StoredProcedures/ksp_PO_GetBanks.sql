-- ============================================================
-- ksp_PO_GetBanks
-- Returns active bank list for the Payment tab (BR-15).
-- Table: pr_Bank (confirmed 15-Jun-2026)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetBanks
(
    @DivCode VARCHAR(2),
    @Search  VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(b.Bank_Code) AS BankCode,
        RTRIM(b.bank_Name) AS BankName
    FROM dbo.pr_Bank b
    WHERE b.Active = 'Y'
      AND b.Divcode = @DivCode
      AND (
            @Search IS NULL OR @Search = ''
            OR b.Bank_Code LIKE '%' + @Search + '%'
            OR b.bank_Name LIKE '%' + @Search + '%'
          )
    ORDER BY b.bank_Name;
END;
GO
