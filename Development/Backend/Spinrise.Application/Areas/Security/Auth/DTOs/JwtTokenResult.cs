namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class JwtTokenResult
{
    public string Token { get; set; } = null!;
    public string TokenId { get; set; } = null!;
    public DateTime ExpiresAtUtc { get; set; }
}
