using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.Security.Division.Interfaces;

namespace Spinrise.API.Areas.Security.Controllers;

[Area("Security")]
[Route("api/v1/divisions")]
public class DivisionController : BaseApiController
{
    private readonly IDivisionRepository _divisionRepo;

    public DivisionController(IDivisionRepository divisionRepo)
    {
        _divisionRepo = divisionRepo;
    }

    [AllowAnonymous]
    [HttpGet("active")]
    public async Task<IActionResult> GetActiveDivisions([FromQuery] string? db)
    {
        var divisions = string.IsNullOrWhiteSpace(db)
            ? await _divisionRepo.GetActiveDivisionsAsync()
            : await _divisionRepo.GetActiveDivisionsAsync(db);

        return OkResponse(divisions);
    }
}
