using FluentAssertions;
using Moq;
using Spinrise.Application.Areas.Security.Auth.DTOs;
using Spinrise.Application.Areas.Security.Auth.Interfaces;
using Spinrise.Application.Areas.Security.Auth.Services;

namespace Spinrise.Tests.Areas.Security.Auth;

public class AuthServiceTests
{
    private readonly Mock<IAuthUserStore> _userStore = new();
    private readonly Mock<IJwtTokenService> _jwtService = new();
    private readonly Mock<IRefreshTokenStore> _tokenStore = new();
    private readonly AuthService _sut;

    private readonly AuthUserDto _testUser = new()
    {
        Id = 1, UserId = "testuser", UserName = "Test User",
        Email = "testuser", Role = "User", DivCode = "01"
    };

    private readonly JwtTokenResult _testRefreshResult = new()
    {
        Token = "refresh-token", TokenId = "token-id-123",
        ExpiresAtUtc = DateTime.UtcNow.AddDays(7)
    };

    public AuthServiceTests()
    {
        _sut = new AuthService(_userStore.Object, _jwtService.Object, _tokenStore.Object);
    }

    // ── Login ─────────────────────────────────────────────────

    [Fact]
    public async Task LoginAsync_ValidCredentials_ReturnsAuthResponse()
    {
        // Arrange
        var request = new LoginRequestDto { DivCode = "01", UserName = "testuser", Password = "pass" };
        _userStore.Setup(x => x.ValidateCredentialsAsync("testuser", "01", "pass"))
                  .ReturnsAsync(_testUser);
        _jwtService.Setup(x => x.GenerateAccessToken(_testUser)).Returns("access-token");
        _jwtService.Setup(x => x.GenerateRefreshToken(_testUser)).Returns(_testRefreshResult);
        _tokenStore.Setup(x => x.StoreAsync("token-id-123", It.IsAny<DateTime>()))
                   .Returns(Task.CompletedTask);

        // Act
        var result = await _sut.LoginAsync(request);

        // Assert
        result.Should().NotBeNull();
        result!.User.UserId.Should().Be("testuser");
        result.Tokens.AccessToken.Should().Be("access-token");
        result.Tokens.RefreshToken.Should().Be("refresh-token");
    }

    [Fact]
    public async Task LoginAsync_InvalidCredentials_ReturnsNull()
    {
        // Arrange
        var request = new LoginRequestDto { DivCode = "01", UserName = "bad", Password = "wrong" };
        _userStore.Setup(x => x.ValidateCredentialsAsync("bad", "01", "wrong"))
                  .ReturnsAsync((AuthUserDto?)null);

        // Act
        var result = await _sut.LoginAsync(request);

        // Assert
        result.Should().BeNull();
        _jwtService.Verify(x => x.GenerateAccessToken(It.IsAny<AuthUserDto>()), Times.Never);
    }

    // ── Refresh ───────────────────────────────────────────────

    [Fact]
    public async Task RefreshTokenAsync_ValidToken_ReturnsNewTokens()
    {
        // Arrange
        var validation = new RefreshTokenValidationResult
        {
            TokenId = "token-id-123",
            ExpiresAtUtc = DateTime.UtcNow.AddDays(7),
            User = _testUser
        };
        _jwtService.Setup(x => x.ValidateRefreshToken("old-refresh")).Returns(validation);
        _tokenStore.Setup(x => x.IsActiveAsync("token-id-123")).ReturnsAsync(true);
        _tokenStore.Setup(x => x.RevokeAsync("token-id-123")).Returns(Task.CompletedTask);
        _userStore.Setup(x => x.GetByUserIdAsync("testuser", "01")).ReturnsAsync(_testUser);
        _jwtService.Setup(x => x.GenerateAccessToken(_testUser)).Returns("new-access");
        _jwtService.Setup(x => x.GenerateRefreshToken(_testUser)).Returns(new JwtTokenResult
        {
            Token = "new-refresh", TokenId = "new-id", ExpiresAtUtc = DateTime.UtcNow.AddDays(7)
        });
        _tokenStore.Setup(x => x.StoreAsync("new-id", It.IsAny<DateTime>())).Returns(Task.CompletedTask);

        // Act
        var result = await _sut.RefreshTokenAsync(new RefreshTokenRequestDto { RefreshToken = "old-refresh" });

        // Assert
        result.Should().NotBeNull();
        result!.Tokens.AccessToken.Should().Be("new-access");
        _tokenStore.Verify(x => x.RevokeAsync("token-id-123"), Times.Once);
    }

    [Fact]
    public async Task RefreshTokenAsync_InvalidToken_ReturnsNull()
    {
        // Arrange
        _jwtService.Setup(x => x.ValidateRefreshToken("bad-token")).Returns((RefreshTokenValidationResult?)null);

        // Act
        var result = await _sut.RefreshTokenAsync(new RefreshTokenRequestDto { RefreshToken = "bad-token" });

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task RefreshTokenAsync_RevokedToken_ReturnsNull()
    {
        // Arrange
        var validation = new RefreshTokenValidationResult
        {
            TokenId = "revoked-id", ExpiresAtUtc = DateTime.UtcNow.AddDays(7), User = _testUser
        };
        _jwtService.Setup(x => x.ValidateRefreshToken("revoked-token")).Returns(validation);
        _tokenStore.Setup(x => x.IsActiveAsync("revoked-id")).ReturnsAsync(false);

        // Act
        var result = await _sut.RefreshTokenAsync(new RefreshTokenRequestDto { RefreshToken = "revoked-token" });

        // Assert
        result.Should().BeNull();
    }

    // ── Logout ────────────────────────────────────────────────

    [Fact]
    public async Task LogoutAsync_ValidToken_RevokesToken()
    {
        // Arrange
        var validation = new RefreshTokenValidationResult
        {
            TokenId = "token-id-123", ExpiresAtUtc = DateTime.UtcNow.AddDays(7), User = _testUser
        };
        _jwtService.Setup(x => x.ValidateRefreshToken("refresh-token")).Returns(validation);
        _tokenStore.Setup(x => x.RevokeAsync("token-id-123")).Returns(Task.CompletedTask);

        // Act
        await _sut.LogoutAsync("refresh-token");

        // Assert
        _tokenStore.Verify(x => x.RevokeAsync("token-id-123"), Times.Once);
    }

    [Fact]
    public async Task LogoutAsync_NullToken_DoesNothing()
    {
        // Act
        await _sut.LogoutAsync(null);

        // Assert
        _tokenStore.Verify(x => x.RevokeAsync(It.IsAny<string>()), Times.Never);
    }
}
