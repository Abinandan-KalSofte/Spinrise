-- ============================================================
-- Spinrise ERP V2 — Merged Stored Procedures
-- Database: SpinRiseSaranya
-- Deploy: Execute this entire file in SSMS against SpinRiseSaranya
-- Rule: NEVER run individual SP files in production — use this file
-- ============================================================

USE JAT;
GO

-- ── Auth ─────────────────────────────────────────────────────
-- ksp_Auth_ValidateUser
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_ValidateUser
(
    @DivCode  VARCHAR(2),
    @UserName VARCHAR(100),
    @Password VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.divcode  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.divcode  = @DivCode
      AND p.user_name = @UserName
      AND dbo.DecryptString(p.password) = @Password
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
GO

-- ksp_Auth_GetActiveDivisions
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
GO

-- ksp_Auth_GetUserById
CREATE OR ALTER PROCEDURE dbo.ksp_Auth_GetUserById
(
    @UserId  VARCHAR(100),
    @DivCode VARCHAR(2)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.divcode  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.user_id  = @UserId
      AND p.divcode = @DivCode
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
GO
