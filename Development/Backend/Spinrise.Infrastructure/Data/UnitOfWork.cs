using System.Data;
using Microsoft.AspNetCore.Http;
using Spinrise.Shared.Constants;

namespace Spinrise.Infrastructure.Data;

public class UnitOfWork : IUnitOfWork
{
    private readonly IDbConnection _connection;
    private IDbTransaction? _transaction;
    private bool _disposed;
    private bool _opened;

    public UnitOfWork(IDbConnectionFactory factory, IHttpContextAccessor httpContextAccessor)
    {
        var dbName = httpContextAccessor.HttpContext?.Items[SpinriseClaims.DbName] as string
            ?? "JAT";
        _connection = factory.CreateConnection(dbName);
        // Connection opened lazily on first use — not here.
        // Opening in the constructor fires even for [AllowAnonymous] endpoints that
        // have no JWT token, causing a failed connection attempt to the fallback DB.
    }

    public IDbConnection Connection
    {
        get
        {
            if (!_opened)
            {
                _connection.Open();
                _opened = true;
            }
            return _connection;
        }
    }
    public IDbTransaction? Transaction => _transaction;

    public Task BeginTransactionAsync()
    {
        _transaction = Connection.BeginTransaction();   // uses lazy getter — opens if not yet open
        return Task.CompletedTask;
    }

    public Task CommitAsync()
    {
        _transaction?.Commit();
        _transaction?.Dispose();
        _transaction = null;
        return Task.CompletedTask;
    }

    public Task RollbackAsync()
    {
        _transaction?.Rollback();
        _transaction?.Dispose();
        _transaction = null;
        return Task.CompletedTask;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _transaction?.Dispose();
        _connection.Dispose();
        _disposed = true;
    }
}
