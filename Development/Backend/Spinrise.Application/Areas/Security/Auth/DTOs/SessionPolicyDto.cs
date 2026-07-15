namespace Spinrise.Application.Areas.Security.Auth.DTOs;

/// <summary>
/// Session lifetime and idle policy handed to the client at login and on every refresh.
/// </summary>
public class SessionPolicyDto
{
    /// <summary>Minutes of no user activity before the client signs the user out.</summary>
    public int IdleMinutes { get; set; }

    /// <summary>How long before the idle cut-off the warning modal appears.</summary>
    public int IdleWarningMinutes { get; set; }

    /// <summary>Hard ceiling from the original login. The server enforces this on refresh;
    /// the client uses it only to show a clean modal instead of a surprise 401.</summary>
    public int AbsoluteSessionHours { get; set; }

    /// <summary>Original login time. Carried unchanged across refreshes.</summary>
    public DateTime AuthTimeUtc { get; set; }

    /// <summary>When the absolute cap falls due — AuthTimeUtc + AbsoluteSessionHours.</summary>
    public DateTime SessionExpiresAtUtc { get; set; }
}
