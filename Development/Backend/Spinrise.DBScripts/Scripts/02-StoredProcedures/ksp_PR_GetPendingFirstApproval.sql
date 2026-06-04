CREATE OR ALTER PROCEDURE ksp_PR_GetPendingFirstApproval
    @DivCode VARCHAR(2),
    @Dep     VARCHAR(3),       -- specific depcode from PO_IndentAppUser for logged-in user
    @YFDate  DATETIME,         -- financial year start (B13/B14: year guard required)
    @YLDate  DATETIME          -- financial year end
AS
BEGIN
    SET NOCOUNT ON;

    -- Year guard applied per prompt clarification B13/B14 (overrides OI-02).
    -- Eligible PR = header not cancelled + prdate in current FY + at least one line where:
    --   FirstApp IS NULL AND SecondApp IS NULL AND ThirdApp IS NULL
    --   AND DirectApp IS NULL AND line not force-closed.

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
      AND h.depcode = @Dep
      AND h.prdate BETWEEN @YFDate AND @YLDate
      AND ISNULL(h.cancelflag, 'N') <> 'Y'
      AND EXISTS (
            SELECT 1
            FROM   PO_PRL l
            WHERE  l.divcode   = h.divcode
              AND  l.prno      = h.prno
              AND  l.prdate    = h.prdate
              AND  l.FirstApp  IS NULL
              AND  l.SecondApp IS NULL
              AND  l.ThirdApp  IS NULL
              AND  l.DirectApp IS NULL
              AND  ISNULL(l.FClosed, 'N') <> 'Y'
          )
    ORDER BY h.prdate DESC, h.prno DESC;
END;
