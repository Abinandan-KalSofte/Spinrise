-- ============================================================
-- ksp_PO_DeptWise_Report
-- Returns PO lines for the Department-Wise PDF report (JAT).
-- Groups by department in the application layer (QuestPDF document).
-- @DepCode = NULL returns all departments.
-- 06-Jul: implemented against LIVE JAT schema (the earlier draft used
-- columns that do not exist there — verified via sys.columns):
--   - Department lives on the LINE (PO_ORDL.DepCode), NOT PO_ORDH —
--     PO_ORDH has no DEPCODE column at all.
--   - Received qty column is PO_ORDL.RCVDQTY (not RECQTY).
--   - GST Amount is cgstamt+sgstamt+igstamt summed — PO_ORDL.TAXAMT is
--     under-populated on live data (216/662 nonzero for 2026 vs 622/662
--     for the components), same finding as the Supplier-Wise reconciliation.
--   - PO_ORDH/PO_ORDL join includes POGRP as a 4th key (PORDNO repeats
--     across POGRP series) and PoNo carries the POGRP prefix, matching
--     the Supplier-Wise reconciled SP.
--   - Header fields (Quotation, Carrier, Advance, Payment, Delivery/
--     Special instructions, Due date, Crd-Days) supplied because the
--     PoDeptwiseDocument row layout renders them.
--   - NOTE (data reality, not a defect): PO_ORDL.DepCode is NULL on most
--     recent JAT lines — those rows group under a blank department.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_DeptWise_Report
    @Divcode  VARCHAR(2),
    @FromDate DATETIME,
    @ToDate   DATETIME,
    @DepCode  VARCHAR(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            h.DIVCODE                                          AS DivCode,
            RTRIM(ISNULL(l.DepCode, ''))                      AS DepCode,
            RTRIM(ISNULL(dep.DEPNAME, ''))                    AS DepName,
            CASE
                WHEN RTRIM(ISNULL(h.POGRP, '')) = '' THEN RTRIM(ISNULL(h.PORDNO, ''))
                ELSE RTRIM(h.POGRP) + '/' + RTRIM(ISNULL(h.PORDNO, ''))
            END                                                AS PoNo,
            h.PORDDT                                           AS PoDate,
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.RCVDQTY, 0)                              AS QtyReceived,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            RTRIM(ISNULL(h.POGRP, ''))                        AS OrderType,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            CASE
                WHEN RTRIM(ISNULL(h.PAYMENT, '')) = 'D' THEN 'Direct'
                ELSE 'Bank'
            END                                                AS PaymentMode,
            RTRIM(ISNULL(h.DEL_INS1, '')) + ' ' + RTRIM(ISNULL(h.DEL_INS2, '')) AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.Duedate                                          AS DueDate,
            ISNULL(h.CRDDAYS, 0)                              AS CrdDays,
            CASE
                WHEN ISNULL(h.Conflg, 'N') = 'Y'
                  THEN 'CONFIRMED'
                WHEN ISNULL(h.FirstlevelApp, 'N') = 'Y'
                  THEN 'First Level Approved'
                ELSE 'PENDING'
            END                                                AS ApprovalStatus,
            RTRIM(ISNULL(div.div_printname, div.DIVNAME))    AS DivPrintName,
            RTRIM(ISNULL(div.div_unitname, ''))               AS DivUnitName
        FROM dbo.PO_ORDH h
        INNER JOIN dbo.PO_ORDL l
            ON  h.DIVCODE = l.DIVCODE
            AND h.PORDNO  = l.PORDNO
            AND CAST(h.PORDDT AS DATE) = CAST(l.PORDDT AS DATE)
            AND h.POGRP   = l.POGRP
        LEFT  JOIN dbo.FA_SLMAS sl
            ON  RTRIM(sl.SLCODE) = RTRIM(h.SLCODE)
        LEFT  JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        LEFT  JOIN dbo.IN_DEP dep
            ON  l.DepCode  = dep.DEPCODE
            AND h.DIVCODE  = dep.divcode
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
          AND ISNULL(h.CANFLG, '') = ''
          AND (@DepCode IS NULL OR RTRIM(l.DepCode) = RTRIM(@DepCode))
        ORDER BY RTRIM(ISNULL(dep.DEPNAME, '')), h.PORDDT DESC, h.PORDNO, l.ITEMCODE;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
