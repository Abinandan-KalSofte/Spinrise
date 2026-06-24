using System.Data;
using Dapper;
using Spinrise.Application.Areas.Security.Auth.DTOs;
using Spinrise.Application.Areas.Security.Auth.Interfaces;
using Spinrise.Infrastructure.Data;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Areas.Security.Auth;

public class DbAuthUserStore : IAuthUserStore
{
    private readonly IDbConnectionFactory _factory;

    public DbAuthUserStore(IDbConnectionFactory factory) => _factory = factory;

    public async Task<AuthUserDto?> ValidateCredentialsAsync(string userName, string divCode, string password, string dbName)
    {
        using var conn = _factory.CreateConnection(dbName);
        conn.Open();
        var record = await conn.QueryFirstOrDefaultAsync<PpPasswdRecord>(
            StoredProcedures.Auth.ValidateUser,
            new { DivCode = divCode, UserName = userName, Password = password },
            commandType: CommandType.StoredProcedure);

        return record is null ? null : MapToDto(record, dbName);
    }

    public async Task<AuthUserDto?> GetByUserIdAsync(string userId, string divCode, string dbName)
    {
        using var conn = _factory.CreateConnection(dbName);
        conn.Open();
        var record = await conn.QueryFirstOrDefaultAsync<PpPasswdRecord>(
            StoredProcedures.Auth.GetUserById,
            new { UserId = userId, DivCode = divCode },
            commandType: CommandType.StoredProcedure);

        return record is null ? null : MapToDto(record, dbName);
    }

    private static AuthUserDto MapToDto(PpPasswdRecord r, string dbName) => new()
    {
        Id       = 0,
        UserId   = r.UserId.Trim(),
        UserName = r.UserName.Trim(),
        Email    = r.UserId.Trim(),
        DivCode  = r.DivCode.Trim(),
        DivName  = r.DivName.Trim(),
        DbName   = dbName,
        Modules  = r.Modules ?? "",
        Role = r.ALevel switch
        {
            1 => UserRoles.Admin,
            2 => UserRoles.Manager,
            _ => UserRoles.User
        }
    };

    private class PpPasswdRecord
    {
        public string  DivCode  { get; set; } = null!;
        public string  UserId   { get; set; } = null!;
        public string  UserName { get; set; } = null!;
        public decimal ALevel   { get; set; }
        public string  Modules  { get; set; } = "";
        public string  DivName  { get; set; } = "";
    }
}
