CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovalLines
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- PO_PRL: macno varchar(5)  — NOT mac_no
    -- mm_MACmas: MAC_NO varchar(5), DESCRIPTION varchar(30)  — MAC_NO uppercase
    SELECT
        l.prsno                                   AS PrSno,
        l.itemcode                                AS ItemCode,
        i.ITEMNAME                                AS ItemName,
        i.CUOM                                    AS Uom,
        m.DESCRIPTION                             AS Machine,
        ISNULL(i.CURSTK, 0)                       AS CurStock,
        ISNULL(l.qtyind,  0)                      AS QtyInd,
        ISNULL(l.qtyreqd, 0)                      AS QtyReqd,
        ISNULL(l.FirstAppQty, 0)                  AS FirstAppQty,
        ISNULL(l.SecondAppQty, 0)                 AS SecondAppQty,
        ISNULL(l.ThirdAppQty, 0)                  AS ThirdAppQty,
        ISNULL(l.qtyord, 0)                       AS QtyOrd,
        ISNULL(l.qtyrec, 0)                       AS QtyRec,
        ISNULL(l.RATE, ISNULL(i.RATE, 0))         AS Rate,
        ISNULL(l.VALUE, 0)                        AS Value,
        l.reqddate                                AS ReqdDate,
        l.FirstApp                                AS FirstApp,
        l.prstatus                                AS PrStatus,
        l.PLACE                                   AS Place,
        ISNULL(l.APPCOST, 0)                      AS AppCost,
        l.remarks                                 AS Remarks,
        l.BGRPCODE                                AS BgrpCode,
        l.macno                                   AS MacNo
    FROM PO_PRL l
    INNER JOIN IN_ITEM   i ON i.ITEMCODE  = l.itemcode
    LEFT  JOIN mm_MACmas m ON m.MAC_NO    = l.macno
                          AND m.DEPCODE   = l.Depcode
                          AND m.DIVCODE   = l.divcode
    WHERE l.divcode = @DivCode
      AND l.prno    = @PrNo
      AND l.prdate  = @PrDate
    ORDER BY l.prsno;
END;
