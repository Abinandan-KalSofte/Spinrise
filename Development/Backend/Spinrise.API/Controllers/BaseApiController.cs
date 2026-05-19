using Microsoft.AspNetCore.Mvc;
using Spinrise.Shared.Models;

namespace Spinrise.API.Controllers;

[ApiController]
public abstract class BaseApiController : ControllerBase
{
    protected IActionResult OkResponse<T>(T data, string message = "Success") =>
        Ok(ApiResponse<T>.Ok(data, message));

    protected IActionResult OkResponse(string message = "Success") =>
        Ok(ApiResponse.Ok(message));

    protected IActionResult FailResponse(string message, int statusCode = 400, object? errors = null) =>
        StatusCode(statusCode, ApiResponse.Fail(message, errors));

    protected IActionResult NotFoundResponse(string message = "Not found.") =>
        NotFound(ApiResponse.Fail(message));

    protected IActionResult UnauthorizedResponse(string message = "Unauthorized.") =>
        Unauthorized(ApiResponse.Fail(message));
}
