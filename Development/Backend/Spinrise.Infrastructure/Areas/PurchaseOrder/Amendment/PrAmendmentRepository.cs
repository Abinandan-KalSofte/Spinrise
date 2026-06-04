using System.Data;
using System.Text.Json;
using Dapper;
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

        var hdr = await multi.ReadFirstOrDefaultAsync<AmendHeaderRow>();
        if (hdr is null) return null;

        var lines = (await multi.ReadAsync<PrAmendmentLineDto>()).ToList();

        return BuildHeaderDto(hdr, lines);
    }

    public async Task<int> SaveAsync(
        string mode, string divCode, decimal prNo, DateOnly prDate,
        SaveAmendmentRequest request, string userId, DateOnly fDate, DateOnly lDate,
        string? hostName, string? ipAddress, int? amendNo = null)
    {
        byte[]? rowVersionBytes = null;
        if (!string.IsNullOrWhiteSpace(request.RowVersion))
            rowVersionBytes = Convert.FromBase64String(request.RowVersion);

        var linesJson = mode != "DELETE"
            ? JsonSerializer.Serialize(request.Lines.Select(l => new
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
                  // PATH A concurrency: convert base64 rowVersion → 0x-prefixed hex for SP CONVERT(VARBINARY,.,1)
                  RowVersion = !string.IsNullOrWhiteSpace(l.RowVersion)
                      ? "0x" + Convert.ToHexString(Convert.FromBase64String(l.RowVersion))
                      : (string?)null,
              }))
            : null;

        var pDate = DateOnly.TryParse(request.PDate, out var parsedPDate)
            ? parsedPDate
            : DateOnly.FromDateTime(DateTime.Today);

        var result = await _uow.Connection.QueryFirstAsync<SaveResultRow>(
            StoredProcedures.PrAmendment.Save,
            new
            {
                Mode             = mode,
                DivCode          = divCode,
                PrNo             = prNo,
                PrDate           = prDate,
                AmendDate        = DateOnly.TryParse(request.AmendDate, out var parsedAmendDate) ? parsedAmendDate : prDate,
                AmendmentReason  = request.AmendmentReason,
                RefNo            = request.RefNo,
                UserId           = userId,
                HostName         = hostName,
                IpAddress        = ipAddress,
                FDate            = fDate,
                LDate            = lDate,
                PDate            = pDate,
                AmendNo          = mode == "ADD" ? (int?)null : amendNo,
                RowVersion       = rowVersionBytes,
                LinesJson        = linesJson,
            },
            commandType: CommandType.StoredProcedure);

        return result.AmendNo;
    }

    public async Task<int> DeleteLineAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo, int prSno,
        byte[] rowVersionBytes, DateOnly pDate, string userId, string? hostName, string? ipAddress)
    {
        var result = await _uow.Connection.QueryFirstAsync<SaveResultRow>(
            StoredProcedures.PrAmendment.Save,
            new
            {
                Mode        = "DELETE_LINE",
                DivCode     = divCode,
                PrNo        = prNo,
                PrDate      = prDate,
                AmendDate   = pDate,
                AmendmentReason = string.Empty,
                UserId      = userId,
                HostName    = hostName,
                IpAddress   = ipAddress,
                FDate       = prDate,
                LDate       = prDate,
                PDate       = pDate,
                AmendNo     = amendNo,
                RowVersion  = rowVersionBytes,
                LinesJson   = (string?)null,
                PrSno       = prSno,
            },
            commandType: CommandType.StoredProcedure);
        return result.AmendNo;
    }

    public async Task<PrAmendmentPrintDto?> GetPrintDataAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrAmendment.GetPrint,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate, AmendNo = amendNo },
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

    // Raw row types — match SP column names exactly
    private sealed record SaveResultRow(int AmendNo);

    private sealed record AmendHeaderRow(
        string?  DivCode,
        decimal  PrNo,
        string?  PrDate,
        int      AmendNo,
        string?  AmendDate,
        string?  AmendmentReason,
        string?  RefNo,
        string?  CreatedBy,
        string?  CreatedDt,
        byte[]?  RowVersion,
        string?  DepCode,
        string?  DepName,
        string?  ReqName,
        string?  ReqEmpName,
        string?  Section,
        string?  IType,
        string?  IDesc,
        string?  AppFlg,
        string?  CancelFlag);

    private sealed record AmendPrintHeaderRow(
        string?  DivCode,
        decimal  PrNo,
        string?  PrDate,
        int      AmendNo,
        string?  AmendDate,
        string?  AmendmentReason,
        string?  RefNo,
        string?  CreatedBy,
        string?  DepCode,
        string?  DepName,
        string?  ReqName,
        byte[]?  DivLogo,
        string?  DivName,
        string?  DivPrintName,
        string?  DivUnitName,
        string?  DivAddress1,
        string?  DivAddress2,
        string?  DivAddress3,
        string?  DivPinCode,
        string?  DivState,
        string?  DivPhone,
        string?  DivEmail);
}
