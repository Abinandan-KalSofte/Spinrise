-- ============================================================
-- ksp_PO_SupplierWise_Report
-- Returns PO lines for the Supplier-Wise PDF report (JAT).
-- Groups by supplier in the application layer (QuestPDF document).
-- @SupplierCode = NULL returns all suppliers.
-- 06-Jul: reconciled against the legacy Crystal Report source SP
-- (KSP_POLIST_SUPPLIERWISE, supplied by user) after real-data findings
-- showed Carrier Name blank and GST Amount always 0.00. Changes made to
-- match the legacy SP exactly:
--   - Carrier Name now comes from a PO_CAR master join on CARCODE (legacy
--     selects PO_CAR.CARNAME, not a PO_ORDH column - CARNAME doesn't
--     exist on PO_ORDH, confirmed by the earlier SSMS "Invalid column
--     name" error; the previous fix's fallback to CARCODE was still wrong).
--   - GST Amount is cgstamt+sgstamt+igstamt (three tax components summed),
--     not the single TAXAMT column.
--   - PO_ORDH/PO_ORDL join now includes POGRP as a 4th key (matches legacy) -
--     PORDNO repeats across POGRP series (AD/1254 vs CR/1254), so omitting
--     it risked matching the wrong PO_ORDL rows on a shared PORDNO+PORDDT.
--   - CANFLG filter removed - legacy has no cancelled-PO exclusion.
--   - Payment mode is now a strict 2-way map (PAYMENT='D' -> Direct, else
--     -> Bank), matching legacy exactly instead of a 3-way map with a
--     raw-value passthrough branch legacy doesn't have.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SupplierWise_Report
    @Divcode      VARCHAR(2),
    @FromDate     DATETIME,
    @ToDate       DATETIME,
    @SupplierCode VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            RTRIM(ISNULL(h.SLCODE, ''))                       AS SupplierCode,
            RTRIM(ISNULL(sl.SLNAME, ''))                      AS SupplierName,
            -- Matches the legacy Crystal formula exactly: POGRP + "/" + PORDNO when POGRP is set,
            -- else just PORDNO (06-Jul single-supplier finding - prefix was missing entirely).
            CASE
                WHEN RTRIM(ISNULL(h.POGRP, '')) = '' THEN RTRIM(ISNULL(h.PORDNO, ''))
                ELSE RTRIM(h.POGRP) + '/' + RTRIM(ISNULL(h.PORDNO, ''))
            END                                                AS PoNo,
            h.PORDDT                                           AS PoDate,
            CASE
                WHEN ISNULL(TRY_CONVERT(BIGINT, l.PRNO), 0) = 0 THEN ''
                ELSE CONVERT(VARCHAR(20), TRY_CONVERT(BIGINT, l.PRNO))
            END                                                AS PrNo,
            RTRIM(ISNULL(h.QUOTNO, ''))                       AS QuotationNo,
            RTRIM(ISNULL(h.CARCODE, ''))                      AS CarrierCode,
            RTRIM(ISNULL(car.CARNAME, ''))                    AS CarrierName,
            -- Legacy selects DEL_INS2 only (the DEL_INS1 + ' ' + DEL_INS2 concatenation was a
            -- divergence — DateWise/ItemWise were already reverted to DEL_INS2 on 07-Jul).
            RTRIM(ISNULL(h.DEL_INS2, ''))                     AS DeliveryInstructions,
            RTRIM(ISNULL(h.SPL_INS, ''))                      AS SpecialInstructions,
            h.DUEDATE                                          AS DueDate,
            l.ITEMCODE                                         AS ItemCode,
            RTRIM(ISNULL(itm.ITEMNAME, ''))                   AS ItemName,
            RTRIM(ISNULL(itm.UOM, ''))                        AS Uom,
            ISNULL(l.RATE, 0)                                 AS Rate,
            ISNULL(l.ORDQTY, 0)                               AS QtyOrdered,
            ISNULL(l.ORDVAL, 0)                               AS LineValue,
            ISNULL(l.cgstamt, 0) + ISNULL(l.sgstamt, 0) + ISNULL(l.igstamt, 0) AS TaxAmount,
            ISNULL(h.ORDVAL, 0)                               AS OrderValue,
            ISNULL(h.ADV_PER, 0)                              AS AdvancePercent,
            ISNULL(h.ADV_AMT, 0)                              AS AdvanceAmount,
            -- Legacy balamt: no advance -> the LINE value; with an advance -> the HEADER value
            -- less the advance. Was an unconditional (h.ORDVAL - h.ADV_AMT), which diverged
            -- whenever ADV_AMT = 0.
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
        INNER JOIN dbo.PO_CAR car
            ON  h.CARCODE = car.CARCODE
        INNER JOIN dbo.PP_DIVMAS div
            ON  h.DIVCODE = div.DIVCODE
        INNER JOIN dbo.IN_ITEM itm
            ON  l.ITEMCODE = itm.ITEMCODE
        WHERE h.DIVCODE = @Divcode
          AND CAST(h.PORDDT AS DATE) BETWEEN @FromDate AND @ToDate
          AND (@SupplierCode IS NULL OR RTRIM(h.SLCODE) = RTRIM(@SupplierCode))
        ORDER BY RTRIM(ISNULL(sl.SLNAME, '')), h.PORDDT DESC, h.PORDNO, l.ITEMCODE;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
