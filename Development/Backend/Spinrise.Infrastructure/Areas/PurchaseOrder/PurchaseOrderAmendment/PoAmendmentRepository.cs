using System.Data;
using System.Text.Json;
using Dapper;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseOrderAmendment;

// Dapper data access for PO Amendment. Mirrors PoCancellationRepository /
// PoForeclosureRepository: JSON-TVP save with explicit camelCase keys matching the
// SP's OPENJSON paths, no @Result output param. JAT DB resolved per-request via the
// JWT claim inside IUnitOfWork (the codebase has no IJATUnitOfWork type; all PO code
// uses IUnitOfWork). The 6 SPs are Mariyaiya's (CEO 12-Jul) — not yet authored; this
// calls them contract-first by the StoredProcedures.Po.Amendment names.
public class PoAmendmentRepository : IPoAmendmentRepository
{
    private readonly IUnitOfWork _uow;

    public PoAmendmentRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<AmendablePoSummaryDto>> GetAmendablePOListAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<AmendablePoSummaryDto>(
            StoredProcedures.Po.Amendment.GetAmendablePOList,
            new { divCode, yfDate, ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PoAmendmentHeaderDto?> GetPOForAmendAsync(
        string divCode, decimal poNo, string poDate, string poGrp)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.Po.Amendment.GetPOForAmend,
            new { divCode, poNo, poDate, poGrp },
            commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<PoAmendmentHeaderDto>();
        if (header is null) return null;

        header.Lines    = (await multi.ReadAsync<PoAmendmentLineDto>()).ToList();
        header.Delivery = (await multi.ReadAsync<PoAmendmentDeliverySlotDto>()).ToList();
        return header;
    }

    public async Task<IEnumerable<AmendmentSummaryDto>> GetAmendmentListAsync(
        string divCode, DateTime yfDate, DateTime ylDate)
    {
        return await _uow.Connection.QueryAsync<AmendmentSummaryDto>(
            StoredProcedures.Po.Amendment.GetAmendmentList,
            new { divCode, yfDate, ylDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> SaveAmendmentAsync(
        AmendmentSaveRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        // Explicit camelCase keys → must match the SP's OPENJSON WITH paths exactly.
        var headerJson = JsonSerializer.Serialize(new
        {
            poNo           = request.PoNo,
            poDate         = request.PoDate,
            poGrp          = request.PoGroup,
            carrier        = request.Carrier,
            // Unlocked by the 13-Jul ruling (header follows VB6; grid keeps FN §1's locks).
            supplier       = request.Supplier,
            gstin          = request.Gstin,
            gstState       = request.GstState,
            inspect        = request.Inspect,
            formType       = request.FormType,
            currency       = request.Currency,
            currRate       = request.CurrRate,
            remarks        = request.Remarks,
            refNo          = request.RefNo,
            refDate        = request.RefDate,
            fileNo         = request.FileNo,
            paymentTerms   = request.PaymentTerms,
            creditDays     = request.CreditDays,
            bankCode       = request.BankCode,
            payMode        = request.PayMode,
            directInstr    = request.DirectInstr,
            advPer         = request.AdvPer,
            advAmt         = request.AdvAmt,
            chequeNo       = request.ChequeNo,
            chequeDate     = request.ChequeDate,
            deliveryInstr1 = request.DeliveryInstr1,
            deliveryInstr2 = request.DeliveryInstr2,
            specialInstr   = request.SpecialInstr,
            dueDate        = request.DueDate,
            roundOff       = request.RoundOff,
            discPer        = request.DiscPer,
            packPer        = request.PackPer,
            insurPer       = request.InsurPer,
            freightAmt     = request.FreightAmt,
            packingAmt     = request.PackingAmt,
            insuranceAmt   = request.InsuranceAmt,
            addTaxPer      = request.AddTaxPer,
            freightType    = request.FreightType,
            discApp        = request.DiscApp,
            packApp        = request.PackApp,
            freightPosition   = request.FreightPosition,
            insurancePosition = request.InsurancePosition,
        });

        // Explicit camelCase keys → match the SP's OPENJSON WITH paths.
        var linesJson = JsonSerializer.Serialize(request.Lines.Select(l => new
        {
            sNo           = l.SNo,
            itemCode      = l.ItemCode,
            prNo          = l.PrNo,
            prDate        = l.PrDate,
            prSno         = l.PrSno,
            rate          = l.Rate,
            qty           = l.Qty,
            weight        = l.Weight,
            discPer       = l.DiscPer,
            packingPer    = l.PackingPer,
            freightPer    = l.FreightPer,
            insurancePer  = l.InsurancePer,
            otherCharges  = l.OtherCharges,
            discApp       = l.DiscApp,
            packApp       = l.PackApp,
            freightPos    = l.FreightPos,
            insuranceDuty = l.InsuranceDuty,
            taxCode       = l.TaxCode,
            hsnCode       = l.HsnCode,
            cgstCode      = l.CgstCode,
            sgstCode      = l.SgstCode,
            igstCode      = l.IgstCode,
            tcsPer        = l.TcsPer,
            addTaxCode    = l.AddTaxCode,
            addTaxPer     = l.AddTaxPer,
            remarks       = l.Remarks,
            itemMemo      = l.ItemMemo,
            amendReason   = l.AmendReason,
            slots = (l.Slots ?? []).Select(s => new
            {
                slotNo = s.SlotNo,
                shDate = s.ShDate,
                qty    = s.Qty,
            }),
        }));

        var amendNo = await _uow.Connection.ExecuteScalarAsync<int>(
            StoredProcedures.Po.Amendment.AmendOrder,
            new
            {
                divCode,
                transDate,
                userId,
                hostName  = hostName  ?? string.Empty,
                ipAddress = ipAddress ?? string.Empty,
                headerJson,
                linesJson,
            },
            commandType: CommandType.StoredProcedure);

        return amendNo;
    }

    public async Task DeleteOrderAsync(
        DeleteOrderRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.Amendment.DeleteOrder,
            new
            {
                divCode,
                poNo      = request.PoNo,
                poDate    = request.PoDate,
                poGrp     = request.PoGroup,
                transDate,
                userId,
                hostName  = hostName  ?? string.Empty,
                ipAddress = ipAddress ?? string.Empty,
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task DeleteLinesAsync(
        DeleteLinesRequestDto request, string divCode, DateTime transDate,
        string userId, string? hostName, string? ipAddress)
    {
        var linesJson = JsonSerializer.Serialize(request.Lines.Select(l => new
        {
            sNo      = l.SNo,
            itemCode = l.ItemCode,
        }));

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.Amendment.DeleteLines,
            new
            {
                divCode,
                poNo      = request.PoNo,
                poDate    = request.PoDate,
                poGrp     = request.PoGroup,
                transDate,
                userId,
                hostName  = hostName  ?? string.Empty,
                ipAddress = ipAddress ?? string.Empty,
                linesJson,
            },
            commandType: CommandType.StoredProcedure);
    }
}
