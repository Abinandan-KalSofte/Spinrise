namespace Spinrise.Application.Areas.Security.Auth.Interfaces;

/// <summary>
/// Tracks live session families (the <c>sid</c> claim) and the ones that have been revoked.
///
/// This is what makes logout mean logout. Revoking the refresh token alone leaves the already-issued
/// access token working for the rest of its lifetime; denying the session id stops it on the next request.
///
/// The denylist is self-bounding: an entry only has to outlive the tokens that carry it, so it is
/// dropped once the session's absolute cap has passed.
/// </summary>
public interface ISessionRegistry
{
    /// <summary>Record a new session at login. <paramref name="expiresAtUtc"/> is the absolute cap.</summary>
    Task TrackAsync(string sessionId, string userId, DateTime expiresAtUtc);

    /// <summary>True if this session has been revoked (logout, logout-all, admin kill).</summary>
    Task<bool> IsRevokedAsync(string sessionId);

    /// <summary>Revoke one session.</summary>
    Task RevokeAsync(string sessionId);

    /// <summary>Revoke every live session belonging to a user.</summary>
    Task RevokeAllForUserAsync(string userId);
}
