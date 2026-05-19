using Spinrise.Application.Areas.Security.Auth.DTOs;
using Spinrise.Application.Areas.Security.Auth.Interfaces;

namespace Spinrise.Application.Areas.Security.Auth.Services;

public class AuthService : IAuthService
{
    private readonly IAuthUserStore _userStore;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRefreshTokenStore _refreshTokenStore;

    public AuthService(
        IAuthUserStore userStore,
        IJwtTokenService jwtTokenService,
        IRefreshTokenStore refreshTokenStore)
    {
        _userStore = userStore;
        _jwtTokenService = jwtTokenService;
        _refreshTokenStore = refreshTokenStore;
    }

    public async Task<AuthResponseDto?> LoginAsync(LoginRequestDto request)
    {
        var user = await _userStore.ValidateCredentialsAsync(
            request.UserName, request.DivCode, request.Password);

        if (user is null) return null;

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
            validation.User.UserId, validation.User.DivCode);

        if (freshUser is null) return null;

        return await CreateSessionAsync(freshUser);
    }

    public async Task LogoutAsync(string? refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken)) return;

        var validation = _jwtTokenService.ValidateRefreshToken(refreshToken);
        if (validation is null) return;

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
