CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovalHeader
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.divcode                                   AS DivCode,
        h.prno                                      AS PrNo,
        h.prdate                                    AS PrDate,
        h.depcode                                   AS DepCode,
        ISNULL(d.DEPNAME, '')                       AS DepName,
        h.refno                                     AS RefNo,
        h.SECTION                                   AS Section,
        CAST(h.SubCost AS VARCHAR(20))              AS SubCost,
        s.SCCNAME                                   AS SccName,
        h.APP1                                      AS App1,
        h.APP2                                      AS App2,
        h.APP3                                      AS App3,
        h.APPFLG                                    AS AppFlg,
        h.APP1DATE                                  AS App1Date,
        ISNULL(e.ename, h.REQNAME)                  AS ReqName
    FROM PO_PRH h
    LEFT JOIN IN_DEP  d ON d.DEPCODE = h.depcode
                       AND d.divcode = h.divcode
    LEFT JOIN IN_SCC  s ON s.SCCCODE = h.SubCost
                       AND s.Divcode = h.divcode
                       AND s.DEPCODE = h.depcode
    LEFT JOIN PR_EMP  e ON TRY_CAST(h.REQNAME AS DECIMAL(5,0)) = e.empno
                       AND e.divcode = h.divcode
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND h.prdate  = @PrDate;

END;