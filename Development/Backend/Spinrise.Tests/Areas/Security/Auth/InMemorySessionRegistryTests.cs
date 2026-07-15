using FluentAssertions;
using Spinrise.Infrastructure.Areas.Security.Auth;

namespace Spinrise.Tests.Areas.Security.Auth;

public class InMemorySessionRegistryTests
{
    private readonly InMemorySessionRegistry _sut = new();

    [Fact]
    public async Task IsRevokedAsync_UnknownSession_ReturnsFalse()
    {
        (await _sut.IsRevokedAsync("never-seen")).Should().BeFalse();
    }

    [Fact]
    public async Task RevokeAsync_TrackedSession_IsThenRevoked()
    {
        await _sut.TrackAsync("sid-1", "testuser", DateTime.UtcNow.AddHours(12));

        (await _sut.IsRevokedAsync("sid-1")).Should().BeFalse();

        await _sut.RevokeAsync("sid-1");

        (await _sut.IsRevokedAsync("sid-1")).Should().BeTrue();
    }

    [Fact]
    public async Task RevokeAsync_UntrackedSession_StillRevokes()
    {
        // A recycle can wipe the tracked set while tokens are still in the wild. Losing the
        // revocation in that window would be strictly worse than holding a conservative denial.
        await _sut.RevokeAsync("sid-orphan");

        (await _sut.IsRevokedAsync("sid-orphan")).Should().BeTrue();
    }

    [Fact]
    public async Task RevokeAllForUserAsync_RevokesOnlyThatUsersSessions()
    {
        await _sut.TrackAsync("sid-a", "alice", DateTime.UtcNow.AddHours(12));
        await _sut.TrackAsync("sid-b", "alice", DateTime.UtcNow.AddHours(12));
        await _sut.TrackAsync("sid-c", "bob",   DateTime.UtcNow.AddHours(12));

        await _sut.RevokeAllForUserAsync("alice");

        (await _sut.IsRevokedAsync("sid-a")).Should().BeTrue();
        (await _sut.IsRevokedAsync("sid-b")).Should().BeTrue();
        (await _sut.IsRevokedAsync("sid-c")).Should().BeFalse();
    }

    [Fact]
    public async Task IsRevokedAsync_ExpiredDenial_IsForgotten()
    {
        // Once the session's absolute cap has passed, every token carrying the sid is dead on its
        // own — holding the denial forever is what made the old refresh store grow without bound.
        await _sut.TrackAsync("sid-old", "testuser", DateTime.UtcNow.AddMilliseconds(-1));
        await _sut.RevokeAsync("sid-old");

        (await _sut.IsRevokedAsync("sid-old")).Should().BeFalse();
    }

    [Fact]
    public async Task IsRevokedAsync_EmptySessionId_ReturnsFalse()
    {
        (await _sut.IsRevokedAsync("")).Should().BeFalse();
    }
}
