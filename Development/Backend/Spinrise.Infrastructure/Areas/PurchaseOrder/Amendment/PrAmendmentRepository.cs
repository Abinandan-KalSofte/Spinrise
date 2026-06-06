using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.PurchaseOrder.Amendment;

public class PrAmendmentRepository : IPrAmendmentRepository
{
    private readonly IUnitOfWork _uow;

    public PrAmendmentRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<IEnumerable<PrAmendmentSummaryDto>> GetListAsync(
        string divCode, DateOnly fDate, DateOnly lDate,
        decimal? prNo, string? search, int page, int pageSize)
    {
        return await _uow.Connection.QueryAsync<PrAmendmentSummaryDto>(
            StoredProcedures.PrAmendment.GetList,
            new
            {
                DivCode    = divCode,
                FDate      = fDate,
                LDate      = lDate,
                PrNo       = prNo,
                Search     = search,
                PageNumber = page,
                PageSize   = pageSize,
            },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PrAmendmentHeaderDto?> GetByIdAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrAmendment.GetById,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate, AmendNo = amendNo },
            commandType: CommandType.StoredProcedure);

        var hdr = await multi.ReadFirstOrDefaultAsync<AmendHeaderRow>();
        if (hdr is null) return null;

        var lines = (await multi.ReadAsync<PrAmendmentLineDto>()).ToList();

        return BuildHeaderDto(hdr, lines);
    }

    public async Task<PrAmendmentHeaderDto?> GetForNewAsync(
        string divCode, decimal prNo, DateOnly prDate)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrAmendment.GetForNew,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate },
            commandType: CommandType.StoredProcedure);

        var hdr = await multi.ReadFirstOrDefaultAsync<AmendHeaderForNewRow>();
        if (hdr is null) return null;

        var lines = (await multi.ReadAsync<PrAmendmentLineDto>()).ToList();

        return BuildHeaderDtoForNew(hdr, lines);
    }

    public async Task<int> SaveAsync(
        string divCode, decimal prNo, DateOnly prDate,
        SaveAmendmentRequest request, string userId, DateOnly fDate, DateOnly lDate,
        string? hostName, string? ipAddress)
    {
        byte[]? rowVersionBytes = null;
        if (!string.IsNullOrWhiteSpace(request.RowVersion))
            rowVersionBytes = Convert.FromBase64String(request.RowVersion);

        var linesJson = JsonSerializer.Serialize(request.Lines.Select(l => new
        {
            l.PrSno,
            l.ItemCode,
            l.MacNo,
            l.QtyInd,
            l.ReqdDate,
            l.Rate,
            l.RateSource,
            l.RateJustification,
            l.CurStock,
            l.CcCode,
            l.CatCode,
            l.BgrpCode,
            l.Place,
            l.AppCost,
            l.Remarks,
            // PATH A concurrency: convert base64 rowVersion → 0x-prefixed hex for SP TRY_CONVERT(VARBINARY,.,1)
            RowVersion = !string.IsNullOrWhiteSpace(l.RowVersion)
                ? "0x" + Convert.ToHexString(Convert.FromBase64String(l.RowVersion))
                : (string?)null,
        }));

        var pDate = DateOnly.TryParse(request.PDate, out var parsedPDate)
            ? parsedPDate
            : DateOnly.FromDateTime(DateTime.Today);

        var p = new DynamicParameters();
        p.Add("Mode",            "ADD");
        p.Add("DivCode",         divCode);
        p.Add("PrNo",            prNo);
        p.Add("PrDate",          prDate);
        p.Add("AmendDate",       DateOnly.TryParse(request.AmendDate, out var parsedAmendDate) ? parsedAmendDate : prDate);
        p.Add("AmendmentReason", request.AmendmentReason);
        p.Add("RefNo",           request.RefNo);
        p.Add("UserId",          userId);
        p.Add("HostName",        hostName);
        p.Add("IpAddress",       ipAddress);
        p.Add("FDate",           fDate);
        p.Add("LDate",           lDate);
        p.Add("PDate",           pDate);
        p.Add("AmendNo",         (int?)null);
        p.Add("RowVersion",      rowVersionBytes, DbType.Binary, size: 8);
        p.Add("LinesJson",       linesJson);
        p.Add("IType",           string.IsNullOrWhiteSpace(request.IType) ? null : request.IType.Trim());
        p.Add("Result",          dbType: DbType.Int32, direction: ParameterDirection.Output);

        try
        {
            var result = await _uow.Connection.QueryFirstAsync<SaveResultRow>(
                StoredProcedures.PrAmendment.Save, p,
                commandType: CommandType.StoredProcedure);
            return result.AmendNo;
        }
        catch (SqlException ex)
        {
            // @Result = 1 → business rule violation (severity 16 RAISERROR) → 400
            // @Result = -1 → infrastructure/system error → re-throw (500 via middleware)
            if (p.Get<int>("Result") == 1)
                throw new InvalidOperationException(ex.Message);
            throw;
        }
    }

    public async Task<PrAmendmentPrintDto?> GetPrintDataAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo, string userId)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrAmendment.GetPrint,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate, AmendNo = amendNo, UserId = userId },
            commandType: CommandType.StoredProcedure);

        var hdr = await multi.ReadFirstOrDefaultAsync<AmendPrintHeaderRow>();
        if (hdr is null) return null;

        var lines = (await multi.ReadAsync<PrAmendmentPrintLineDto>()).ToList();

        return new PrAmendmentPrintDto(
            DivCode:          hdr.DivCode          ?? string.Empty,
            PrNo:             hdr.PrNo,
            PrDate:           hdr.PrDate           ?? string.Empty,
            AmendNo:          hdr.AmendNo,
            AmendDate:        hdr.AmendDate         ?? string.Empty,
            AmendmentReason:  hdr.AmendmentReason   ?? string.Empty,
            RefNo:            hdr.RefNo             ?? string.Empty,
            CreatedBy:        hdr.CreatedBy         ?? string.Empty,
            DepCode:          hdr.DepCode           ?? string.Empty,
            DepName:          hdr.DepName           ?? string.Empty,
            ReqName:          hdr.ReqName           ?? string.Empty,
            DivName:          hdr.DivName           ?? string.Empty,
            DivPrintName:     hdr.DivPrintName      ?? string.Empty,
            DivUnitName:      hdr.DivUnitName       ?? string.Empty,
            DivAddress1:      hdr.DivAddress1       ?? string.Empty,
            DivAddress2:      hdr.DivAddress2       ?? string.Empty,
            DivAddress3:      hdr.DivAddress3       ?? string.Empty,
            DivPinCode:       hdr.DivPinCode        ?? string.Empty,
            DivState:         hdr.DivState          ?? string.Empty,
            DivPhone:         hdr.DivPhone          ?? string.Empty,
            DivEmail:         hdr.DivEmail          ?? string.Empty,
            DivLogo:          hdr.DivLogo,
            Lines:            lines
        );
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static PrAmendmentHeaderDto BuildHeaderDto(AmendHeaderRow hdr, List<PrAmendmentLineDto> lines)
    {
        string rowVer = hdr.RowVersion is not null
            ? Convert.ToBase64String(hdr.RowVersion)
            : string.Empty;

        return new PrAmendmentHeaderDto(
            DivCode:          hdr.DivCode          ?? string.Empty,
            PrNo:             hdr.PrNo,
            PrDate:           hdr.PrDate           ?? string.Empty,
            AmendNo:          hdr.AmendNo,
            AmendDate:        hdr.AmendDate         ?? string.Empty,
            AmendmentReason:  hdr.AmendmentReason   ?? string.Empty,
            RefNo:            hdr.RefNo             ?? string.Empty,
            CreatedBy:        hdr.CreatedBy         ?? string.Empty,
            CreatedDt:        hdr.CreatedDt         ?? string.Empty,
            RowVersion:       rowVer,
            DepCode:          hdr.DepCode           ?? string.Empty,
            DepName:          hdr.DepName           ?? string.Empty,
            ReqName:          hdr.ReqName           ?? string.Empty,
            ReqEmpName:       hdr.ReqEmpName        ?? string.Empty,
            Section:          hdr.Section           ?? string.Empty,
            IType:            hdr.IType             ?? string.Empty,
            IDesc:            hdr.IDesc             ?? string.Empty,
            AppFlg:           hdr.AppFlg            ?? string.Empty,
            CancelFlag:       hdr.CancelFlag        ?? string.Empty,
            Lines:            lines
        );
    }

    private static PrAmendmentHeaderDto BuildHeaderDtoForNew(AmendHeaderForNewRow hdr, List<PrAmendmentLineDto> lines)
    {
        return new PrAmendmentHeaderDto(
            DivCode:         hdr.DivCode          ?? string.Empty,
            PrNo:            hdr.PrNo,
            PrDate:          hdr.PrDate           ?? string.Empty,
            AmendNo:         hdr.AmendNo,
            AmendDate:       hdr.AmendDate         ?? string.Empty,
            AmendmentReason: hdr.AmendmentReason   ?? string.Empty,
            RefNo:           hdr.RefNo             ?? string.Empty,
            CreatedBy:       hdr.CreatedBy         ?? string.Empty,
            CreatedDt:       hdr.CreatedDt         ?? string.Empty,
            RowVersion:      hdr.RowVersion         ?? string.Empty,
            DepCode:         hdr.DepCode           ?? string.Empty,
            DepName:         hdr.DepName           ?? string.Empty,
            ReqName:         hdr.ReqName           ?? string.Empty,
            ReqEmpName:      hdr.ReqEmpName        ?? string.Empty,
            Section:         hdr.Section           ?? string.Empty,
            IType:           hdr.IType             ?? string.Empty,
            IDesc:           hdr.IDesc             ?? string.Empty,
            AppFlg:          hdr.AppFlg            ?? string.Empty,
            CancelFlag:      hdr.CancelFlag        ?? string.Empty,
            Lines:           lines
        );
    }

    // Raw row types — match SP column names exactly
    private sealed record SaveResultRow(int AmendNo);

    // Property classes — Dapper maps by name, so SP column order and additions never cause constructor errors.
    private sealed class AmendHeaderRow
    {
        public string?  DivCode          { get; init; }
        public decimal  PrNo             { get; init; }
        public string?  PrDate           { get; init; }
        public int      AmendNo          { get; init; }
        public string?  AmendDate        { get; init; }
        public string?  AmendmentReason  { get; init; }
        public string?  RefNo            { get; init; }
        public string?  CreatedBy        { get; init; }
        public string?  CreatedDt        { get; init; }
        public byte[]?  RowVersion       { get; init; }
        public string?  DepCode          { get; init; }
        public string?  DepName          { get; init; }
        public string?  ReqName          { get; init; }
        public string?  ReqEmpName       { get; init; }
        public string?  Section          { get; init; }
        public string?  IType            { get; init; }
        public string?  IDesc            { get; init; }
        public string?  AppFlg           { get; init; }
        public string?  CancelFlag       { get; init; }
    }

    // ForNew SP returns RowVersion as '' (string) + ExistingAmendCount
    private sealed class AmendHeaderForNewRow
    {
        public string?  DivCode          { get; init; }
        public decimal  PrNo             { get; init; }
        public string?  PrDate           { get; init; }
        public int      AmendNo          { get; init; }
        public string?  AmendDate        { get; init; }
        public string?  AmendmentReason  { get; init; }
        public string?  RefNo            { get; init; }
        public string?  CreatedBy        { get; init; }
        public string?  CreatedDt        { get; init; }
        public string?  RowVersion       { get; init; }
        public string?  DepCode          { get; init; }
        public string?  DepName          { get; init; }
        public string?  ReqName          { get; init; }
        public string?  ReqEmpName       { get; init; }
        public string?  Section          { get; init; }
        public string?  IType            { get; init; }
        public string?  IDesc            { get; init; }
        public string?  AppFlg           { get; init; }
        public string?  CancelFlag       { get; init; }
        public int      ExistingAmendCount { get; init; }
    }

    private sealed class AmendPrintHeaderRow
    {
        public string?  DivCode          { get; init; }
        public decimal  PrNo             { get; init; }
        public string?  PrDate           { get; init; }
        public int      AmendNo          { get; init; }
        public string?  AmendDate        { get; init; }
        public string?  AmendmentReason  { get; init; }
        public string?  RefNo            { get; init; }
        public string?  CreatedBy        { get; init; }
        public string?  DepCode          { get; init; }
        public string?  DepName          { get; init; }
        public string?  ReqName          { get; init; }
        public byte[]?  DivLogo          { get; init; }
        public string?  DivName          { get; init; }
        public string?  DivPrintName     { get; init; }
        public string?  DivUnitName      { get; init; }
        public string?  DivAddress1      { get; init; }
        public string?  DivAddress2      { get; init; }
        public string?  DivAddress3      { get; init; }
        public string?  DivPinCode       { get; init; }
        public string?  DivState         { get; init; }
        public string?  DivPhone         { get; init; }
        public string?  DivEmail         { get; init; }
    }
}
