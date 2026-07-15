-- ============================================================
-- ksp_PO_ItemWise_Report
-- Returns PO lines for the Item-Wise PDF report (JAT database).
-- Groups by item in the application layer (QuestPDF document).
-- @FItem/@TItem = 'A' means "all items" (matches the repository's
-- fetchAll convention); otherwise an alphabetical item-code range.
-- Column names mirror the confirmed-correct live schema used by
-- ksp_PO_DateWise_Report (TAXAMT, ADV_PER, ADV_AMT, PAYMENT, CARCODE,
-- DEL_INS1/DEL_INS2, SPL_INS) — the previous version of this SP was an
-- unimplemented placeholder (SELECT TOP 0 ... WHERE 1=0).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_ItemWise_Report
    @Divcode  VARCHAR(2),
    @FromDate VARCHAR(10),
    @ToDate   VARCHAR(10),
    @FItem    VARCHAR(20) = 'A',
    @TItem    VARCHAR(20) = 'A',
    -- VB6's @Opt confirm-status filter, restored: 'A'=all, 'Y'=confirmed, 'N'=not confirmed
    -- (PO_ORDH.CONFLG domain confirmed via ksp_PO_SetFinalApproval.sql / ksp_PO_GetApprovalStatus.sql).
    @Opt      VARCHAR(15) = 'A'
AS
-- 07-Jul VB6-parity pass (task/abinandan/POList-DateWise-ItemWise-VB6-Parity):
-- BalanceAmount reverted to VB6's line-level conditional formula; PAYMENT reverted to
-- VB6's 2-way case; DeliveryInstructions reverted to DEL_INS2 only; CANFLG exclusion and
-- LEFT JOINs on FA_SLMAS/PO_CAR reverted to VB6's INNER JOINs (row-set parity, user-approved
-- deviation from the prior session's "defensive" version); ORDER BY reverted to PORDDT only;
-- @Opt confirm-status filter restored (was dropped when this SP was rewritten from its
-- SELECT TOP 0 stub); PrNo added (confirmed real vs VB6). GST/CarrierName fixes from 06-Jul
-- are genuine data-correctness fixes and are KEPT.
-- 11-Jul true-source parity, per Reports_Vb6\new\ (PO-Itemwise.rpt bindings + the legacy SP in
-- "Script for po reports.txt"). The .rpt binds "Order Value"={ORDVAL} and "Item Value"=
-- {poitemvalue}; the legacy SP selects `PO_ORDh."ordval" as ORDVAL` + `isnull(po_ordl.ordval,0)
-- as poitemvalue` => Order Value = HEADER PO_ORDH.ORDVAL (once per PO), Item Value = LINE
-- PO_ORDL.ORDVAL (summed per line). NOTE: an earlier revision of that script aliased ORDVAL from
-- PO_ORDL.LANDCOST; the 11-Jul 12:31 update replaced it with the header value, so LANDCOST is NOT
-- used by this report. Same rule now holds across all three PO List reports.
-- balamt: ADV_AMT=0 -> line ORDVAL, else HEADER ORDVAL - ADV_AMT (matches the legacy CASE).
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            RTRIM(ISNULL(h.PORDNO, ''))                       AS PoNo,
            h.PORDDT                                           AS PoDate,
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            RTRIM(ISNULL(dep.DEPNAME, ''))                    AS DepName,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            -- 11-Jul true-source parity (Reports_Vb6\new\PO-Itemwise.rpt +
            -- "Script for po reports.txt"): the report's "Order Value" column binds to
            -- {ORDVAL}, which the legacy SP now aliases from the HEADER order value
            -- (`PO_ORDh."ordval" as ORDVAL`) — shown once per PO. The "Item Value" column
            -- binds to {poitemvalue} = line ORDVAL (= LineValue above), summed per line.
            ISNULL(h.ORDVAL, 0)                               AS HeaderOrderValue,
            -- 06-Jul: GST = cgstamt+sgstamt+igstamt summed — TAXAMT is under-populated
            -- on live JAT; same real-data finding as the Supplier-Wise reconciliation.
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
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            -- 06-Jul: CARNAME from the PO_CAR master — CARCODE was echoed as the name.
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            RTRIM(ISNULL(h.DEL_INS2, ''))                     AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.Duedate                                          AS DueDate,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName,
            -- PR No — same source/logic as ksp_PO_DateWise_Report (l.PRNO, not header).
            CASE
                WHEN ISNULL(TRY_CONVERT(BIGINT, l.PRNO), 0) = 0 THEN ''
                ELSE CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, l.PRNO))
            END                                                AS PrNo
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
          AND (@FItem = 'A' OR l.ITEMCODE BETWEEN @FItem AND @TItem)
          AND (@Opt = 'A' OR (@Opt <> 'A' AND ISNULL(h.CONFLG, 'N') = @Opt))
        ORDER BY h.PORDDT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
