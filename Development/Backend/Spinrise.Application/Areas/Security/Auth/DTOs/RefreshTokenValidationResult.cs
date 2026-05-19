namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class RefreshTokenValidationResult
{
    public string TokenId { get; set; } = null!;
    public DateTime ExpiresAtUtc { get; set; }
    public AuthUserDto User { get; set; } = null!;
}
