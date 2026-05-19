using Spinrise.Application.Areas.Security.Auth.DTOs;

namespace Spinrise.Application.Areas.Security.Auth.Interfaces;

public interface IAuthUserStore
{
    Task<AuthUserDto?> ValidateCredentialsAsync(string userName, string divCode, string password);
    Task<AuthUserDto?> GetByUserIdAsync(string userId, string divCode);
}
