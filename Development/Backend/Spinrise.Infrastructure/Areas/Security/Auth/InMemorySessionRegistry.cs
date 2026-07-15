using System.Collections.Concurrent;
using Spinrise.Application.Areas.Security.Auth.Interfaces;

namespace Spinrise.Infrastructure.Areas.Security.Auth;

/// <summary>
/// Phase-1 in-process implementation of <see cref="ISessionRegistry"/>.
///
/// KNOWN LIMITATION — an IIS app-pool recycle clears both dictionaries. A session revoked just
/// before a recycle would have its access token honoured again for the remainder of that token's
/// life (&lt;= Jwt:AccessTokenMinutes). This is a deliberate, time-boxed gap: the durable
/// PP_UserSession-backed store (CR-AUTH-SESSION-01) removes it. Do not treat it as a bug — but do
/// not ship a second worker process against this either, because the registry is per-process.
/// </summary>
public class InMemorySessionRegistry : ISessionRegistry
{
    // sid -> (userId, absolute cap)
    private readonly ConcurrentDictionary<string, (string UserId, DateTime ExpiresAtUtc)> _sessions = new();

    // sid -> when the entry can be forgotten (the session's absolute cap; past that, every token
    // carrying this sid has expired on its own and the denylist entry is dead weight)
    private readonly ConcurrentDictionary<string, DateTime> _revoked = new();

    public Task TrackAsync(string sessionId, string userId, DateTime expiresAtUtc)
    {
        if (string.IsNullOrWhiteSpace(sessionId)) return Task.CompletedTask;

        Prune();
        _sessions[sessionId] = (userId, expiresAtUtc);
        return Task.CompletedTask;
    }

    public Task<bool> IsRevokedAsync(string sessionId)
    {
        if (string.IsNullOrWhiteSpace(sessionId))
            return Task.FromResult(false);

        if (!_revoked.TryGetValue(sessionId, out var forgetAt))
            return Task.FromResult(false);

        if (DateTime.UtcNow >= forgetAt)
        {
            _revoked.TryRemove(sessionId, out _);
            return Task.FromResult(false);
        }

        return Task.FromResult(true);
    }

    public Task RevokeAsync(string sessionId)
    {
        if (string.IsNullOrWhiteSpace(sessionId)) return Task.CompletedTask;

        // Hold the denial until the session's absolute cap. If the sid was never tracked (e.g. the
        // registry was reset by a recycle) fall back to a conservative window rather than dropping
        // the revocation on the floor.
        var forgetAt = _sessions.TryGetValue(sessionId, out var s)
            ? s.ExpiresAtUtc
            : DateTime.UtcNow.AddHours(24);

        _revoked[sessionId] = forgetAt;
        _sessions.TryRemove(sessionId, out _);
        return Task.CompletedTask;
    }

    public Task RevokeAllForUserAsync(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId)) return Task.CompletedTask;

        foreach (var (sid, entry) in _sessions)
        {
            if (string.Equals(entry.UserId, userId, StringComparison.OrdinalIgnoreCase))
            {
                _revoked[sid] = entry.ExpiresAtUtc;
                _sessions.TryRemove(sid, out _);
            }
        }

        return Task.CompletedTask;
    }

    /// <summary>Drop sessions and denials that have outlived every token that could carry them.
    /// Called on write, so neither dictionary grows without bound (the old refresh store did).</summary>
    private void Prune()
    {
        var now = DateTime.UtcNow;

        foreach (var (sid, entry) in _sessions)
            if (now >= entry.ExpiresAtUtc)
                _sessions.TryRemove(sid, out _);

        foreach (var (sid, forgetAt) in _revoked)
            if (now >= forgetAt)
                _revoked.TryRemove(sid, out _);
    }
}
