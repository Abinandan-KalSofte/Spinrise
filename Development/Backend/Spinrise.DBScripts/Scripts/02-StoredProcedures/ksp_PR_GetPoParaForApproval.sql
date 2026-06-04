CREATE OR ALTER PROCEDURE ksp_PR_GetPoParaForApproval
    @DivCode VARCHAR(2)
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_PARA columns: divcode varchar(2), APPUSERLEVEL1 numeric(5,0),
    --   AppUserLevel2 numeric(5,0), AppUserLevel3 numeric(5,0),
    --   AppUserLabel1 varchar(35), AppUserLabel2 varchar(35), AppUserLabel3 varchar(35)
    SELECT TOP 1
        divcode         AS DivCode,
        APPUSERLEVEL1   AS AppUserLevel1,
        AppUserLevel2   AS AppUserLevel2,
        AppUserLevel3   AS AppUserLevel3,
        AppUserLabel1   AS AppUserLabel1,
        AppUserLabel2   AS AppUserLabel2,
        AppUserLabel3   AS AppUserLabel3,
        -- Financial year bounds computed server-side (April–March)
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()),     4, 1) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()) - 1, 4, 1) AS DATETIME)
        END AS YFDate,
        CASE WHEN MONTH(GETDATE()) >= 4
             THEN CAST(DATEFROMPARTS(YEAR(GETDATE()) + 1, 3, 31) AS DATETIME)
             ELSE CAST(DATEFROMPARTS(YEAR(GETDATE()),     3, 31) AS DATETIME)
        END AS YLDate
    FROM PO_PARA
    WHERE divcode = @DivCode;
END;
