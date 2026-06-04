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

        var hdr = await multi.ReadFirstOrDefaultAsync<dynamic>();
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

        var hdr = await multi.ReadFirstOrDefaultAsync<dynamic>();
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

        var result = await _uow.Connection.QueryFirstAsync<dynamic>(
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

        return Convert.ToInt32(result.AmendNo);
    }

    public async Task<int> DeleteLineAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo, int prSno,
        byte[] rowVersionBytes, DateOnly pDate, string userId, string? hostName, string? ipAddress)
    {
        var result = await _uow.Connection.QueryFirstAsync<dynamic>(
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
        return Convert.ToInt32(result.AmendNo);
    }

    public async Task<PrAmendmentPrintDto?> GetPrintDataAsync(
        string divCode, decimal prNo, DateOnly prDate, int amendNo)
    {
        using var multi = await _uow.Connection.QueryMultipleAsync(
            StoredProcedures.PrAmendment.GetPrint,
            new { DivCode = divCode, PrNo = prNo, PrDate = prDate, AmendNo = amendNo },
            commandType: CommandType.StoredProcedure);

        var hdr = await multi.ReadFirstOrDefaultAsync<dynamic>();
        if (hdr is null) return null;

        var lines = (await multi.ReadAsync<PrAmendmentPrintLineDto>()).ToList();

        return new PrAmendmentPrintDto(
            DivCode:          (string)hdr.divcode,
            PrNo:             Convert.ToDecimal(hdr.prno),
            PrDate:           (string)hdr.prDate,
            AmendNo:          Convert.ToInt32(hdr.amendno),
            AmendDate:        (string)hdr.amendDate,
            AmendmentReason:  (string)hdr.amendmentReason,
            RefNo:            (string)hdr.refNo,
            CreatedBy:        (string)hdr.createdby,
            DepCode:          (string)hdr.depcode,
            DepName:          (string)hdr.depName,
            ReqName:          (string)hdr.reqName,
            DivName:          (string)hdr.divName,
            DivPrintName:     (string)hdr.divPrintName,
            DivUnitName:      (string)hdr.divUnitName,
            DivAddress1:      (string)hdr.divAddress1,
            DivAddress2:      (string)hdr.divAddress2,
            DivAddress3:      (string)hdr.divAddress3,
            DivPinCode:       (string)hdr.divPinCode,
            DivState:         (string)hdr.divState,
            DivPhone:         (string)hdr.divPhone,
            DivEmail:         (string)hdr.divEmail,
            DivLogo:          hdr.divLogo as byte[],
            Lines:            lines
        );
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static PrAmendmentHeaderDto BuildHeaderDto(dynamic hdr, List<PrAmendmentLineDto> lines)
    {
        string rowVer = hdr.rowVersion is byte[] rv
            ? Convert.ToBase64String(rv)
            : string.Empty;

        return new PrAmendmentHeaderDto(
            DivCode:          (string)hdr.divcode,
            PrNo:             Convert.ToDecimal(hdr.prno),
            PrDate:           (string)hdr.prDate,
            AmendNo:          Convert.ToInt32(hdr.amendno),
            AmendDate:        (string)hdr.amendDate,
            AmendmentReason:  (string)hdr.amendmentReason,
            RefNo:            (string)hdr.refNo,
            CreatedBy:        (string)hdr.createdby,
            CreatedDt:        (string)hdr.createdDt,
            RowVersion:       rowVer,
            DepCode:          (string)hdr.depcode,
            DepName:          (string)hdr.depName,
            ReqName:          (string)hdr.reqName,
            ReqEmpName:       (string)hdr.reqEmpName,
            Section:          (string)hdr.section,
            IType:            (string)hdr.iType,
            IDesc:            (string)hdr.iDesc,
            AppFlg:           (string)hdr.appFlg,
            CancelFlag:       (string)hdr.cancelFlag,
            Lines:            lines
        );
    }
}
