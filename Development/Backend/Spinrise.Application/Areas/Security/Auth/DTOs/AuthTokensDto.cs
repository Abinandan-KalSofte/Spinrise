namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class AuthTokensDto
{
    public string AccessToken { get; set; } = null!;
    public string RefreshToken { get; set; } = null!;
}
