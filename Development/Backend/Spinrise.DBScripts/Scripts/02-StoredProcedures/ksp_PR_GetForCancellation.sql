-- ============================================================
-- ksp_PR_GetForCancellation
-- Returns two result sets for a PR under cancellation review.
--   Result Set 1 : PR header (single row)
--   Result Set 2 : PR line items (ordered by prsno)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetForCancellation
(
    @DivCode    VARCHAR(2),
    @PrNo       NUMERIC(6,0),
    @PrDate     DATE,
    @DepCode    VARCHAR(3)
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Result Set 1: Header
    SELECT
        a.prno                                              AS PrNo,
        CONVERT(VARCHAR(12), a.prdate, 106)                 AS PRDate,
        a.depcode                                           AS DepCode,
        c.Depname                                           AS Department,
        ISNULL(a.section,  '')                              AS Section,
        ISNULL(a.reqname,  '')                              AS RequestedBy,
        ISNULL(t.idesc, ISNULL(a.ITYPE,''))                 AS PRType,
        ISNULL(a.refno,    '')                              AS RefNo,
        ISNULL(a.reqname,  '')                              AS CreatedBy,
        ISNULL((SELECT TOP 1 PRSTATUS FROM PO_PRL
                 WHERE prno = a.prno AND divcode = a.divcode
                 ORDER BY prsno), '')                       AS Status
    FROM  PO_PRH a
    INNER JOIN In_dep        c ON c.depcode = a.depcode AND c.divcode = a.divcode
    LEFT  JOIN PO_INDENTTYPE t ON t.itype   = a.ITYPE
    WHERE a.divcode = @DivCode
      AND a.prno    = @PrNo
      AND a.prdate  = @PrDate
      AND a.depcode = @DepCode;

    -- Result Set 2: Line items
    SELECT
        CAST(ISNULL(b.prsno, 0) AS INT)                        AS Sno,
        b.itemcode                                             AS ItemCode,
        ISNULL(d.Itemname, '')                                 AS ItemName,
        ISNULL(d.UOM, '')                                      AS UOM,
        ISNULL(b.QTYIND,  0)                                   AS QtyRequired,
        ISNULL(b.QTYREQD, 0)                                   AS QtyApproved,
        ISNULL(b.QTYord,  0)                                   AS QtyOrdered,
        ISNULL(b.qtyrec,  0)                                   AS QtyReceived,
        ISNULL(d.curstk,  0)                                   AS CurrentStock,
        ISNULL(d.RATE,    0)                                   AS Rate,
        ISNULL(b.appcost, 0)                                   AS ApproxCost,
        ISNULL(CONVERT(VARCHAR(12), b.reqddate, 106), '')      AS ReqdDate,
        ISNULL(e.Description, '')                              AS Machine,
        ISNULL(b.place,   '')                                  AS PlaceOfIssue,
        ISNULL(b.remarks, '')                                  AS Remarks,
        CAST(CASE WHEN ISNULL(b.sample,'N')='Y' THEN 1 ELSE 0 END AS BIT) AS IsSample
    FROM  PO_PRL   b
    INNER JOIN in_item   d ON d.itemcode = b.itemcode
    LEFT  JOIN MM_MACMAS e ON e.MACFLAG  = 'M'
                           AND e.DIVCODE  = b.divcode
                           AND e.DEPCODE  = b.depcode
                           AND e.MAC_NO   = b.macno
    WHERE b.divcode = @DivCode
      AND b.prno    = @PrNo
      AND b.prdate  = @PrDate
    ORDER BY b.prsno;
END;
