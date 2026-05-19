using FluentAssertions;
using Spinrise.Infrastructure.Areas.Security.Auth;

namespace Spinrise.Tests.Areas.Security.Auth;

public class InMemoryRefreshTokenStoreTests
{
    private readonly InMemoryRefreshTokenStore _sut = new();

    [Fact]
    public async Task StoreAndIsActive_ActiveToken_ReturnsTrue()
    {
        var tokenId = Guid.NewGuid().ToString();
        await _sut.StoreAsync(tokenId, DateTime.UtcNow.AddHours(1));

        var result = await _sut.IsActiveAsync(tokenId);

        result.Should().BeTrue();
    }

    [Fact]
    public async Task IsActive_ExpiredToken_ReturnsFalse()
    {
        var tokenId = Guid.NewGuid().ToString();
        await _sut.StoreAsync(tokenId, DateTime.UtcNow.AddSeconds(-1));

        var result = await _sut.IsActiveAsync(tokenId);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task IsActive_UnknownToken_ReturnsFalse()
    {
        var result = await _sut.IsActiveAsync("does-not-exist");
        result.Should().BeFalse();
    }

    [Fact]
    public async Task Revoke_ActiveToken_BecomesInactive()
    {
        var tokenId = Guid.NewGuid().ToString();
        await _sut.StoreAsync(tokenId, DateTime.UtcNow.AddHours(1));

        await _sut.RevokeAsync(tokenId);

        var result = await _sut.IsActiveAsync(tokenId);
        result.Should().BeFalse();
    }

    [Fact]
    public async Task Revoke_NonexistentToken_DoesNotThrow()
    {
        var act = async () => await _sut.RevokeAsync("ghost-token");
        await act.Should().NotThrowAsync();
    }
}
