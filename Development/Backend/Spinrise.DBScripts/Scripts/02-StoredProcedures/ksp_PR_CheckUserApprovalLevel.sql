CREATE OR ALTER PROCEDURE ksp_PR_CheckUserApprovalLevel
    @DivCode VARCHAR(2),
    @UserId  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- PP_PASSWD: user_id varchar(5), alevel decimal(3,0) — NOT USERID / ULEVEL
    -- PO_PARA:   APPUSERLEVEL1 numeric(5,0)
    SELECT
        p.alevel            AS UserLevel,
        pa.APPUSERLEVEL1    AS AppUserLevel1,
        pa.AppUserLevel2    AS AppUserLevel2,
        pa.AppUserLevel3    AS AppUserLevel3,
        pa.AppUserLabel1    AS AppUserLabel1,
        pa.AppUserLabel2    AS AppUserLabel2,
        pa.AppUserLabel3    AS AppUserLabel3
    FROM PP_PASSWD p
    CROSS JOIN PO_PARA pa
    WHERE p.divcode  = @DivCode
      AND p.user_id  = @UserId
      AND pa.divcode = @DivCode;
END;
