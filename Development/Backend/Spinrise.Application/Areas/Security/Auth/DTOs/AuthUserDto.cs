namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class AuthUserDto
{
    public int Id { get; set; }
    public string UserId { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Role { get; set; } = null!;
    public string DivCode { get; set; } = null!;
}
