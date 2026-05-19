using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.Security.Auth.DTOs;

public class RefreshTokenRequestDto
{
    [Required]
    public string RefreshToken { get; set; } = null!;
}
