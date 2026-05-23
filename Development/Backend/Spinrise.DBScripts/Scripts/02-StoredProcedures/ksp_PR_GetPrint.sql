CREATE OR ALTER PROCEDURE dbo.ksp_PR_GetPrint
(
    @DivCode VARCHAR(2),
    @PrNo    NUMERIC(6,0),
    @PrDate  DATE = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    IF @PrDate IS NULL RETURN;

    SELECT
        -- Division letterhead (PP_DIVMAS actual column names — matching V1)
        dv.DIV_LOGO                                         AS DivLogo,
        RTRIM(ISNULL(dv.DIVNAME,         ''))               AS DivName,
        RTRIM(ISNULL(dv.div_printname,   ''))               AS DivPrintName,
        RTRIM(ISNULL(dv.div_unitname,    ''))               AS DivUnitName,
        RTRIM(ISNULL(dv.DIVISION_ADDR1,  ''))               AS DivAddress1,
        RTRIM(ISNULL(dv.DIVISION_ADDR2,  ''))               AS DivAddress2,
        RTRIM(ISNULL(dv.DIVISION_ADDR3,  ''))               AS DivAddress3,
        RTRIM(ISNULL(dv.PINCODE,         ''))               AS DivPinCode,
        RTRIM(ISNULL(dv.STATENAME,       ''))               AS DivState,
        RTRIM(ISNULL(dv.PHONE1,          ''))               AS DivPhone,
        RTRIM(ISNULL(dv.EMAIL,           ''))               AS DivEmail,

        -- PR Header
        RTRIM(h.divcode)                                    AS DivCode,
        h.prno                                              AS PrNo,
        CAST(h.prdate AS DATE)                              AS PrDate,
        RTRIM(ISNULL(h.depcode,  ''))                       AS DepCode,
        RTRIM(ISNULL(dep.depname,''))                       AS DepName,
        RTRIM(ISNULL(h.REQNAME,  ''))                       AS ReqName,
        RTRIM(ISNULL(emp.ename,  ''))                       AS ReqEmpName,
        RTRIM(ISNULL(h.SECTION,  ''))                       AS Section,
        RTRIM(ISNULL(NULLIF(RTRIM(h.refno), '0'), ''))      AS RefNo,
        RTRIM(ISNULL(h.PO_GRP,   ''))                       AS PoGrp,
        RTRIM(ISNULL(it.IDESC,   ''))                       AS IDesc,
        RTRIM(ISNULL(h.APPFLG,   'N'))                      AS AppFlg,
        RTRIM(ISNULL(pwd.user_name, ISNULL(h.createdby,''))) AS CreatedBy,
        RTRIM(ISNULL(h.createddt, ''))                      AS CreatedDt,

        -- PR Line
        l.prsno                                             AS PrSno,
        RTRIM(ISNULL(l.itemcode, ''))                       AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                       AS ItemName,
        RTRIM(ISNULL(i.uom,      ''))                       AS Uom,
        RTRIM(ISNULL(i.CATLNO,   ''))                       AS CatNo,
        RTRIM(ISNULL(i.DRAWNO,   ''))                       AS DrawNo,
        RTRIM(ISNULL(l.macno,    ''))                       AS MacNo,
        RTRIM(ISNULL(m.MODEL,    ''))                       AS MacModel,
        RTRIM(ISNULL(m.MacMake,  ''))                       AS MacMake,
        ISNULL(l.qtyind,          0)                        AS QtyInd,
        CAST(l.reqddate AS DATE)                            AS ReqdDate,
        ISNULL(l.LPO_RATE,        0)                        AS LastPoRate,
        CAST(l.LPO_DATE AS DATE)                            AS LastPoDate,
        ISNULL(l.curstock,        0)                        AS CurrentStock,
        ISNULL(l.APPCOST,         0)                        AS AppCost,
        RTRIM(ISNULL(l.remarks,  ''))                       AS Remarks,

        -- Approval flags
        ISNULL(l.FirstApp,  'N')                            AS FirstApp,
        ISNULL(l.SecondApp, 'N')                            AS SecondApp,
        ISNULL(l.ThirdApp,  'N')                            AS ThirdApp,
        ISNULL(l.DirectApp, 'N')                            AS DirectApp,

        -- Approver names (FirstappUser has lowercase 'a' in the actual DB column)
        RTRIM(ISNULL(l.FirstappUser,  ''))                  AS FirstAppUser,
        RTRIM(ISNULL(l.SecondAppUser, ''))                  AS SecondAppUser,
        RTRIM(ISNULL(l.ThirdAppUser,  ''))                  AS ThirdAppUser,
        RTRIM(ISNULL(l.FinalAppUser,  ''))                  AS FinalAppUser,

        -- Only DirectAppDate exists; APP1/2/3DATE do not exist in this schema
        CASE WHEN l.DirectAppDate IS NOT NULL
             THEN CONVERT(VARCHAR(12), CAST(l.DirectAppDate AS DATE), 103)
             ELSE '' END                                     AS PresidentAppDate,

        -- CR-PR-12: user-selected rate (LPO/Average/Manual)
        ISNULL(l.RATE, 0)                                   AS Rate

    FROM  dbo.PO_PRH h
    INNER JOIN dbo.PO_PRL l
           ON  l.divcode              = h.divcode
           AND l.prno                 = h.prno
           AND CAST(l.prdate AS DATE) = CAST(h.prdate AS DATE)
    LEFT  JOIN dbo.PP_DIVMAS     dv  ON dv.DIVCODE = h.divcode
    LEFT  JOIN dbo.IN_DEP       dep  ON dep.divcode = h.divcode AND dep.depcode = h.depcode
    OUTER APPLY (SELECT TOP 1 ename FROM dbo.PR_EMP
                 WHERE CAST(empno AS VARCHAR(10)) = h.REQNAME)            emp
    OUTER APPLY (SELECT TOP 1 IDESC FROM dbo.PO_INDENTTYPE
                 WHERE ITYPE = h.ITYPE)                                   it
    OUTER APPLY (SELECT TOP 1 user_name FROM dbo.PP_PASSWD
                 WHERE RTRIM(user_id) = RTRIM(h.createdby)
                   AND RTRIM(divcode) = RTRIM(h.divcode))                 pwd
    LEFT  JOIN dbo.IN_ITEM        i  ON i.itemcode = l.itemcode
    LEFT  JOIN dbo.MM_MACMAS      m  ON m.DIVCODE  = l.divcode
                                    AND m.MAC_NO   = l.macno
                                    AND m.DEPCODE  = h.depcode
                                    AND m.MACFLAG  = 'M'
    WHERE h.divcode              = @DivCode
      AND h.prno                 = @PrNo
      AND CAST(h.prdate AS DATE) = @PrDate
      AND ISNULL(l.AmdFlg, '')  <> 'Y'
    ORDER BY l.prsno;
END;
GO
