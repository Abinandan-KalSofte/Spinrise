-- OI-07 HELD: Header-level reset (all lines). Per-line scope pending CEO confirmation.
CREATE OR ALTER PROCEDURE ksp_PR_DeleteFirstApproval
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATETIME,
    @UserId    VARCHAR(50),
    @UserName  VARCHAR(50),
    @IpAddress VARCHAR(50),
    @HostName  VARCHAR(50),
    @ModuleNo  INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Reset PO_PRH header ───────────────────────────────────────────
        -- PO_PRH has NO PRSTATUS column — do not update it here
        UPDATE PO_PRH
        SET APPFLG   = 'N',
            APP1     = NULL,
            APP1DATE = NULL,
            APP1TIME = NULL
        WHERE divcode = @DivCode
          AND prno    = @PrNo
          AND prdate  = @PrDate;

        -- ── 2. Reset PO_PRL lines (where DirectApp IS NULL) ──────────────────
        -- qtyreqd is written during SaveFirstApproval so must be cleared on delete
        UPDATE PO_PRL
        SET qtyreqd      = NULL,
            FirstAppQty  = 0,
            FirstApp     = NULL,
            prstatus     = NULL,
            FirstappUser = NULL
        WHERE divcode   = @DivCode
          AND prno      = @PrNo
          AND prdate    = @PrDate
          AND (DirectApp IS NULL OR DirectApp <> 'Y');

        -- ── 3. Audit log per affected line ───────────────────────────────────
        INSERT INTO LogDet_po (
            divcode, prno, prdate, itemcode, depcode,
            Trans_UserId, prsno, Quantity, username,
            Trans_date, Trans_Name, Trans_Mod,
            Trans_IPADD, Trans_Host,
            UOM, RATE, macno, SubCost, moduleNo,
            docno, docdt
        )
        SELECT
            @DivCode, @PrNo, @PrDate, l.itemcode, l.Depcode,
            @UserId, l.prsno, ISNULL(l.qtyind, 0), @UserName,
            GETDATE(), 'Purchase Requisition Approval', 'DELETE',
            @IpAddress, @HostName,
            i.CUOM, ISNULL(l.RATE, 0), l.macno, h.SubCost, @ModuleNo,
            @PrNo, @PrDate
        FROM PO_PRL l
        INNER JOIN IN_ITEM i ON i.ITEMCODE = l.itemcode
        LEFT  JOIN PO_PRH  h ON h.divcode = l.divcode
                             AND h.prno    = l.prno
                             AND h.prdate  = l.prdate
        WHERE l.divcode  = @DivCode
          AND l.prno     = @PrNo
          AND l.prdate   = @PrDate
          AND (l.DirectApp IS NULL OR l.DirectApp <> 'Y');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
