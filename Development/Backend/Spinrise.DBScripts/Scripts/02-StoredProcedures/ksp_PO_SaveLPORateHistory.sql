-- ============================================================
-- ksp_PO_SaveLPORateHistory  (SP #15)
-- Records LPO rate history in PO_LPORATEAPP after every Add save.
-- Always active — no activation flag (FSD §8.4 / §1368).
-- Called once per PO line from PoEntryRepository after ksp_PO_SaveEntry.
-- CDOCNO = MAX+1 per division (D-14: non-atomic; medium impact).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SaveLPORateHistory
(
    @DivCode   VARCHAR(5),
    @PoNo      NUMERIC(10,0),
    @PoDate    DATE,
    @OrderType VARCHAR(5),
    @Supplier  VARCHAR(10),
    @ItemCode  VARCHAR(10),
    @Qty       NUMERIC(12,3),
    @Rate      NUMERIC(13,4),
    @UserId    VARCHAR(15)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewCDocNo   NUMERIC(10,0);
    DECLARE @LPoRdNo     NUMERIC(10,0);
    DECLARE @LPoRdDt     DATE;
    DECLARE @LPoGrp      VARCHAR(5);
    DECLARE @LSlCode     VARCHAR(10);
    DECLARE @LRate       NUMERIC(13,4);

    -- CDOCNO = MAX+1 for this division (D-14: use SEQUENCE in future sprint)
    SELECT @NewCDocNo = ISNULL(MAX(CDOCNO), 0) + 1
    FROM dbo.PO_LPORATEAPP
    WHERE RTRIM(ISNULL(DIVCODE, '')) = RTRIM(@DivCode);

    -- Previous most-recent PO for the same item in this division (excluding current PO)
    SELECT TOP 1
        @LPoRdNo = h.PORDNO,
        @LPoRdDt = CAST(h.PORDDT AS DATE),
        @LPoGrp  = RTRIM(ISNULL(h.ORDTYPE, '')),
        @LSlCode = RTRIM(ISNULL(h.SLCODE,  '')),
        @LRate   = l.RATE
    FROM dbo.PO_ORDL l
    INNER JOIN dbo.PO_ORDH h
        ON  h.PORDNO  = l.PORDNO
        AND h.PORDDT  = l.PORDDT
        AND h.DIVCODE = l.DIVCODE
    WHERE RTRIM(ISNULL(l.ITEMCODE, '')) = RTRIM(@ItemCode)
      AND RTRIM(ISNULL(h.DIVCODE,  '')) = RTRIM(@DivCode)
      AND h.PORDNO <> @PoNo
    ORDER BY h.PORDDT DESC, h.PORDNO DESC;

    INSERT INTO dbo.PO_LPORATEAPP
    (
        DIVCODE,    CDOCNO,
        LPORDNO,    LPORDDT,   LPOGRP,    LSLCODE,
        ITEMCODE,   CQUANTITY, LRATE,
        CDATE,      CSLCODE,   CPOGRP,    CRATE,
        CREATEDBY,  CREATEDDATE
    )
    VALUES
    (
        RTRIM(@DivCode),    @NewCDocNo,
        @LPoRdNo,           @LPoRdDt,   @LPoGrp,          @LSlCode,
        RTRIM(@ItemCode),   @Qty,        @LRate,
        GETDATE(),          RTRIM(@Supplier), RTRIM(@OrderType), @Rate,
        RTRIM(@UserId),     GETDATE()
    );
END;
GO
