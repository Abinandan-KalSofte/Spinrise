using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Spinrise.API.Controllers;
using Spinrise.Application.Areas.Security.Auth.DTOs;
using Spinrise.Application.Areas.Security.Auth.Interfaces;

namespace Spinrise.API.Areas.Security.Controllers;

[Area("Security")]
[Route("api/v1/auth")]
public class AuthController : BaseApiController
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
    {
        var result = await _authService.LoginAsync(request);
        if (result is null)
            return UnauthorizedResponse("Invalid credentials.");

        return OkResponse(result, "Login successful.");
    }

    [AllowAnonymous]
    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequestDto request)
    {
        var result = await _authService.RefreshTokenAsync(request);
        if (result is null)
            return UnauthorizedResponse("Invalid or expired refresh token.");

        return OkResponse(result, "Token refreshed successfully.");
    }

    [AllowAnonymous]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutRequestDto request)
    {
        await _authService.LogoutAsync(request.RefreshToken);
        return OkResponse("Logout successful.");
    }
}
