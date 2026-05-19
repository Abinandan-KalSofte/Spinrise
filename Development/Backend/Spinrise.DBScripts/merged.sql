-- ============================================================
-- Spinrise ERP V2 — Merged Stored Procedures
-- Database: SpinRiseSaranya
-- Deploy: Execute this entire file in SSMS against SpinRiseSaranya
-- Rule: NEVER run individual SP files in production — use this file
-- ============================================================

USE SpinRiseSaranya;
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
        p.div_code  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.div_code  = @DivCode
      AND p.user_id   = @UserName
      AND dbo.DecryptString(p.password) = @Password
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
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
        p.div_code  AS DivCode,
        p.user_id   AS UserId,
        p.user_name AS UserName,
        p.alevel    AS ALevel
    FROM dbo.PP_PASSWD p
    WHERE p.user_id  = @UserId
      AND p.div_code = @DivCode
      AND UPPER(ISNULL(p.activeflg, 'N')) = 'Y';
END;
GO
