namespace Spinrise.Application.Areas.Security.Auth.Interfaces;

public interface IRefreshTokenStore
{
    Task StoreAsync(string tokenId, DateTime expiresAtUtc);
    Task<bool> IsActiveAsync(string tokenId);
    Task RevokeAsync(string tokenId);
}
