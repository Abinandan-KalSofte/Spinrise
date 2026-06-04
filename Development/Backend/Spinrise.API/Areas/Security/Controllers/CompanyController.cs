using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.Security.Company.Interfaces;

namespace Spinrise.API.Areas.Security.Controllers;

[Area("Security")]
[Route("api/v1/companies")]
public class CompanyController : BaseApiController
{
    private readonly ICompanyRepository _repo;

    public CompanyController(ICompanyRepository repo) => _repo = repo;

    [AllowAnonymous]
    [HttpGet("active")]
    public async Task<IActionResult> GetActiveCompanies([FromQuery] string? db)
    {
        var companies = string.IsNullOrWhiteSpace(db)
            ? await _repo.GetActiveCompaniesAsync()
            : await _repo.GetActiveCompaniesAsync(db);

        return OkResponse(companies);
    }
}
