CREATE OR ALTER PROCEDURE ksp_PR_GetFirstApprovalReport
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: Header + division letterhead
    SELECT
        -- Division letterhead (PP_DIVMAS — same columns as ksp_PR_GetPrint)
        dv.DIV_LOGO                                          AS DivLogo,
        RTRIM(ISNULL(dv.DIVNAME,        ''))                 AS DivName,
        RTRIM(ISNULL(dv.div_printname,  ''))                 AS DivPrintName,
        RTRIM(ISNULL(dv.div_unitname,   ''))                 AS DivUnitName,
        RTRIM(ISNULL(dv.DIVISION_ADDR1, ''))                 AS DivAddress1,
        RTRIM(ISNULL(dv.DIVISION_ADDR2, ''))                 AS DivAddress2,
        RTRIM(ISNULL(dv.DIVISION_ADDR3, ''))                 AS DivAddress3,
        RTRIM(ISNULL(dv.PINCODE,        ''))                 AS DivPinCode,
        RTRIM(ISNULL(dv.STATENAME,      ''))                 AS DivState,
        RTRIM(ISNULL(dv.PHONE1,         ''))                 AS DivPhone,
        RTRIM(ISNULL(dv.EMAIL,          ''))                 AS DivEmail,

        -- PR header
        h.divcode                                            AS DivCode,
        h.prno                                               AS PrNo,
        h.prdate                                             AS PrDate,
        RTRIM(ISNULL(h.depcode, ''))                         AS DepCode,
        RTRIM(ISNULL(d.DEPNAME, ''))                         AS DepName,
        RTRIM(ISNULL(NULLIF(RTRIM(h.refno), '0'), ''))       AS RefNo,
        RTRIM(ISNULL(h.SECTION, ''))                         AS Section,
        h.APP1DATE                                           AS App1Date,
        RTRIM(ISNULL(e.ename, h.REQNAME))                    AS ReqName,
        RTRIM(ISNULL(apv.user_name, ISNULL(h.APP1, '')))    AS ApproverName,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby,''))) AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                       AS CreatedDt

    FROM PO_PRH h
    LEFT JOIN PP_DIVMAS dv ON dv.DIVCODE = h.divcode
    LEFT JOIN IN_DEP    d  ON d.DEPCODE  = h.depcode AND d.divcode = h.divcode
    LEFT JOIN PR_EMP    e  ON TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno
                          AND e.divcode = h.divcode
    OUTER APPLY (
        SELECT TOP 1 user_name FROM PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(h.APP1)
          AND RTRIM(divcode)  = RTRIM(h.divcode)
    ) apv
    OUTER APPLY (
        SELECT TOP 1 user_name FROM PP_PASSWD
        WHERE RTRIM(user_id) = RTRIM(h.createdby)
          AND RTRIM(divcode)  = RTRIM(h.divcode)
    ) pwd
    WHERE h.divcode = @DivCode
      AND h.prno    = @PrNo
      AND h.prdate  = @PrDate;

    -- Result set 2: Lines (FirstApp = 'Y' only)
    SELECT
        l.prsno                    AS PrSno,
        RTRIM(l.itemcode)          AS ItemCode,
        RTRIM(ISNULL(i.ITEMNAME,'')) AS ItemName,
        RTRIM(ISNULL(i.CUOM,    '')) AS Uom,
        ISNULL(l.qtyind, 0)        AS QtyInd,
        ISNULL(l.FirstAppQty, 0)   AS FirstAppQty,
        ISNULL(l.RATE, 0)          AS Rate,
        RTRIM(ISNULL(l.remarks,'')) AS Remarks
    FROM PO_PRL l
    INNER JOIN IN_ITEM i ON i.ITEMCODE = l.itemcode
    WHERE l.divcode  = @DivCode
      AND l.prno     = @PrNo
      AND l.prdate   = @PrDate
      AND l.FirstApp = 'Y'
    ORDER BY l.prsno;
END;
GO
