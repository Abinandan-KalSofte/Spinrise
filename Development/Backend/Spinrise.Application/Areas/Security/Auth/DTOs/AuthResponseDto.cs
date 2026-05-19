namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class AuthResponseDto
{
    public AuthUserDto User { get; set; } = null!;
    public AuthTokensDto Tokens { get; set; } = null!;
}
