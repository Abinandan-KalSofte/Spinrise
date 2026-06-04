using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.Security.Database.Interfaces;

namespace Spinrise.API.Areas.Security.Controllers;

[Area("Security")]
[Route("api/v1/databases")]
public class DatabaseController : BaseApiController
{
    private readonly IDatabaseRepository _databaseRepo;

    public DatabaseController(IDatabaseRepository databaseRepo)
    {
        _databaseRepo = databaseRepo;
    }

    [AllowAnonymous]
    [HttpGet]
    public async Task<IActionResult> GetDatabases()
    {
        var databases = await _databaseRepo.GetDatabasesAsync();
        return OkResponse(databases);
    }
}
