-- ============================================================
-- ksp_PO_GetPOForAmend
-- Loads ONE Purchase Order for amendment (FN-PO-Amendment v1.2 §1 / §2).
--
-- THREE result sets, consumed by PoAmendmentRepository.GetPOForAmendAsync via
-- QueryMultipleAsync in this exact order:
--   1. header   → PoAmendmentHeaderDto
--   2. lines    → PoAmendmentLineDto        (attached as header.Lines)
--   3. delivery → PoAmendmentDeliverySlotDto(attached as header.Delivery)
--
-- Dapper binds BY NAME. Every alias below is a contract with the DTO — do not
-- rename one without changing the other.
--
-- Type conventions (T-0156 — a DATE/NUMERIC column against a string/int property
-- fails Dapper materialisation at RUNTIME, not compile time):
--   * dates  → CONVERT(VARCHAR(10), col, 120)   (DTO holds string)
--   * SNo    → CAST(... AS INT)                 (DTO holds int)
--   * SlotNo → CAST(... AS INT)
--
-- Line key throughout: DIVCODE + POGRP + PORDNO + PORDDT + PORDSNO + ITEMCODE,
-- matching POGRP as ISNULL(POGRP,'') = ISNULL(@PoGrp,'') per FN §4 (T-0119 item
-- (c) confirmed POGRP is never NULL/blank on live JAT, but the ISNULL match is
-- kept for consistency with the other five PO SPs).
--
-- NEW SP (FN §5) — no legacy SP owns this name; VB6 amdmnt.frm used inline ADO.
-- ⚠️ NOT VERIFIED AGAINST LIVE JAT (read-only SQL login down) — PARSEONLY/deploy first.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_GetPOForAmend
(
    @DivCode VARCHAR(2),
    @PoNo    NUMERIC(10,0),
    @PoDate  DATE,
    @PoGrp   VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Header ────────────────────────────────────────────────────────────
    SELECT  RTRIM(h.DIVCODE)                            AS DivCode,
            h.PORDNO                                    AS PoNo,
            CONVERT(VARCHAR(10), h.PORDDT, 120)         AS PoDate,
            RTRIM(ISNULL(h.POGRP, ''))                  AS PoGroup,
            RTRIM(ISNULL(h.POGRP, ''))                  AS OrderType,
            RTRIM(ISNULL(t.TYPNAME, ''))                AS OrderTypeDesc,
            RTRIM(ISNULL(h.SLCODE, ''))                 AS Supplier,
            RTRIM(ISNULL(s.SLNAME, ''))                 AS SupplierName,
            RTRIM(ISNULL(h.cust_gstinno, ''))           AS Gstin,
            RTRIM(ISNULL(CAST(h.cust_gststcode AS VARCHAR(10)), '')) AS GstState,
            -- Amendment (read-only on the screen)
            h.AMDORDNO                                  AS AmdOrderNo,
            CONVERT(VARCHAR(10), h.AMDORDDT, 120)       AS AmdDate,
            h.REFORDNO                                  AS RefOrderNo,
            CONVERT(VARCHAR(10), h.REFORDDT, 120)       AS RefOrderDate,
            -- Order details
            RTRIM(ISNULL(h.INSPECT, ''))                AS Inspect,
            ISNULL(h.roff, 0)                           AS RoundOff,
            ISNULL(h.ORDVAL, 0)                         AS OrderValue,
            RTRIM(ISNULL(h.Form_type, ''))              AS FormType,
            RTRIM(ISNULL(h.refno, ''))                  AS RefNo,
            CONVERT(VARCHAR(10), h.refDate, 120)        AS RefDate,
            RTRIM(ISNULL(h.CurrCode, ''))               AS Currency,
            ISNULL(h.FCurRate, 0)                       AS CurrRate,
            RTRIM(ISNULL(h.REMARKS, ''))                AS Remarks,
            -- Tax / discount (header)
            0                                           AS CgstPer,   -- header GST % is not stored on PO_ORDH (line-level only)
            0                                           AS SgstPer,
            0                                           AS IgstPer,
            ISNULL(h.htcs_amt, 0)                       AS TcsPer,
            ISNULL(h.DISPER, 0)                         AS DiscPer,
            ISNULL(h.PCKPER, 0)                         AS PackPer,
            ISNULL(h.INSPER, 0)                         AS InsurPer,
            0                                           AS FreightPer, -- PO_ORDH stores the freight AMOUNT, not a %
            ISNULL(h.FREIGHT, 0)                        AS FreightAmt,
            ISNULL(h.Pack_Amt, 0)                       AS PackingAmt,
            ISNULL(h.Ins_Amt, 0)                        AS InsuranceAmt,
            ISNULL(h.ADDTAXPER, 0)                      AS AddTaxPer,
            RTRIM(ISNULL(h.FILENO, ''))                 AS FileNo,
            ISNULL(h.FCACharg, 0)                       AS FcaFob,
            CASE WHEN RTRIM(ISNULL(h.FRTFLG,'')) = 'Y' THEN 'TOPAY' ELSE 'PAID' END AS FreightType,
            CASE WHEN UPPER(RTRIM(ISNULL(h.disflg,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
            CASE WHEN UPPER(RTRIM(ISNULL(h.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
            CASE WHEN UPPER(RTRIM(ISNULL(h.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPosition,
            CASE WHEN UPPER(RTRIM(ISNULL(h.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsurancePosition,
            -- Payment
            CASE WHEN RTRIM(ISNULL(h.PAYMENT,'D')) = 'B' THEN 'BANK' ELSE 'DIRECT' END AS PayMode,
            RTRIM(ISNULL(h.DIRECT_INS, ''))             AS DirectInstr,
            RTRIM(ISNULL(h.BANK_CODE, ''))              AS BankCode,
            RTRIM(ISNULL(h.PAYTERMS, ''))               AS PaymentTerms,
            RTRIM(ISNULL(h.paytermcode, ''))            AS PaymentTermCode,
            ISNULL(h.ADV_PER, 0)                        AS AdvPer,
            ISNULL(h.ADV_AMT, 0)                        AS AdvAmt,
            RTRIM(ISNULL(h.advpaymenttype, ''))         AS ModeOfPayment,
            RTRIM(ISNULL(h.CHQNO, ''))                  AS PayRef,     -- same column as ChequeNo; two display labels, one physical value (matches ksp_PO_GetPOHeader)
            CONVERT(VARCHAR(10), h.CHQDT, 120)          AS PayRefDate,
            RTRIM(ISNULL(h.CHQNO, ''))                  AS ChequeNo,
            CONVERT(VARCHAR(10), h.CHQDT, 120)          AS ChequeDate,
            -- Instructions
            RTRIM(ISNULL(h.CARCODE, ''))                AS Carrier,
            CAST(ISNULL(h.CRDDAYS, 0) AS INT)           AS CreditDays,
            CONVERT(VARCHAR(10), h.Duedate, 120)        AS DueDate,
            RTRIM(ISNULL(h.DEL_INS1, ''))               AS DeliveryLocation,
            RTRIM(ISNULL(h.Billadd, ''))                AS BillingAddress,
            RTRIM(ISNULL(h.SPL_INS, ''))                AS SpecialInstr,
            RTRIM(ISNULL(h.DEL_INS2, ''))               AS Despatch,
            RTRIM(ISNULL(h.Note, ''))                   AS Purpose,
            RTRIM(ISNULL(h.Note2, ''))                  AS OtherLevies,
            RTRIM(ISNULL(h.PriceTerm, ''))               AS PricingTerms,
            RTRIM(ISNULL(h.RemarksPF, ''))               AS PackForwarding,
            RTRIM(ISNULL(h.RemarksIns, ''))              AS Insurance,
            RTRIM(ISNULL(h.RemarksFrt, ''))              AS Freight,
            -- Cancel / status (read-only context)
            RTRIM(ISNULL(h.CANFLG, ''))                 AS CancelFlag,
            CONVERT(VARCHAR(10), h.CANDT, 120)          AS CancelDate,
            RTRIM(ISNULL(h.REMINDER, ''))               AS Reminder,
            RTRIM(ISNULL(h.approved, ''))               AS Approved,
            RTRIM(ISNULL(h.appby, ''))                  AS ApprovedBy,
            RTRIM(ISNULL(h.Conflg, ''))                 AS Conflg,
            -- Audit
            RTRIM(ISNULL(u.user_name, h.createdby))     AS CreatedBy,
            ISNULL(CONVERT(VARCHAR(19), h.createddt, 103), '') AS CreatedDt
    FROM    PO_ORDH h
    LEFT JOIN FA_SLMAS s ON s.SLCODE = h.SLCODE
    -- PO_TYPE's key column is TYPE_CODE. (ksp_PO_GetOrderTypes exposes it as the
    -- alias "PoGrp", which is an OUTPUT name, not the column — do not join on POGRP.)
    LEFT JOIN PO_TYPE  t ON RTRIM(t.TYPE_CODE) = RTRIM(h.POGRP)
    OUTER APPLY (
        SELECT TOP 1 u.user_name
        FROM   PP_PASSWD u
        WHERE  RTRIM(u.user_id) = RTRIM(h.createdby)
          AND  RTRIM(u.divcode)  = RTRIM(h.DIVCODE)
    ) u
    WHERE   h.DIVCODE = @DivCode
      AND   h.PORDNO  = @PoNo
      AND   CAST(h.PORDDT AS DATE) = @PoDate
      AND   (@PoGrp IS NULL OR ISNULL(h.POGRP, '') = ISNULL(@PoGrp, ''));

    -- ── 2. Lines ─────────────────────────────────────────────────────────────
    SELECT  CAST(l.PORDSNO AS INT)                      AS SNo,
            RTRIM(l.ITEMCODE)                           AS ItemCode,
            RTRIM(ISNULL(i.ITEMNAME, ''))               AS ItemName,
            RTRIM(ISNULL(i.UOM, ''))                    AS Uom,
            RTRIM(ISNULL(CAST(l.QUOTNO AS VARCHAR(20)), '')) AS QuotNo,
            ISNULL(CONVERT(VARCHAR(10), l.QUOTDT, 120), '')  AS QuotDate,
            ISNULL(l.PRNO, 0)                           AS PrNo,
            ISNULL(CONVERT(VARCHAR(10), l.PRDATE, 120), '')  AS PrDate,
            ISNULL(l.PRSNO, 0)                          AS PrSno,
            ISNULL(l.Rate, 0)                           AS Rate,
            ISNULL(l.ORDqty, 0)                         AS Qty,
            ISNULL(l.Weight, 0)                         AS Weight,
            ISNULL(l.ORDVAL, 0)                         AS Value,
            ISNULL(l.FRate, 0)                          AS FRate,
            ISNULL(l.FValue, 0)                         AS FValue,
            ISNULL(l.disper, 0)                         AS DiscPer,
            ISNULL(l.disamt, 0)                         AS DiscAmt,
            ISNULL(l.PACKPER, 0)                        AS PackingPer,
            ISNULL(l.Packamt, 0)                        AS PackingAmt,
            ISNULL(l.Frgt1per, 0)                       AS FreightPer,
            ISNULL(l.Frgt1Amt, 0)                       AS FreightAmt,
            ISNULL(l.Ins_per, 0)                        AS InsurancePer,
            ISNULL(l.Ins_amt, 0)                        AS InsuranceAmt,
            ISNULL(l.OTHCHGS, 0)                        AS OtherCharges,
            ISNULL(l.FCACharg, 0)                       AS FcaFob,
            CASE WHEN UPPER(RTRIM(ISNULL(l.DISFLG,   ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS DiscApp,
            CASE WHEN UPPER(RTRIM(ISNULL(l.PACK_FLG, ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS PackApp,
            CASE WHEN UPPER(RTRIM(ISNULL(l.FRT_FLG,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS FreightPos,
            CASE WHEN UPPER(RTRIM(ISNULL(l.Ins_Flg,  ''))) = 'A' THEN 'AFTER' ELSE 'BEFORE' END AS InsuranceDuty,
            RTRIM(ISNULL(l.hsncode, ''))                AS HsnCode,
            RTRIM(ISNULL(l.Tax_code, ''))               AS TaxCode,
            ISNULL(l.taxper, 0)                         AS TaxPer,
            ISNULL(l.Taxamt, 0)                         AS TaxAmt,
            RTRIM(ISNULL(l.cgst_tax_code, ''))          AS CgstCode,
            ISNULL(l.cgstper, 0)                        AS CgstPer,
            ISNULL(l.cgstamt, 0)                        AS CgstAmt,
            RTRIM(ISNULL(l.sgst_tax_code, ''))          AS SgstCode,
            ISNULL(l.sgstper, 0)                        AS SgstPer,
            ISNULL(l.sgstamt, 0)                        AS SgstAmt,
            RTRIM(ISNULL(l.igst_tax_code, ''))          AS IgstCode,
            ISNULL(l.igstper, 0)                        AS IgstPer,
            ISNULL(l.igstamt, 0)                        AS IgstAmt,
            ISNULL(l.Tcs_per, 0)                        AS TcsPer,
            ISNULL(l.Tcs_amt, 0)                        AS TcsAmt,
            RTRIM(ISNULL(l.ADDTAX_CODE, ''))            AS AddTaxCode,
            ISNULL(l.ADDTAXPER, 0)                      AS AddTaxPer,
            ISNULL(l.ADDTAXAMT, 0)                      AS AddTaxAmt,
            ISNULL(l.LANDCOST, 0)                       AS LandingCost,
            ISNULL(l.modvat, 0)                         AS Cenvat,
            ISNULL(l.RCVDQTY, 0)                        AS ReceivedQty,
            ISNULL(l.CANQTY, 0)                         AS CancelQty,
            -- PR remaining balance (qtyreqd - qtyord). Feeds the client-side amend
            -- ceiling (Gap #5): max new qty = current qty + this balance. NULL PR
            -- link → no PR ceiling, returned as a large sentinel so the UI does not
            -- clamp a non-PR line.
            ISNULL(( SELECT ISNULL(p.qtyreqd, 0) - ISNULL(p.QTYORD, 0)
                     FROM PO_PRL p
                     WHERE p.PRNO = l.PRNO AND p.PRDATE = l.PRDATE
                       AND p.DIVCODE = l.DIVCODE AND p.ITEMCODE = l.ITEMCODE
                       AND p.PRSNO = l.PRSNO ), 999999999)  AS PrBalance,
            RTRIM(ISNULL(l.AmedReason, ''))             AS AmendReason,
            RTRIM(ISNULL(l.Remarks, ''))                AS Remarks,
            RTRIM(ISNULL(l.ITEMMEMO, ''))               AS ItemMemo,
            RTRIM(ISNULL(l.reqidpo, ''))                AS RequesterId,
            RTRIM(ISNULL(l.reqnamepo, ''))              AS RequesterName,
            RTRIM(ISNULL(l.DepCode, ''))                AS DepCode
    FROM    PO_ORDL l
    LEFT JOIN IN_ITEM i ON i.ITEMCODE = l.ITEMCODE
    WHERE   l.DIVCODE = @DivCode
      AND   l.PORDNO  = @PoNo
      AND   CAST(l.PORDDT AS DATE) = @PoDate
      AND   (@PoGrp IS NULL OR ISNULL(l.POGRP, '') = ISNULL(@PoGrp, ''))
    ORDER BY l.PORDSNO;

    -- ── 3. Delivery schedule (PO_ORDL_DETL) ──────────────────────────────────
    -- Flat rows keyed by SNo+ItemCode; the client groups them under their line.
    SELECT  CAST(d.pordsno AS INT)                      AS SNo,
            RTRIM(d.itemcode)                           AS ItemCode,
            CAST(ROW_NUMBER() OVER (
                    PARTITION BY d.pordsno, d.itemcode
                    ORDER BY d.shdate) AS INT)          AS SlotNo,
            ISNULL(CONVERT(VARCHAR(10), d.shdate, 120), '') AS ShDate,
            ISNULL(d.Quantity, 0)                       AS Qty
    FROM    PO_ORDL_DETL d
    WHERE   d.divcode = @DivCode
      AND   d.pordno  = @PoNo
      AND   CAST(d.porddt AS DATE) = @PoDate
      AND   (@PoGrp IS NULL OR ISNULL(d.pogrp, '') = ISNULL(@PoGrp, ''))
    ORDER BY d.pordsno, d.shdate;
END;
GO
