namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class AuthUserDto
{
    public int    Id       { get; set; }
    public string UserId   { get; set; } = null!;
    public string UserName { get; set; } = null!;
    public string Email    { get; set; } = null!;
    public string Role     { get; set; } = null!;
    public string DivCode  { get; set; } = null!;
    public string DivName  { get; set; } = "";
    public string DbName   { get; set; } = null!;
    /// <summary>Comma-separated list of module numbers the user can access (e.g. "1,3,4,5").</summary>
    public string Modules  { get; set; } = "";
}
