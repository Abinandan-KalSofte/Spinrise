using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;
using Spinrise.Shared.Constants;
using Spinrise.Shared.Models;
using System.Security.Claims;

namespace Spinrise.API.Areas.PurchaseOrder.Controllers;

[Authorize]
[Area("PurchaseOrder")]
[Route("api/v1/finallevel-pr")]
public class FinalLevelApprovalController : BaseApiController
{
    private readonly IFinalLevelApprovalService _service;

    public FinalLevelApprovalController(IFinalLevelApprovalService service) => _service = service;

    // GET /api/v1/finallevel-pr?dbName=KML&divCode=01&bypass=1
    [HttpGet]
    public async Task<IActionResult> GetPending([FromQuery] FinalApprovalGetQuery query)
    {
        if (!ModelState.IsValid) return UnprocessableEntity(ModelState);
        var result = await _service.GetPendingAsync(query);
        return OkResponse(result);
    }

    // POST /api/v1/finallevel-pr/approve
    [HttpPost("approve")]
    public async Task<IActionResult> SaveApprovals([FromBody] FinalApprovalSaveRequest request)
    {
        if (!ModelState.IsValid) return UnprocessableEntity(ModelState);

        var finalAppUser = User.FindFirstValue(SpinriseClaims.UserName)
                        ?? User.FindFirstValue(SpinriseClaims.UserId)
                        ?? string.Empty;

        try
        {
            var result = await _service.SaveApprovalsAsync(request, finalAppUser);
            return OkResponse(result);
        }
        catch (ConcurrencyConflictException ex)
        {
            var payload = new
            {
                code    = "CONCURRENCY_CONFLICT",
                message = ex.Message,
                conflictItems = ex.ConflictItems.Select(c => new { prNo = c.PrNo, prSno = c.PrSno }),
            };
            return StatusCode(409, payload);
        }
    }

    // GET /api/v1/finallevel-pr/companies
    [HttpGet("companies")]
    public async Task<IActionResult> GetCompanies()
    {
        var result = await _service.GetCompaniesAsync();
        return OkResponse(result);
    }

    // GET /api/v1/finallevel-pr/divisions?dbName=KML
    [HttpGet("divisions")]
    public async Task<IActionResult> GetDivisions([FromQuery] string dbName)
    {
        var result = await _service.GetDivisionsAsync(dbName);
        return OkResponse(result);
    }

    // GET /api/v1/finallevel-pr/items/{itemCode}/purchase-history?divCode=01
    [HttpGet("items/{itemCode}/purchase-history")]
    public async Task<IActionResult> GetItemHistory(string itemCode, [FromQuery] string divCode)
    {
        var result = await _service.GetItemHistoryAsync(itemCode, divCode);
        return OkResponse(result);
    }
}
