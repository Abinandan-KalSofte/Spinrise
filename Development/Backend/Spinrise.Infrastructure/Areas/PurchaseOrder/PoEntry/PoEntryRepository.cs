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

    public async Task<IEnumerable<BankOptionDto>> GetBanksAsync(string? search)
    {
        return await _uow.Connection.QueryAsync<BankOptionDto>(
            StoredProcedures.Po.GetBanks,
            new { Search = search },
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

    public async Task<IEnumerable<EligiblePrLineDto>> GetEligiblePrLinesAsync(
        string divCode, string? orderType, string? search, int page, int pageSize)
    {
        return await _uow.Connection.QueryAsync<EligiblePrLineDto>(
            StoredProcedures.Po.GetEligiblePrLines,
            new { DivCode = divCode, OrderType = orderType, Search = search, PageNumber = page, PageSize = pageSize },
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
        var linesJson = JsonSerializer.Serialize(request.Lines, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

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
        p.Add("PackPer",         request.Header.PackPer);
        p.Add("InsurPer",        request.Header.InsurPer);
        p.Add("SurchargePer",    request.Header.SurchargePer);
        p.Add("AddTaxPer",       request.Header.AddTaxPer);
        p.Add("FileNo",          request.Header.FileNo);
        p.Add("FcaFob",          request.Header.FcaFob);
        p.Add("FreightType",     request.Header.FreightType);
        p.Add("DiscApp",         request.Header.DiscApp);
        p.Add("PackApp",         request.Header.PackApp);
        p.Add("CessApp",         request.Header.CessApp);
        p.Add("PayMode",         request.Header.PayMode);
        p.Add("DirectInstr",     request.Header.DirectInstr);
        p.Add("BankCode",        request.Header.BankCode);
        p.Add("PaymentTerms",    request.Header.PaymentTerms);
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
        p.Add("PoNo", dbType: DbType.Decimal, direction: ParameterDirection.Output);

        await _uow.Connection.ExecuteAsync(
            StoredProcedures.Po.SaveEntry,
            p,
            commandType: CommandType.StoredProcedure);

        var poNo = p.Get<decimal>("PoNo");
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
            r.IgstPer, r.IgstAmt, r.TcsPer, r.TcsAmt
        )).ToList();

        return new PoPrintDto(
            header.DivLogo, header.DivName, header.DivPrintName,
            header.DivAddress1, header.DivAddress2, header.DivAddress3,
            header.DivPinCode, header.DivPhone, header.DivEmail, header.DivGstin,
            header.DivCode, header.PoNo, header.PoDate,
            header.SlCode, header.SlName, header.SlAddress, header.SlGstin,
            header.OrderType, header.Carrier, header.Currency, header.CurrRate,
            header.CreditDays, header.PayMode, header.Remarks,
            header.CgstPer, header.SgstPer, header.IgstPer, header.TcsPer,
            header.DiscPer, header.FreightAmt, header.RoundOff, header.OrderValue,
            header.FirstLevelApp, header.Conflg, header.CreatedBy, header.CreatedDt,
            lines
        );
    }

    private static async Task<List<DeliveryScheduleLineDto>> ReadDeliveryAsync(SqlMapper.GridReader multi)
    {
        var slots     = (await multi.ReadAsync<DeliverySlotRow>()).ToList();
        var slotsByLine = slots.GroupBy(s => s.LineNo).ToDictionary(g => g.Key, g => g.ToList());

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
                SlotNo  = s.SlotNo,
                ShDate  = s.ShDate,
                Qty     = s.Qty,
                Remarks = s.Remarks
            }).ToList()
        }).ToList();
    }

    private sealed record DeliverySlotRow(
        int     LineNo,
        string  ItemCode,
        string  ItemName,
        string  Uom,
        decimal PrNo,
        decimal PoQty,
        int     SlotNo,
        string? ShDate,
        decimal Qty,
        string  Remarks);
}
