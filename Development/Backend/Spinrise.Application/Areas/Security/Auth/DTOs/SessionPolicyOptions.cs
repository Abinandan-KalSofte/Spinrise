namespace Spinrise.Application.Areas.Security.Auth.DTOs;

/// <summary>
/// Session lifetime / idle policy, bound from the "Jwt" configuration section.
///
/// Lives in Application (not Infrastructure, alongside JwtOptions) because AuthService enforces the
/// absolute cap and Application must not depend on Infrastructure. Both types bind from the same
/// section, so the values cannot drift apart.
/// </summary>
public class SessionPolicyOptions
{
    /// <summary>Hard ceiling from the original login. Enforced on refresh.</summary>
    public int AbsoluteSessionHours { get; set; } = 12;

    /// <summary>Client idle cut-off, in minutes.</summary>
    public int IdleMinutes { get; set; } = 30;

    /// <summary>How long before the idle cut-off the warning modal appears.</summary>
    public int IdleWarningMinutes { get; set; } = 2;
}
