CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovedForDeletion
    @DivCode VARCHAR(2),
    @YFDate  DATETIME,         -- financial year start (B13/B14: year guard required)
    @YLDate  DATETIME          -- financial year end
AS
BEGIN
    SET NOCOUNT ON;

    -- Year guard applied per prompt clarification B13/B14 (overrides OI-02).
    -- Used for both Delete-Approval listing AND Find/Navigation.

    SELECT DISTINCT
        h.prno              AS PrNo,
        h.prdate            AS PrDate,
        h.depcode           AS DepCode,
        ISNULL(d.DEPNAME, h.depcode) AS DepName,
        ISNULL(h.refno, '')  AS RefNo,
        ISNULL(h.SECTION,'') AS Section
    FROM PO_PRH h
    LEFT JOIN IN_DEP d
        ON  d.DEPCODE = h.depcode
        AND d.divcode = h.divcode
    WHERE h.divcode = @DivCode
      AND h.prdate BETWEEN @YFDate AND @YLDate
      AND ISNULL(h.cancelflag, 'N') <> 'Y'
      AND EXISTS (
            SELECT 1
            FROM   PO_PRL l
            WHERE  l.divcode   = h.divcode
              AND  l.prno      = h.prno
              AND  l.prdate    = h.prdate
              AND  l.FirstApp  IS NOT NULL
              AND  l.DirectApp IS NULL
              AND  ISNULL(l.FClosed, 'N') <> 'Y'
          )
    ORDER BY h.prdate DESC, h.prno DESC;
END;
