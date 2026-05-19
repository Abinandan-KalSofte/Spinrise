CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetActiveDivisions
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RTRIM(d.DIVCODE) AS DivCode,
        RTRIM(d.DIVNAME) AS DivName
    FROM dbo.pp_divmas d
    ORDER BY d.DIVCODE;
END;
