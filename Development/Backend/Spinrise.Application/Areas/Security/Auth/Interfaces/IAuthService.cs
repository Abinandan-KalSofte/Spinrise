using Spinrise.Application.Areas.Security.Auth.DTOs;

namespace Spinrise.Application.Areas.Security.Auth.Interfaces;

public interface IAuthService
{
    Task<AuthResponseDto?> LoginAsync(LoginRequestDto request);
    Task<AuthResponseDto?> RefreshTokenAsync(RefreshTokenRequestDto request);
    Task LogoutAsync(string? refreshToken);
}
