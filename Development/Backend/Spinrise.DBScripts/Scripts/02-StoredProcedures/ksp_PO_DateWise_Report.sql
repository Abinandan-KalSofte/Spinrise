-- ============================================================
-- ksp_PO_DateWise_Report
-- Returns PO lines for the Date-Wise PDF report (JAT database).
-- Groups by PO date in the application layer (QuestPDF document).
-- Column names verified against the live schema (2026-07-03) — several
-- earlier aliases (TAX_AMT, ADVPER, ADVAMT, PAYMODE, DELINST, SPINST,
-- CARNAME) did not exist and would have failed to compile.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DateWise_Report
    @Divcode  VARCHAR(2),
    @FromDate DATETIME,
    @ToDate   DATETIME
AS
-- 07-Jul VB6-parity pass (task/abinandan/POList-DateWise-ItemWise-VB6-Parity):
-- BalanceAmount reverted to VB6's line-level conditional formula; PAYMENT reverted to
-- VB6's 2-way case; DeliveryInstructions reverted to DEL_INS2 only; CANFLG exclusion and
-- LEFT JOINs on FA_SLMAS/PO_CAR reverted to VB6's INNER JOINs (row-set parity, user-approved
-- deviation from the prior session's "defensive" version); ORDER BY reverted to PORDDT only.
-- GST/CarrierName/PrNo fixes from 06-Jul are genuine data-correctness fixes and are KEPT.
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.PORDDT                                           AS PoDate,
            RTRIM(ISNULL(h.PORDNO, ''))                       AS PoNo,
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            RTRIM(ISNULL(dep.DEPNAME, ''))                    AS DepName,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            -- 11-Jul true-source parity (Reports_Vb6\new\PO-Datewise.rpt +
            -- "Script for po reports.txt"): the report's "Order Value" column binds to
            -- {ORDVAL} = the HEADER order value (PO_ORDH.ORDVAL), shown once per PO; the
            -- "Item Value" column binds to {poitemvalue} = line ORDVAL (= LineValue above).
            ISNULL(h.ORDVAL, 0)                               AS HeaderOrderValue,
            -- 06-Jul: GST = cgstamt+sgstamt+igstamt summed — TAXAMT is under-populated
            -- on live JAT (216/662 nonzero for 2026 vs 622/662 for the components);
            -- same real-data finding as the Supplier-Wise reconciliation.
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            RTRIM(ISNULL(h.POGRP, ''))                        AS OrderType,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            -- Legacy balamt: no advance -> the LINE value; with an advance -> the HEADER value
            -- less the advance (the two branches deliberately read different tables).
            CASE
                WHEN ISNULL(h.ADV_AMT, 0) = 0 THEN l.ORDVAL
                ELSE (h.ORDVAL - h.ADV_AMT)
            END                                                AS BalanceAmount,
            CASE
                WHEN RTRIM(ISNULL(h.PAYMENT, '')) = 'D' THEN 'Direct'
                ELSE 'Bank'
            END                                                AS PaymentMode,
            0                                                   AS DelDays,
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            RTRIM(ISNULL(h.CARCODE, ''))                      AS CarrierCode,
            -- 06-Jul: CARNAME comes from the PO_CAR master — CARCODE was being echoed
            -- back as the name, so the print showed codes ("AAZ") instead of names.
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            -- PR No is the purchase-requisition number the PO LINE was raised from.
            -- It lives on the line table (PO_ORDL.PRNO), NOT the header — a single PO can
            -- pull lines from several PRs, so this must come from l.*, not h.*. (Previously
            -- this was mistakenly aliased from h.PORDNO, which just echoed the PO number.)
            -- TRY_CONVERT keeps the SP safe whether PRNO is stored numeric or varchar; a
            -- 0/NULL PRNO (direct PO, not raised from a PR) renders as blank.
            CASE
                WHEN ISNULL(TRY_CONVERT(BIGINT, l.PRNO), 0) = 0 THEN ''
                ELSE CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, l.PRNO))
            END                                                AS PrNo,
            RTRIM(ISNULL(h.DEL_INS2, ''))                     AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.Duedate                                          AS DueDate,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName
        FROM dbo.PO_ORDH h
        INNER JOIN dbo.PO_ORDL l
            ON  h.DIVCODE = l.DIVCODE
            AND h.PORDNO  = l.PORDNO
            AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
            AND h.POGRP   = l.POGRP
        INNER JOIN dbo.FA_SLMAS sl
            ON  RTRIM(sl.SLCODE) = RTRIM(h.SLCODE)
        INNER JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        LEFT  JOIN dbo.IN_DEP dep
            ON  l.DepCode = dep.DEPCODE
            AND h.DIVCODE = dep.DIVCODE
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
        ORDER BY h.PORDDT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
