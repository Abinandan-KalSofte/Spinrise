using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;
using Spinrise.Shared.Models;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.PoEntry;

// TODO: Verify all column names against live JAT schema (PO_ORDH, PO_ORDL, PO_ORDL_DETL, etc.)
//       before deploying SPs to production.
public class PoEntryRepository : IPoEntryRepository
{
    private readonly IUnitOfWork _uow;

    public PoEntryRepository(IUnitOfWork uow)
    {
        _uow = uow;
    }

    public async Task<PoParametersDto?> GetParametersAsync(string divCode)
    {
        return await _uow.Connection.QueryFirstOrDefaultAsync<PoParametersDto>(
            StoredProcedures.Po.GetParameters,
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PoPreAddChecksDto> GetPreAddChecksAsync(string divCode)
    {
        return await _uow.Connection.QueryFirstAsync<PoPreAddChecksDto>(
            StoredProcedures.Po.GetPreAddChecks,
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PoUserPermissionsDto> GetUserPermissionsAsync(string userId, string divCode)
    {
        return await _uow.Connection.QueryFirstOrDefaultAsync<PoUserPermissionsDto>(
            StoredProcedures.Po.GetUserLevel,
            new { UserId = userId, DivCode = divCode },
            commandType: CommandType.StoredProcedure)
            ?? new PoUserPermissionsDto();
    }

    public async Task<IEnumerable<SupplierOptionDto>> GetSuppliersAsync(string divCode, string? search)
    {
        return await _uow.Connection.QueryAsync<SupplierOptionDto>(
            StoredProcedures.Po.GetSuppliers,
            new { DivCode = divCode, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<OrderTypeOptionDto>> GetOrderTypesAsync(bool activeOnly)
    {
        return await _uow.Connection.QueryAsync<OrderTypeOptionDto>(
            StoredProcedures.Po.GetOrderTypes,
            new { ActiveOnly = activeOnly ? 1 : 0 },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<CarrierOptionDto>> GetCarriersAsync(string? search)
    {
        return await _uow.Connection.QueryAsync<CarrierOptionDto>(
            StoredProcedures.Po.GetCarriers,
            new { Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<BankOptionDto>> GetBanksAsync(string divCode, string? search)
    {
        return await _uow.Connection.QueryAsync<BankOptionDto>(
            StoredProcedures.Po.GetBanks,
            new { DivCode = divCode, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<FormTypeOptionDto>> GetFormTypesAsync()
    {
        return await _uow.Connection.QueryAsync<FormTypeOptionDto>(
            StoredProcedures.Po.GetFormTypes,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<GstTaxCodeOptionDto>> GetGstTaxCodesAsync(string? search)
    {
        return await _uow.Connection.QueryAsync<GstTaxCodeOptionDto>(
            StoredProcedures.Po.GetGstTaxCodes,
            new { Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<GstRoutingResultDto> GetGstRoutingAsync(string divCode, string slCode)
    {
        return await _uow.Connection.QueryFirstAsync<GstRoutingResultDto>(
            StoredProcedures.Po.GetGstRouting,
            new { DivCode = divCode, SlCode = slCode },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<AddressOptionDto>> GetAddressesAsync(string divCode, string kind, string? search)
    {
        return await _uow.Connection.QueryAsync<AddressOptionDto>(
            StoredProcedures.Po.GetAddresses,
            new { DivCode = divCode, Kind = kind, Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<CurrencyOptionDto>> GetCurrenciesAsync(string? search)
    {
        return await _uow.Connection.QueryAsync<CurrencyOptionDto>(
            StoredProcedures.Po.GetCurrencies,
            new { Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<AddressOptionDto>> GetPricingTermsAsync(string? search)
    {
        return await _uow.Connection.QueryAsync<AddressOptionDto>(
            StoredProcedures.Po.GetPricingTerms,
            new { Search = search },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PayTermOptionDto>> GetPayTermsAsync()
    {
        return await _uow.Connection.QueryAsync<PayTermOptionDto>(
            StoredProcedures.Po.GetPayTerms,
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<EligiblePrLineDto>> GetEligiblePrLinesAsync(
        string divCode, string? orderType, string? search, int page, int pageSize)
    {
        return await _uow.Connection.QueryAsync<EligiblePrLineDto>(
            StoredProcedures.Po.GetEligiblePrLines,
            new { DivCode = divCode, OrderType = orderType, Search = search, PageNumber = page, PageSize = pageSize },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<PoSummaryDto>> GetListAsync(
        string divCode, DateOnly fDate, DateOnly lDate, string? search, string? supplier, int page, int pageSize)
    {
        return await _uow.Connection.QueryAsync<PoSummaryDto>(
            StoredProcedures.Po.GetList,
            new { DivCode = divCode, FDate = fDate, LDate = lDate, Search = search, Supplier = supplier, Page = page, PageSize = pageSize },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PoHeaderDto?> GetByIdAsync(string divCode, decimal poNo, DateOnly poDate)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.Po.GetById,
            new { DivCode = divCode, PoNo = poNo, PoDate = poDate },
            commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<PoHeaderDto>();
        if (header is null) return null;

        header.Lines    = (await multi.ReadAsync<PoLineDto>()).ToList();
        header.Delivery = await ReadDeliveryAsync(multi);
        return header;
    }

    public async Task<PoHeaderDto?> GetLastRecordAsync(string divCode, DateOnly fDate, DateOnly lDate)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.Po.GetLastRecord,
            new { DivCode = divCode, FDate = fDate, LDate = lDate },
            commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<PoHeaderDto>();
        if (header is null) return null;

        header.Lines    = (await multi.ReadAsync<PoLineDto>()).ToList();
        header.Delivery = await ReadDeliveryAsync(multi);
        return header;
    }

    public async Task<PoSaveResultDto> SaveAsync(string divCode, AddPoRequest request,
        string userId, string? hostName, string? ipAddress, DateOnly fDate, DateOnly lDate)
    {
        // CR-006: zero out IGST for LOCAL route, zero out CGST/SGST for IGST route.
        var linesJson = JsonSerializer.Serialize(
            request.Lines.Select(l => new
            {
                prNo          = l.PrNo,
                prSno         = l.PrSno,
                prDate        = l.PrDate,
                itemCode      = l.ItemCode,
                rate          = l.Rate,
                qty           = l.Qty,
                taxCode       = l.TaxCode,
                hsnCode       = l.HsnCode,
                cgstPer       = l.Route == "IGST" ? 0m : l.CgstPer,
                sgstPer       = l.Route == "IGST" ? 0m : l.SgstPer,
                igstPer       = l.Route == "LOCAL" ? 0m : l.IgstPer,
                tcsPer        = l.TcsPer,
                cgstCode      = l.Route == "IGST" ? "" : l.CgstCode,
                sgstCode      = l.Route == "IGST" ? "" : l.SgstCode,
                igstCode      = l.Route == "LOCAL" ? "" : l.IgstCode,
                requesterId   = l.RequesterId,
                requesterName = l.RequesterName,
                discPer       = l.DiscPer,
                packingPer    = l.PackingPer,
                freightPer    = l.FreightPer,
                insurancePer  = l.InsurancePer,
                cessPer       = l.CessPer,
                fcaFob        = l.FcaFob,
                otherCharges  = l.OtherCharges,
                addTaxCode    = l.AddTaxCode,
                addTaxPer     = l.AddTaxPer,
                discApp       = l.DiscApp,
                packApp       = l.PackApp,
                freightPos    = l.FreightPos,
                insuranceDuty = l.InsuranceDuty,
                cessTaxPos    = l.CessTaxPos,
                slots         = l.Slots.Select(s => new { shDate = s.ShDate, qty = s.Qty }),
            }),
            new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

        var p = new DynamicParameters();
        p.Add("DivCode",         divCode);
        p.Add("PoDate",          request.PoDate);
        p.Add("OrderType",       request.Header.OrderType);
        p.Add("Supplier",        request.Header.Supplier);
        p.Add("Currency",        request.Header.Currency);
        p.Add("CurrRate",        request.Header.CurrRate);
        p.Add("Carrier",         request.Header.Carrier);
        p.Add("Inspect",         request.Header.Inspect);
        p.Add("FormType",        request.Header.FormType);
        p.Add("RefNo",           request.Header.RefNo);
        p.Add("RefDate",         request.Header.RefDate);
        p.Add("Remarks",         request.Header.Remarks);
        p.Add("CgstPer",         request.Header.CgstPer);
        p.Add("SgstPer",         request.Header.SgstPer);
        p.Add("IgstPer",         request.Header.IgstPer);
        p.Add("TcsPer",          request.Header.TcsPer);
        p.Add("DiscPer",         request.Header.DiscPer);
        p.Add("CessPer",         request.Header.CessPer);
        p.Add("AedPer",          request.Header.AedPer);
        p.Add("FreightAmt",      request.Header.FreightAmt);
        p.Add("FreightPer",      request.Header.FreightPer);
        p.Add("PackPer",         request.Header.PackPer);
        p.Add("InsurPer",        request.Header.InsurPer);
        p.Add("SurchargePer",    request.Header.SurchargePer);
        p.Add("AddTaxPer",       request.Header.AddTaxPer);
        p.Add("FileNo",          request.Header.FileNo);
        p.Add("FcaFob",          request.Header.FcaFob);
        p.Add("FreightType",          request.Header.FreightType);
        p.Add("DiscApp",              request.Header.DiscApp);
        p.Add("PackApp",              request.Header.PackApp);
        p.Add("FreightPosition",      request.Header.FreightPosition);
        p.Add("InsurancePosition",    request.Header.InsurancePosition);
        p.Add("CessApp",              request.Header.CessPosition);
        p.Add("PayMode",         request.Header.PayMode);
        p.Add("DirectInstr",     request.Header.DirectInstr);
        p.Add("BankCode",        request.Header.BankCode);
        p.Add("PaymentTerms",    request.Header.PaymentTerms);
        p.Add("PayTermCode",     request.Header.PaymentTermCode);
        p.Add("AdvPer",          request.Header.AdvPer);
        p.Add("AdvAmt",          request.Header.AdvAmt);
        p.Add("ModeOfPayment",   request.Header.ModeOfPayment);
        p.Add("PayRef",          request.Header.PayRef);
        p.Add("PayRefDate",      request.Header.PayRefDate);
        p.Add("ChequeNo",        request.Header.ChequeNo);
        p.Add("ChequeDate",      request.Header.ChequeDate);
        p.Add("CreditDays",      request.Header.CreditDays);
        p.Add("DeliveryDate",    request.Header.DeliveryDate);
        p.Add("DeliveryLocation",request.Header.DeliveryLocation);
        p.Add("BillingAddress",  request.Header.BillingAddress);
        p.Add("SpecialInstr",    request.Header.SpecialInstr);
        p.Add("Despatch",        request.Header.Despatch);
        p.Add("Purpose",         request.Header.Purpose);
        p.Add("OtherLevies",     request.Header.OtherLevies);
        p.Add("PricingTerms",    request.Header.PricingTerms);
        p.Add("PackForwarding",  request.Header.PackForwarding);
        p.Add("Insurance",       request.Header.Insurance);
        p.Add("Freight",         request.Header.Freight);
        p.Add("FDate",           fDate);
        p.Add("LDate",           lDate);
        p.Add("UserId",          userId);
        p.Add("HostName",        hostName);
        p.Add("IpAddress",       ipAddress);
        p.Add("LinesJson",       linesJson);
        p.Add("RoundOff",        request.Header.RoundOff);
        p.Add("TotalOrdVal",     request.Header.OrderValue);   // FD-01: grand total for PO_ORDH.ORDVAL
        p.Add("PoNo", dbType: DbType.Decimal, direction: ParameterDirection.Output);

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.SaveEntry,
            p,
            commandType: CommandType.StoredProcedure);

        var poNo = p.Get<decimal>("PoNo");

        // SP #13: deduct order value from PO_BUDGET (no-op if BudgetControl='N' in PO_PARA)
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.UpdateBudget,
            new { DivCode = divCode, PoNo = poNo, PoDate = request.PoDate },
            commandType: CommandType.StoredProcedure);

        // SP #14: deduct ordered qty from PO_BUDGETQTY_YEAR (no-op if BudgetQty='N' in PO_PARA)
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.UpdateBudgetQty,
            new { DivCode = divCode, PoNo = poNo, PoDate = request.PoDate },
            commandType: CommandType.StoredProcedure);

        // SP #15: record LPO rate history — always active, called once per line
        foreach (var line in request.Lines)
            await _uow.Connection.ExecuteAsync(
                StoredProcedures.Po.SaveLpoRateHistory,
                new
                {
                    DivCode   = divCode,
                    PoNo      = poNo,
                    PoDate    = request.PoDate,
                    OrderType = request.Header.OrderType,
                    Supplier  = request.Header.Supplier,
                    ItemCode  = line.ItemCode,
                    Qty       = line.Qty,
                    Rate      = line.Rate,
                    UserId    = userId
                },
                commandType: CommandType.StoredProcedure);

        return new PoSaveResultDto
        {
            PoNo   = poNo,
            PoDate = request.PoDate.ToString("yyyy-MM-dd")
        };
    }

    public async Task DeleteAsync(string divCode, DeletePoRequest request,
        string userId, string? hostName, string? ipAddress)
    {
        var lineReasonsJson = JsonSerializer.Serialize(request.LineReasons, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        try
        {
            await _uow.Connection.ExecuteAsync(
                StoredProcedures.Po.DeletePo,
                new
                {
                    DivCode         = divCode,
                    PoNo            = request.PoNo,
                    PoDate          = request.PoDate,
                    DeleteMode      = request.DeleteMode,
                    DefaultReason   = request.DefaultReason,
                    LineReasonsJson = lineReasonsJson,
                    UserId          = userId,
                    HostName        = hostName,
                    IpAddress       = ipAddress
                },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Message.Contains("GRN", StringComparison.OrdinalIgnoreCase))
        {
            throw new BusinessConflictException("SORRY - ALREADY GRN IS RAISED FOR THIS PURCHASE ORDER");
        }
    }

    public async Task UpdatePrintFlagAsync(string divCode, decimal poNo, DateOnly poDate)
    {
        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.SetPrintFlag,
            new { DivCode = divCode, PoNo = poNo, PoDate = poDate },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PoPrintDto?> GetPrintDataAsync(string divCode, decimal poNo, DateOnly poDate)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.Po.GetPrintData,
            new { DivCode = divCode, PoNo = poNo, PoDate = poDate },
            commandType: CommandType.StoredProcedure);

        var header = await multi.ReadFirstOrDefaultAsync<PoPrintHeaderRow>();
        if (header is null) return null;

        var lineRows = (await multi.ReadAsync<PoPrintLineRow>()).ToList();

        var lines = lineRows.Select(r => new PoPrintLineDto(
            r.LineNo, r.ItemCode, r.ItemName, r.Uom, r.HsnCode,
            r.PrNo, r.PrSno, r.Qty, r.Rate, r.Value,
            r.TaxCode, r.TaxPer, r.TaxAmt,
            r.CgstPer, r.CgstAmt, r.SgstPer, r.SgstAmt,
            r.IgstPer, r.IgstAmt, r.TcsPer, r.TcsAmt,
            r.LineDis, r.LineDisAmt
        )).ToList();

        return new PoPrintDto(
            header.DivLogo, header.DivName, header.DivPrintName, header.DivUnitName,
            header.DivAddress1, header.DivAddress2, header.DivAddress3,
            header.DivPinCode, header.DivPhone, header.DivEmail, header.DivGstin, header.DivPan, header.DivWeb,
            header.DivCode, header.PoNo, header.PoDate,
            header.SlCode, header.SlName, header.SlAddress, header.SlGstin, header.SlPhone, header.SlEmail,
            header.OrderType, header.Carrier, header.Currency, header.CurrRate,
            header.CreditDays, header.PayMode, header.Remarks,
            header.CgstPer, header.SgstPer, header.IgstPer, header.TcsPer,
            header.DiscPer, header.FreightAmt, header.RoundOff, header.OrderValue,
            header.FirstLevelApp, header.Conflg, header.CreatedBy, header.CreatedDt,
            header.RefNo, header.RefDate, header.DeliveryDate, header.Purpose,
            header.PayTerms, header.InsAmt, header.PackAmt,
            header.DivStateCode, header.SlStateCode,
            lines
        );
    }

    private static async Task<List<DeliveryScheduleLineDto>> ReadDeliveryAsync(SqlMapper.GridReader multi)
    {
        var slots       = (await multi.ReadAsync<DeliverySlotRow>()).ToList();
        var slotsByLine = slots.GroupBy(s => (int)s.LineNo).ToDictionary(g => g.Key, g => g.ToList());

        return slotsByLine.Select(kvp => new DeliveryScheduleLineDto
        {
            LineNo   = kvp.Key,
            ItemCode = kvp.Value.First().ItemCode,
            ItemName = kvp.Value.First().ItemName,
            Uom      = kvp.Value.First().Uom,
            PrNo     = kvp.Value.First().PrNo,
            PoQty    = kvp.Value.First().PoQty,
            Slots    = kvp.Value.Select(s => new DeliverySlotDto
            {
                SlotNo = (int)s.SlotNo,
                ShDate = s.ShDate,
                Qty    = s.Qty,
            }).ToList()
        }).ToList();
    }

    // Class (not record) so Dapper uses property-binding — silently ignores extra
    // columns the deployed SP may return (e.g. Remarks in old JAT SP version).
    private sealed class DeliverySlotRow
    {
        public decimal LineNo   { get; set; }          // PORDSNO — NUMERIC → decimal
        public string  ItemCode { get; set; } = "";
        public string  ItemName { get; set; } = "";
        public string  Uom      { get; set; } = "";
        public decimal PrNo     { get; set; }
        public decimal PoQty    { get; set; }
        public long    SlotNo   { get; set; }          // ROW_NUMBER() → BIGINT → long
        public string? ShDate   { get; set; }
        public decimal Qty      { get; set; }
    }
}
