using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class LoginRequestDto
{
    [Required]
    [StringLength(2, MinimumLength = 1)]
    public string DivCode { get; set; } = null!;

    [Required]
    [StringLength(100, MinimumLength = 1)]
    public string UserName { get; set; } = null!;

    [Required]
    public string Password { get; set; } = null!;

    [Required]
    [StringLength(128, MinimumLength = 1)]
    public string DbName { get; set; } = null!;
}
