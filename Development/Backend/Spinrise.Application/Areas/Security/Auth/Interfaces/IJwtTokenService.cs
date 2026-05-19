using Spinrise.Application.Areas.Security.Auth.DTOs;

namespace Spinrise.Application.Areas.Security.Auth.Interfaces;

public interface IJwtTokenService
{
    string GenerateAccessToken(AuthUserDto user);
    JwtTokenResult GenerateRefreshToken(AuthUserDto user);
    RefreshTokenValidationResult? ValidateRefreshToken(string refreshToken);
}
