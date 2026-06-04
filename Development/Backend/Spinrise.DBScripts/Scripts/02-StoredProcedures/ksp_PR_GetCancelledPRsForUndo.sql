-- Add pre_cancel_status to PO_PRH if it does not already exist (BR-UNDO-01)
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.PO_PRH')
       AND name = N'pre_cancel_status'
)
BEGIN
    ALTER TABLE dbo.PO_PRH ADD pre_cancel_status char(1) NULL;
END;
GO

CREATE OR ALTER PROCEDURE ksp_PR_GetCancelledPRsForUndo
    @divcode varchar(10),
    @yfdate  datetime,
    @yldate  datetime
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            a.prno,
            CONVERT(varchar(12), a.prdate,   106) AS PRDate,
            a.depcode                             AS DepCode,
            c.Depname                             AS Department,
            ISNULL(a.reqname, '')                 AS RequestedBy,
            CONVERT(varchar(12), a.canceldt, 106) AS CancelledOn,
            ISNULL(a.pre_cancel_status, '')        AS PrevStatus,
            a.row_version                          AS RowVersion,
            RTRIM(ISNULL(a.CANREASON, ''))         AS CancelReason
        FROM  PO_PRH a
        INNER JOIN In_dep c ON c.depcode  = a.depcode
                            AND c.divcode  = a.divcode
        WHERE a.divcode    = @divcode
          AND a.cancelflag = 'Y'
          AND a.prdate BETWEEN @yfdate AND @yldate
        ORDER BY a.canceldt DESC, a.prno DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
