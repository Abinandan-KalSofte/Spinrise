using Microsoft.Extensions.Logging;
using Spinrise.Application.Areas.Security.Auth.DTOs;
using Spinrise.Application.Areas.Security.Auth.Interfaces;

namespace Spinrise.Application.Areas.Security.Auth.Services;

public class AuthService : IAuthService
{
    private readonly IAuthUserStore _userStore;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRefreshTokenStore _refreshTokenStore;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        IAuthUserStore userStore,
        IJwtTokenService jwtTokenService,
        IRefreshTokenStore refreshTokenStore,
        ILogger<AuthService> logger)
    {
        _userStore = userStore;
        _jwtTokenService = jwtTokenService;
        _refreshTokenStore = refreshTokenStore;
        _logger = logger;
    }

    public async Task<AuthResponseDto?> LoginAsync(LoginRequestDto request)
    {
        var user = await _userStore.ValidateCredentialsAsync(
            request.UserName, request.DivCode, request.Password, request.DbName);

        if (user is null)
        {
            _logger.LogWarning("Login failed | User: {UserId} | Div: {DivCode} | DB: {DbName}",
                request.UserName, request.DivCode, request.DbName);
            return null;
        }

        _logger.LogInformation("Login | User: {UserId} | Div: {DivCode} | DB: {DbName}",
            user.UserId, user.DivCode, request.DbName);

        return await CreateSessionAsync(user);
    }

    public async Task<AuthResponseDto?> RefreshTokenAsync(RefreshTokenRequestDto request)
    {
        var validation = _jwtTokenService.ValidateRefreshToken(request.RefreshToken);
        if (validation is null) return null;

        var isActive = await _refreshTokenStore.IsActiveAsync(validation.TokenId);
        if (!isActive) return null;

        await _refreshTokenStore.RevokeAsync(validation.TokenId);

        var freshUser = await _userStore.GetByUserIdAsync(
            validation.User.UserId, validation.User.DivCode, validation.User.DbName);

        if (freshUser is null) return null;

        return await CreateSessionAsync(freshUser);
    }

    public async Task LogoutAsync(string? refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken)) return;

        var validation = _jwtTokenService.ValidateRefreshToken(refreshToken);
        if (validation is null) return;

        _logger.LogInformation("Logout | User: {UserId}", validation.User.UserId);
        await _refreshTokenStore.RevokeAsync(validation.TokenId);
    }

    private async Task<AuthResponseDto> CreateSessionAsync(AuthUserDto user)
    {
        var accessToken = _jwtTokenService.GenerateAccessToken(user);
        var refreshResult = _jwtTokenService.GenerateRefreshToken(user);

        await _refreshTokenStore.StoreAsync(refreshResult.TokenId, refreshResult.ExpiresAtUtc);

        return new AuthResponseDto
        {
            User = user,
            Tokens = new AuthTokensDto
            {
                AccessToken = accessToken,
                RefreshToken = refreshResult.Token
            }
        };
    }
}
