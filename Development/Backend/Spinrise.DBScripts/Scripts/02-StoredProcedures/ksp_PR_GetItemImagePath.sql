CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetItemImagePath
(
    @ItemCode VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RTRIM(ISNULL(ImagePath, '')) AS ImagePath
    FROM   dbo.IN_ITEM
    WHERE  itemcode = @ItemCode;
END;
GO
