CREATE OR ALTER PROCEDURE ksp_PR_SaveFirstApproval
    @DivCode   VARCHAR(2),
    @PrNo      NUMERIC(6,0),
    @PrDate    DATETIME,
    @AppDate   DATETIME,
    @UserId    VARCHAR(50),
    @UserName  VARCHAR(50),
    @IpAddress VARCHAR(50),
    @HostName  VARCHAR(50),
    @ModuleNo  INT,
    @LinesJson NVARCHAR(MAX)       -- JSON array of approved lines
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Parse JSON lines ──────────────────────────────────────────────
        DECLARE @Lines TABLE (
            PrSno       NUMERIC(5,0),
            ItemCode    VARCHAR(10),
            DepCode     VARCHAR(3),
            QtyReqd     NUMERIC(12,3),
            FirstAppQty NUMERIC(12,3),
            Rate        NUMERIC(13,4),
            MacNo       VARCHAR(5),
            SubCost     NUMERIC(5,0),
            Uom         VARCHAR(3)
        );

        INSERT INTO @Lines (PrSno, ItemCode, DepCode, QtyReqd, FirstAppQty, Rate, MacNo, SubCost, Uom)
        SELECT
            CAST(j.PrSno        AS NUMERIC(5,0)),
            j.ItemCode,
            j.DepCode,
            CAST(j.QtyReqd      AS NUMERIC(12,3)),
            CAST(j.FirstAppQty  AS NUMERIC(12,3)),
            CAST(j.Rate         AS NUMERIC(13,4)),
            j.MacNo,
            TRY_CAST(j.SubCost  AS NUMERIC(5,0)),
            j.Uom
        FROM OPENJSON(@LinesJson) WITH (
            PrSno       NVARCHAR(20) '$.prSno',
            ItemCode    VARCHAR(10)  '$.itemCode',
            DepCode     VARCHAR(3)   '$.depCode',
            QtyReqd     NVARCHAR(20) '$.qtyReqd',
            FirstAppQty NVARCHAR(20) '$.firstAppQty',
            Rate        NVARCHAR(20) '$.rate',
            MacNo       VARCHAR(5)   '$.macNo',
            SubCost     NVARCHAR(20) '$.subCost',
            Uom         VARCHAR(3)   '$.uom'
        ) j;

        -- ── DEF-FA-01: server-side qty guard ─────────────────────────────────
        IF EXISTS (SELECT 1 FROM @Lines WHERE FirstAppQty > QtyReqd)
        BEGIN
            RAISERROR('First Approval Quantity exceeds Quantity Required on one or more lines.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- ── FA-ADD-09: reject zero or negative FirstAppQty ────────────────────
        IF EXISTS (SELECT 1 FROM @Lines WHERE FirstAppQty <= 0)
        BEGIN
            RAISERROR('First Approval Quantity must be greater than zero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- ── 2. Update PO_PRL lines ───────────────────────────────────────────
        -- PO_PRL columns: qtyreqd, FirstAppQty, FirstApp, RATE, VALUE, prstatus
        UPDATE l
        SET l.qtyreqd     = ln.QtyReqd,
            l.FirstAppQty = ln.FirstAppQty,
            l.FirstApp    = 'Y',
            l.RATE        = ln.Rate,
            l.VALUE       = ln.QtyReqd * ln.Rate,
            l.prstatus    = 'F',
            l.FirstappUser= @UserId
        FROM PO_PRL l
        INNER JOIN @Lines ln
            ON  ln.PrSno    = l.prsno
            AND ln.ItemCode = l.itemcode
        WHERE l.divcode = @DivCode
          AND l.prno    = @PrNo
          AND l.prdate  = @PrDate;

        -- ── 3. Update PO_PRH header — DEF-FA-03: only when ALL lines approved ─
        -- PO_PRH has NO PRSTATUS column. APPFLG tracks overall header approval.
        -- Only promote header to APPFLG='Y' when every PO_PRL line now has FirstApp='Y'.
        UPDATE PO_PRH
        SET APPFLG   = 'Y',
            APP1     = @UserId,
            APP1DATE = @AppDate,
            APP1TIME = GETDATE()
        WHERE divcode = @DivCode
          AND prno    = @PrNo
          AND prdate  = @PrDate
          AND NOT EXISTS (
              SELECT 1 FROM PO_PRL
              WHERE  divcode  = @DivCode
                AND  prno     = @PrNo
                AND  prdate   = @PrDate
                AND  ISNULL(FirstApp,  '') <> 'Y'
                AND  ISNULL(DirectApp, '') <> 'Y'           -- DirectApp lines bypass first-level
                AND  ISNULL(prstatus,  '') NOT IN ('X','Z') -- cancelled/foreclosed cannot be approved
          );

        -- ── 4. Audit log per line ────────────────────────────────────────────
        -- LogDet_po columns verified from live schema
        INSERT INTO LogDet_po (
            divcode, prno, prdate, itemcode, depcode,
            Trans_UserId, prsno, Quantity, username,
            Trans_date, Trans_Name, Trans_Mod,
            Trans_IPADD, Trans_Host,
            UOM, RATE, macno, SubCost, moduleNo,
            docno, docdt,
            FirstappUser, AppUser, Appdate, Appqty
        )
        SELECT
            @DivCode, @PrNo, @PrDate, ln.ItemCode, ln.DepCode,
            @UserId, ln.PrSno, ln.QtyReqd, @UserName,
            GETDATE(), 'Purchase Requisition Approval', 'ADD',
            @IpAddress, @HostName,
            ln.Uom, ln.Rate, ln.MacNo, ln.SubCost, @ModuleNo,
            @PrNo, @PrDate,
            @UserId, @UserId, @AppDate, ln.FirstAppQty
        FROM @Lines ln;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
