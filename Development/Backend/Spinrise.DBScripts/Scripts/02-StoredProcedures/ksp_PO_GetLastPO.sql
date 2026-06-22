-- ============================================================
-- ksp_PO_GetLastPO
-- Loads most recent PO for the division in the FY window.
-- Returns 3 result sets: (1) header, (2) lines, (3) delivery slots.
-- Called on screen load (View mode initial state).
-- Column mapping confirmed against live JAT PO_ORDH schema.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetLastPO
(
    @DivCode VARCHAR(2),
    @FDate   DATE,
    @LDate   DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PoNo   NUMERIC(10,0);
    DECLARE @PoDate DATE;

    SELECT TOP 1
        @PoNo   = PORDNO,
        @PoDate = CAST(PORDDT AS DATE)
    FROM dbo.PO_ORDH
    WHERE DIVCODE = @DivCode
      AND CAST(PORDDT AS DATE) BETWEEN @FDate AND @LDate
      AND ISNULL(CANFLG, '') = ''
    ORDER BY PORDDT DESC, PORDNO DESC;

    IF @PoNo IS NULL
    BEGIN
        SELECT NULL AS DivCode, NULL AS PoNo, NULL AS PoDate, NULL AS OrderType,
               NULL AS OrderTypeDesc, NULL AS Supplier, NULL AS SupplierName,
               NULL AS Gstin, NULL AS GstState, NULL AS Inspect,
               NULL AS RoundOff, NULL AS OrderValue, NULL AS FormType,
               NULL AS RefNo, NULL AS RefDate, NULL AS Currency, NULL AS CurrRate,
               NULL AS Remarks, NULL AS CgstPer, NULL AS SgstPer, NULL AS IgstPer,
               NULL AS TcsPer, NULL AS DiscPer, NULL AS CessPer, NULL AS AedPer,
               NULL AS FreightAmt, NULL AS FreightPer, NULL AS PackPer, NULL AS InsurPer,
               NULL AS SurchargePer, NULL AS AddTaxPer, NULL AS FileNo,
               NULL AS FcaFob, NULL AS FreightType, NULL AS DiscApp,
               NULL AS PackApp, NULL AS PayMode,
               NULL AS DirectInstr, NULL AS BankCode, NULL AS PaymentTerms,
               NULL AS AdvPer, NULL AS AdvAmt, NULL AS ModeOfPayment,
               NULL AS PayRef, NULL AS PayRefDate, NULL AS ChequeNo,
               NULL AS ChequeDate, NULL AS CreditDays, NULL AS DeliveryDate,
               NULL AS DeliveryLocation, NULL AS BillingAddress,
               NULL AS SpecialInstr, NULL AS Despatch, NULL AS Purpose,
               NULL AS OtherLevies, NULL AS PricingTerms, NULL AS PackForwarding,
               NULL AS Insurance, NULL AS Freight, NULL AS Reminder, NULL AS Status,
               NULL AS Cancelled, NULL AS CancelDate, NULL AS CancelReason,
               NULL AS Approved, NULL AS ApprovedBy, NULL AS AmdOrderNo,
               NULL AS AmdDate, NULL AS AmdRefNo, NULL AS AmdRefDate,
               NULL AS ApprovalStatus, NULL AS PrintStatus, NULL AS FirstLevelApp,
               NULL AS Conflg, NULL AS CreatedBy, NULL AS CreatedDt,
               NULL AS UserId, NULL AS Carrier,
               NULL AS FreightPosition, NULL AS InsurancePosition, NULL AS CessPosition,
               NULL AS PackingAmt, NULL AS InsuranceAmt,
               NULL AS DiscountAmt, NULL AS CessAmt, NULL AS AddTaxAmt
        WHERE 1 = 0;
        SELECT 0 AS [LineNo] WHERE 1 = 0;
        SELECT 0 AS [LineNo] WHERE 1 = 0;
        RETURN;
    END

    -- ─── Result set 1: Header ─────────────────────────────────────────────────
    SELECT
        RTRIM(h.DIVCODE)                                            AS DivCode,
        h.PORDNO                                                    AS PoNo,
        CONVERT(varchar(10), CAST(h.PORDDT AS DATE), 120)          AS PoDate,
        RTRIM(ISNULL(h.POGRP, ''))                                  AS OrderType,
        RTRIM(ISNULL(t.TYPNAME, ''))                                AS OrderTypeDesc,
        RTRIM(ISNULL(h.SLCODE, ''))                                 AS Supplier,
        RTRIM(ISNULL(sl.slname, ''))                                AS SupplierName,
        RTRIM(ISNULL(h.cust_gstinno, ''))                           AS Gstin,
        CAST(ISNULL(h.cust_gststcode, 0) AS VARCHAR(50))            AS GstState,
        CASE WHEN UPPER(RTRIM(ISNULL(h.INSPECT, 'N'))) = 'Y' THEN 'YES' ELSE 'NO' END AS Inspect,
        ISNULL(h.roff, 0)                                           AS RoundOff,
        ISNULL(h.ORDVAL, 0)                                         AS OrderValue,
        RTRIM(ISNULL(h.Form_type, ''))                              AS FormType,
        RTRIM(ISNULL(h.refno, ''))                                  AS RefNo,
        CASE WHEN h.refDate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.refDate AS DATE), 120) END AS RefDate,
        RTRIM(ISNULL(h.CurrCode, ''))                               AS Currency,
        ISNULL(h.FCurRate, 1)                                       AS CurrRate,
        RTRIM(ISNULL(h.REMARKS, ''))                                AS Remarks,
        -- Header GST: PO_ORDH stores amounts only (CGSTAMT/SGSTAMT/IGSTAMT), not percentages
        CAST(0 AS DECIMAL(10,2))                                    AS CgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS SgstPer,
        CAST(0 AS DECIMAL(10,2))                                    AS IgstPer,
        ISNULL(h.htcs_amt, 0)                                       AS TcsPer,
        ISNULL(h.DISPER, 0)                                         AS DiscPer,
        ISNULL(h.Cessper, 0)                                        AS CessPer,
        CAST(0 AS DECIMAL(10,2))                                    AS AedPer,
        ISNULL(h.FREIGHT, 0)                                        AS FreightAmt,
        CASE WHEN ISNULL(h.ORDVAL, 0) > 0
             THEN ROUND(ISNULL(h.FREIGHT, 0) * 100.0 / h.ORDVAL, 2)
             ELSE 0 END                                             AS FreightPer,
        ISNULL(h.PCKPER, 0)                                         AS PackPer,
        ISNULL(h.INSPER, 0)                                         AS InsurPer,
        ISNULL(h.SURPER, 0)                                         AS SurchargePer,
        ISNULL(h.ADDTAXPER, 0)                                      AS AddTaxPer,
        RTRIM(ISNULL(h.FILENO, ''))                                 AS FileNo,
        ISNULL(h.FCACharg, 0)                                       AS FcaFob,
        CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
        CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        -- Applicability position flags (FRT_FLG/Ins_Flg/Cess_Flg: 'A'=AFTER, else BEFORE)
        CASE WHEN UPPER(RTRIM(ISNULL(h.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsurancePosition,
        CASE WHEN UPPER(RTRIM(ISNULL(h.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessPosition,
        -- Charge amounts: Pack_Amt and Ins_Amt stored in DB; others derived from stored %
        ISNULL(h.Pack_Amt, 0)                                                                 AS PackingAmt,
        ISNULL(h.Ins_Amt,  0)                                                                 AS InsuranceAmt,
        ROUND(ISNULL(h.ORDVAL,0) * ISNULL(h.DISPER,0)    / 100.0, 2)                        AS DiscountAmt,
        ROUND(ISNULL(h.ORDVAL,0) * ISNULL(h.Cessper,0)   / 100.0, 2)                        AS CessAmt,
        ROUND(ISNULL(h.ORDVAL,0) * ISNULL(h.ADDTAXPER,0) / 100.0, 2)                        AS AddTaxAmt,
        -- Payment
        CASE WHEN RTRIM(ISNULL(h.PAYMENT, 'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
        RTRIM(ISNULL(h.DIRECT_INS, ''))                             AS DirectInstr,
        RTRIM(ISNULL(h.BANK_CODE, ''))                              AS BankCode,
        RTRIM(ISNULL(h.PAYTERMS, ''))                               AS PaymentTerms,
        RTRIM(ISNULL(h.paytermcode, ''))                            AS PaymentTermCode,
        ISNULL(h.ADV_PER, 0)                                        AS AdvPer,
        ISNULL(h.ADV_AMT, 0)                                        AS AdvAmt,
        RTRIM(ISNULL(h.advpaymenttype, ''))                         AS ModeOfPayment,
        RTRIM(ISNULL(h.chqno, ''))                                  AS PayRef,    -- FIX: CHQNO stores PayRef (DIRECT) or ChequeNo (BANK) via COALESCE; return same value
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS PayRefDate, -- FIX: CHQDT stores PayRefDate (DIRECT) or ChequeDate (BANK) via COALESCE
        RTRIM(ISNULL(h.chqno, ''))                                  AS ChequeNo,
        CASE WHEN h.chqdt IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.chqdt AS DATE), 120) END AS ChequeDate,
        ISNULL(h.CRDDAYS, 0)                                        AS CreditDays,
        -- Instructions
        CASE WHEN h.Duedate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.Duedate AS DATE), 120) END AS DeliveryDate,
        RTRIM(ISNULL(h.DEL_INS1, ''))                               AS DeliveryLocation,
        RTRIM(ISNULL(h.Billadd, ''))                                AS BillingAddress,
        RTRIM(ISNULL(h.SPL_INS, ''))                                AS SpecialInstr,
        RTRIM(ISNULL(h.DEL_INS2, ''))                               AS Despatch,
        RTRIM(ISNULL(h.Note, ''))                                   AS Purpose,
        RTRIM(ISNULL(h.Note2, ''))                                  AS OtherLevies, -- FIX: was hardcoded ''; @OtherLevies maps to Note2 per SaveEntry comment
        RTRIM(ISNULL(h.PriceTerm, ''))                              AS PricingTerms,
        RTRIM(ISNULL(h.RemarksPF, ''))                              AS PackForwarding,
        RTRIM(ISNULL(h.RemarksIns, ''))                             AS Insurance,
        RTRIM(ISNULL(h.RemarksFrt, ''))                             AS Freight,
        -- Cancel / status
        RTRIM(ISNULL(h.REMINDER, ''))                               AS Reminder,
        ''                                                          AS Status,
        CAST(CASE WHEN ISNULL(h.CANFLG, '') <> '' THEN 1 ELSE 0 END AS BIT) AS Cancelled,
        CASE WHEN h.CANDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.CANDT AS DATE), 120) END AS CancelDate,
        RTRIM(ISNULL(h.REASON, ''))                                 AS CancelReason,
        RTRIM(ISNULL(h.APPROVED, 'N'))                              AS Approved,
        RTRIM(ISNULL(h.APPBY, ''))                                  AS ApprovedBy,
        -- Amendment
        TRY_CAST(NULLIF(RTRIM(h.AMDORDNO), '') AS DECIMAL(10,0))   AS AmdOrderNo,
        CASE WHEN h.AMDORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.AMDORDDT AS DATE), 120) END AS AmdDate,
        TRY_CAST(NULLIF(RTRIM(h.REFORDNO), '') AS DECIMAL(10,0))   AS AmdRefNo,
        CASE WHEN h.REFORDDT IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(h.REFORDDT AS DATE), 120) END AS AmdRefDate,
        -- Approval / print
        CASE WHEN ISNULL(h.Conflg, 'N') = 'Y' THEN 'CONFIRMED' ELSE 'PENDING' END AS ApprovalStatus,
        RTRIM(ISNULL(h.poprintflg, 'N'))                            AS PrintStatus,
        RTRIM(ISNULL(h.FirstlevelApp, 'N'))                         AS FirstLevelApp,
        RTRIM(ISNULL(h.Conflg, 'N'))                                AS Conflg,
        RTRIM(ISNULL(u.user_name, h.createdby))                     AS CreatedBy,
        ISNULL(CONVERT(varchar(19), h.createddt, 103), '')          AS CreatedDt,
        RTRIM(ISNULL(h.createdby, ''))                              AS UserId,
        RTRIM(ISNULL(h.CARCODE, ''))                                AS Carrier
    FROM dbo.PO_ORDH h
    LEFT JOIN dbo.PO_TYPE t
        ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    LEFT JOIN dbo.FA_SLMAS sl
        ON RTRIM(sl.slcode) = RTRIM(h.SLCODE)
    OUTER APPLY (
        SELECT TOP 1 u.user_name
        FROM dbo.PP_PASSWD u
        WHERE RTRIM(u.user_id) = RTRIM(h.createdby)
          AND RTRIM(u.divcode)  = RTRIM(h.DIVCODE)
    ) u
    WHERE h.DIVCODE = @DivCode
      AND h.PORDNO  = @PoNo
      AND CAST(h.PORDDT AS DATE) = @PoDate;

    -- ─── Result set 2: Lines ──────────────────────────────────────────────────
    SELECT
        l.PORDSNO                                                   AS [LineNo],
        l.PRSNO                                                     AS PrSno,
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(CONVERT(varchar(10), CAST(l.PRDATE AS DATE), 120), '') AS PrDate,
        ISNULL(l.Rate, 0)                                           AS Rate,
        ISNULL(l.ORDqty, 0)                                         AS Qty,
        ISNULL(prl.qtyreqd,0) - ISNULL(prl.qtyord,0) - ISNULL(prl.Enq_Qty,0) AS BalanceQty,
        ISNULL(l.ORDVAL, 0)                                         AS Value,
        RTRIM(ISNULL(l.Tax_code, ''))                               AS TaxCode,
        ISNULL(l.taxper, 0)                                         AS TaxPer,
        ISNULL(l.cgstamt,0) + ISNULL(l.sgstamt,0) + ISNULL(l.igstamt,0) AS TaxAmt,
        RTRIM(ISNULL(l.hsncode, ''))                                AS HsnCode,
        ISNULL(l.cgstper, 0)                                        AS CgstPer,
        ISNULL(l.cgstamt, 0)                                        AS CgstAmt,
        ISNULL(l.sgstper, 0)                                        AS SgstPer,
        ISNULL(l.sgstamt, 0)                                        AS SgstAmt,
        ISNULL(l.igstper, 0)                                        AS IgstPer,
        ISNULL(l.igstamt, 0)                                        AS IgstAmt,
        ISNULL(l.Tcs_per, 0)                                        AS TcsPer,
        ISNULL(l.Tcs_amt, 0)                                        AS TcsAmt,
        RTRIM(ISNULL(l.cgst_tax_code, ''))                          AS CgstCode,
        RTRIM(ISNULL(l.sgst_tax_code, ''))                          AS SgstCode,
        RTRIM(ISNULL(l.igst_tax_code, ''))                          AS IgstCode,
        RTRIM(ISNULL(l.reqidpo, ''))                                AS RequesterId,
        RTRIM(ISNULL(l.reqnamepo, ''))                              AS RequesterName,
        CASE WHEN ISNULL(l.igstper, 0) > 0 THEN 'IGST' ELSE 'LOCAL' END AS Route,
        RTRIM(ISNULL(l.deletereason, ''))                           AS DeleteReason,
        ISNULL(l.disper,    0)                                      AS DiscPer,
        ISNULL(l.disamt,    0)                                      AS DiscAmt,
        ISNULL(l.PACKPER,   0)                                      AS PackingPer,
        ISNULL(l.Packamt,   0)                                      AS PackingAmt,
        ISNULL(l.Frgt1per,  0)                                      AS FreightPer,
        ISNULL(l.Frgt1Amt,  0)                                      AS FreightAmt,
        ISNULL(l.Ins_per,   0)                                      AS InsurancePer,
        ISNULL(l.Ins_amt,   0)                                      AS InsuranceAmt,
        ISNULL(l.OTHCHGS,   0)                                      AS OtherCharges,
        ISNULL(l.cess_per,  0)                                      AS CessPer,
        ISNULL(l.cess_amt,  0)                                      AS CessAmt,
        RTRIM(ISNULL(l.ADDTAX_CODE, ''))                            AS AddTaxCode,
        ISNULL(l.ADDTAXPER, 0)                                      AS AddTaxPer,
        ISNULL(l.ADDTAXAMT, 0)                                      AS AddTaxAmt,
        ISNULL(l.FCACharg,  0)                                      AS FcaFob,
        CASE WHEN UPPER(RTRIM(ISNULL(l.DISFLG,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
        CASE WHEN UPPER(RTRIM(ISNULL(l.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPos,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsuranceDuty,
        CASE WHEN UPPER(RTRIM(ISNULL(l.Cess_Flg, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS CessTaxPos,
        -- POT-TC-04: Landing Cost (net per line = taxable + GST + TCS + charges - discount)
        ISNULL(l.ORDVAL,0)
          - ISNULL(l.disamt,0)
          + ISNULL(l.Packamt,0)
          + ISNULL(l.Frgt1Amt,0)
          + ISNULL(l.Ins_amt,0)
          + ISNULL(l.OTHCHGS,0)
          + ISNULL(l.cess_amt,0)
          + ISNULL(l.cgstamt,0)
          + ISNULL(l.sgstamt,0)
          + ISNULL(l.igstamt,0)
          + ISNULL(l.Tcs_amt,0)
          + ISNULL(l.ADDTAXAMT,0)                                    AS NetAmount
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    LEFT JOIN dbo.PO_PRL prl
        ON prl.divcode = l.DIVCODE
       AND prl.prno    = l.PRNO
       AND CAST(prl.prdate AS DATE) = CAST(l.PRDATE AS DATE)
       AND prl.prsno   = l.PRSNO
    WHERE l.DIVCODE = @DivCode
      AND l.PORDNO  = @PoNo
      AND CAST(l.PORDDT AS DATE) = @PoDate
    ORDER BY l.PORDSNO;

    -- ─── Result set 3: Delivery slots ─────────────────────────────────────────
    SELECT
        d.PORDSNO                                                   AS [LineNo],
        RTRIM(l.ITEMCODE)                                           AS ItemCode,
        RTRIM(ISNULL(i.itemname, ''))                               AS ItemName,
        RTRIM(ISNULL(i.uom, ''))                                    AS Uom,
        l.PRNO                                                      AS PrNo,
        ISNULL(l.ORDqty, 0)                                         AS PoQty,
        ROW_NUMBER() OVER (PARTITION BY d.PORDSNO ORDER BY d.shdate) AS SlotNo,
        CASE WHEN d.shdate IS NULL THEN NULL
             ELSE CONVERT(varchar(10), CAST(d.shdate AS DATE), 120) END AS ShDate,
        ISNULL(d.Quantity, 0)                                       AS Qty,
        ''                                                          AS Remarks
    FROM dbo.PO_ORDL_DETL d
    INNER JOIN dbo.PO_ORDL l
        ON l.DIVCODE = d.divcode AND l.PORDNO = d.pordno
       AND CAST(l.PORDDT AS DATE) = CAST(d.porddt AS DATE)
       AND l.PORDSNO = d.PORDSNO
    INNER JOIN dbo.IN_ITEM i
        ON i.itemcode = l.ITEMCODE
    WHERE d.divcode = @DivCode
      AND d.pordno  = @PoNo
      AND CAST(d.porddt AS DATE) = @PoDate
    ORDER BY d.PORDSNO, d.shdate;
END;
GO
