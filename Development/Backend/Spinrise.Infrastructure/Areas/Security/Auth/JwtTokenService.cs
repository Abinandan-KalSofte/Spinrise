using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Spinrise.Application.Areas.Security.Auth.DTOs;
using Spinrise.Application.Areas.Security.Auth.Interfaces;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.Security.Auth;

public class JwtTokenService : IJwtTokenService
{
    private readonly JwtOptions _options;

    public JwtTokenService(IOptions<JwtOptions> options)
    {
        _options = options.Value;
    }

    public string GenerateAccessToken(AuthUserDto user)
    {
        var claims = BuildClaims(user, "access");
        return CreateToken(claims, TimeSpan.FromMinutes(_options.AccessTokenMinutes));
    }

    public JwtTokenResult GenerateRefreshToken(AuthUserDto user)
    {
        var tokenId = Guid.NewGuid().ToString();
        var expiresAt = DateTime.UtcNow.AddDays(_options.RefreshTokenDays);

        var claims = BuildClaims(user, "refresh");
        claims.Add(new Claim(JwtRegisteredClaimNames.Jti, tokenId));

        var token = CreateToken(claims, TimeSpan.FromDays(_options.RefreshTokenDays));
        return new JwtTokenResult { Token = token, TokenId = tokenId, ExpiresAtUtc = expiresAt };
    }

    public RefreshTokenValidationResult? ValidateRefreshToken(string refreshToken)
    {
        try
        {
            var principal = ValidateToken(refreshToken);
            if (principal is null) return null;

            var tokenType = principal.FindFirstValue(SpinriseClaims.TokenType);
            if (tokenType != "refresh") return null;

            var tokenId = principal.FindFirstValue(JwtRegisteredClaimNames.Jti);
            var expClaim = principal.FindFirstValue(JwtRegisteredClaimNames.Exp);
            if (tokenId is null || expClaim is null) return null;

            var expiresAt = DateTimeOffset.FromUnixTimeSeconds(long.Parse(expClaim)).UtcDateTime;

            var user = new AuthUserDto
            {
                UserId   = principal.FindFirstValue(JwtRegisteredClaimNames.Email) ?? string.Empty,
                UserName = principal.FindFirstValue(SpinriseClaims.UserName)       ?? string.Empty,
                Email    = principal.FindFirstValue(JwtRegisteredClaimNames.Email) ?? string.Empty,
                Role     = principal.FindFirstValue(ClaimTypes.Role)               ?? string.Empty,
                DivCode  = principal.FindFirstValue(SpinriseClaims.DivCode)        ?? string.Empty,
                DbName   = principal.FindFirstValue(SpinriseClaims.DbName)         ?? string.Empty,
            };

            return new RefreshTokenValidationResult
            {
                TokenId = tokenId,
                ExpiresAtUtc = expiresAt,
                User = user
            };
        }
        catch
        {
            return null;
        }
    }

    private List<Claim> BuildClaims(AuthUserDto user, string tokenType) =>
    [
        new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
        new(JwtRegisteredClaimNames.Email, user.UserId),
        new(ClaimTypes.Role, user.Role),
        new(SpinriseClaims.DivCode, user.DivCode),
        new(SpinriseClaims.UserId, user.UserId),
        new(SpinriseClaims.UserName, user.UserName),
        new(SpinriseClaims.DbName, user.DbName),
        new(SpinriseClaims.TokenType, tokenType),
        new(JwtRegisteredClaimNames.Iat,
            DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(),
            ClaimValueTypes.Integer64)
    ];

    private string CreateToken(List<Claim> claims, TimeSpan expiry)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SecretKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.Add(expiry),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private ClaimsPrincipal? ValidateToken(string token)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SecretKey));
        var handler = new JwtSecurityTokenHandler();

        var parameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = _options.Issuer,
            ValidateAudience = true,
            ValidAudience = _options.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = key,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero,
            NameClaimType = JwtRegisteredClaimNames.Email,
            RoleClaimType = ClaimTypes.Role
        };

        return handler.ValidateToken(token, parameters, out _);
    }
}
