-- ============================================================
-- ksp_PR_SaveForeclosureLine
-- Force-closes a single PR line:
--   1. Sets prstatus='Z', FClosed='Y', FCloseddt=GETDATE() on PO_PRL
--   2. Resolves depcode from PO_PRH
--   3. Writes audit log entry (Trans_Mod='ADD')
-- NOTE: PO_PRH has NO prstatus column — Step 4 (header status promotion)
-- removed. Foreclosure status tracked via PO_PRL.prstatus only.
-- Called once per line from C#, which wraps all calls in an
-- outer UnitOfWork transaction covering the full save batch.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_SaveForeclosureLine
(
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATE,
    @PrSno     INT,
    @ItemCode  VARCHAR(15),
    @Balance   NUMERIC(10,3),
    @UserId    VARCHAR(50),
    @HostName  VARCHAR(100) = NULL,
    @IpAddress VARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Force-close the line (@PrSno=0 targets all lines for the item)
    UPDATE PO_PRL
    SET    prstatus  = 'Z',
           FClosed   = 'Y',
           FCloseddt = GETDATE()
    WHERE  divcode  = @DivCode
      AND  prno     = @PrNo
      AND  prdate   = @PrDate
      AND  itemcode = @ItemCode
      AND  (@PrSno = 0 OR prsno = @PrSno)
      AND  prstatus <> 'C';   -- FC-EX-09/BR-03: never force-close a Received line

    -- Step 2: Resolve depcode from header
    DECLARE @DepCode VARCHAR(3);
    SELECT TOP 1 @DepCode = depcode
    FROM PO_PRH
    WHERE divcode = @DivCode AND prno = @PrNo AND prdate = @PrDate;

    -- Step 3: Audit log
    INSERT INTO LogDet_po
        (divcode, prno, prdate, depcode,
         Trans_UserId, prsno, itemcode, Quantity,
         username, Trans_date,
         Trans_Name, Trans_Mod,
         Trans_IPADD, Trans_Host)
    VALUES
        (@DivCode, @PrNo, @PrDate, @DepCode,
         @UserId, @PrSno, @ItemCode, @Balance,
         @UserId, GETDATE(),
         'Purchase Requisition Foreclosure', 'ADD',
         @IpAddress, @HostName);

    -- Step 4 REMOVED: PO_PRH has no prstatus column.
    -- Foreclosure completion is determined by checking PO_PRL.prstatus
    -- on all lines — handled in the application layer if needed.
END;
