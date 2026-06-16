-- ============================================================
-- ksp_PO_GetPrint
-- Returns print data for a PO (PDF generation via QuestPDF).
-- Returns 2 result sets: (1) header with division letterhead,
--                        (2) PO lines.
-- PP_DIVMAS confirmed columns: div_printname, PHONE1, gstinno,
--   add1, add2, add3, pincode, email — all verified.
-- FA_SLMAS confirmed columns: add1, add2, gstinno (lowercase).
-- PO_ORDH: GST % columns don't exist — amounts only.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPrint
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── Result set 1: Print header (div letterhead + PO header) ──────────────
    SELECT
        -- Division letterhead
        div.DIV_LOGO                                                AS DivLogo,
        RTRIM(ISNULL(div.divname, ''))                              AS DivName,
        RTRIM(ISNULL(div.div_printname, div.divname))               AS DivPrintName,
        RTRIM(ISNULL(div.div_unitname, ''))                         AS DivUnitName,
        RTRIM(ISNULL(div.add1, ''))                                 AS DivAddress1,
        RTRIM(ISNULL(div.add2, ''))                                 AS DivAddress2,
        RTRIM(ISNULL(div.add3, ''))                                 AS DivAddress3,
        RTRIM(ISNULL(div.pincode, ''))                              AS DivPinCode,
        RTRIM(ISNULL(div.PHONE1, ''))                               AS DivPhone,
        RTRIM(ISNULL(div.email, ''))                                AS DivEmail,
        RTRIM(ISNULL(div.gstinno, ''))                              AS DivGstin,
        RTRIM(ISNULL(div.PAN, ''))                                  AS DivPan,
        RTRIM(ISNULL(div.WEBADDR, ''))                              AS DivWeb,
        -- PO header
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS SlCode,
        RTRIM(ISNULL(sl.slname, ''))                                AS SlName,
        RTRIM(ISNULL(sl.add1, '')) +
            CASE WHEN RTRIM(ISNULL(sl.add2, '')) <> ''
                 THEN ' ' + RTRIM(sl.add2) ELSE '' END              AS SlAddress,
        RTRIM(ISNULL(sl.gstinno, ''))                               AS SlGstin,
        RTRIM(ISNULL(sl.phone1, ''))                                AS SlPhone,
        RTRIM(ISNULL(sl.email, ''))                                 AS SlEmail,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier,
        RTRIM(ISNULL(h.CurrCode, ''))                               AS Currency,
        ISNULL(h.FCurRate, 1)                                       AS CurrRate,
        ISNULL(h.CRDDAYS, 0)                                        AS CreditDays,
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.REMARKS, ''))                                AS Remarks,
        -- PO_ORDH has no GST % columns — amounts only
        CAST(0 AS DECIMAL(10,2))                                    AS CgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS IgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        ISNULL(h.roff, 0)                                           AS RoundOff,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(h.createdby, ''))                              AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        -- Additional fields for V2 print
        RTRIM(ISNULL(h.refno, ''))                                  AS RefNo,
        CASE WHEN h.refDate IS NULL THEN ''
             ELSE CONVERT(varchar(10), h.refDate, 103) END          AS RefDate,
        CASE WHEN h.Duedate IS NULL THEN ''
             ELSE CONVERT(varchar(10), h.Duedate, 103) END          AS DeliveryDate,
        RTRIM(ISNULL(h.Note, ''))                                   AS Purpose,
        RTRIM(ISNULL(h.paytermcode, ''))                            AS PayTerms,
        ISNULL(h.Ins_Amt, 0)                                        AS InsAmt,
        ISNULL(h.Pack_Amt, 0)                                       AS PackAmt,
        LEFT(ISNULL(div.gstinno, ''), 2)                            AS DivStateCode,
        LEFT(ISNULL(sl.gstinno, ''), 2)                             AS SlStateCode
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.pp_divmas div
        ON RTRIM(div.divcode) = RTRIM(h.DIVCODE)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;

    -- ─── Result set 2: Print lines ────────────────────────────────────────────
    SELECT
        l.PORDSNO                                                   AS [LineNo],
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        RTRIM(ISNULL(l.hsncode, ''))                                AS HsnCode,
        l.PRNO                                                      AS PrNo,
        l.PRSNO                                                     AS PrSno,
        ISNULL(l.ORDqty, 0)                                         AS Qty,
        ISNULL(l.Rate, 0)                                           AS Rate,
        ISNULL(l.ORDVAL, 0)                                         AS Value,
        RTRIM(ISNULL(l.Tax_code, ''))                               AS TaxCode,
        ISNULL(l.taxper, 0)                                         AS TaxPer,
        ISNULL(l.Taxamt, 0)                                         AS TaxAmt,
        ISNULL(l.cgstper, 0)                                        AS CgstPer,
        ISNULL(l.cgstamt, 0)                                        AS CgstAmt,
        ISNULL(l.sgstper, 0)                                        AS SgstPer,
        ISNULL(l.sgstamt, 0)                                        AS SgstAmt,
        ISNULL(l.igstper, 0)                                        AS IgstPer,
        ISNULL(l.igstamt, 0)                                        AS IgstAmt,
        ISNULL(l.Tcs_per, 0)                                        AS TcsPer,
        ISNULL(l.Tcs_amt, 0)                                        AS TcsAmt,
        ISNULL(l.disper, 0)                                         AS LineDis,
        ISNULL(l.disamt, 0)                                         AS LineDisAmt
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE l.DIVCODE = @DivCode
      AND l.PORDNO  = @PoNo
      AND CAST(l.PORDDT AS DATE) = @PoDate
    ORDER BY l.PORDSNO;
END;
GO
