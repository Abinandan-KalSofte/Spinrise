USE master;
GO

CREATE OR ALTER PROCEDURE dbo.ksp_GetDatabases
AS
BEGIN
    SET NOCOUNT ON;

    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master','tempdb','msdb','model','ReportServer','ReportServerTempDB','pubs','Northwind')
    ORDER BY name;
END
GO
