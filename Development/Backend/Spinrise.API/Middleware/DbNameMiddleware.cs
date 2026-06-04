using System.IdentityModel.Tokens.Jwt;
using Spinrise.Shared.Constants;

namespace Spinrise.API.Middleware;

public class DbNameMiddleware
{
    private readonly RequestDelegate _next;

    public DbNameMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        var authHeader = context.Request.Headers.Authorization.FirstOrDefault();
        if (authHeader?.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) == true)
        {
            var token = authHeader["Bearer ".Length..];
            try
            {
                var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
                var dbName = jwt.Claims.FirstOrDefault(c => c.Type == SpinriseClaims.DbName)?.Value;
                if (!string.IsNullOrWhiteSpace(dbName))
                    context.Items[SpinriseClaims.DbName] = dbName;
            }
            catch { /* invalid token — let auth middleware reject it */ }
        }

        await _next(context);
    }
}
