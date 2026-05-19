using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Spinrise.Infrastructure.Data;

public class UnitOfWork : IUnitOfWork
{
    private readonly IDbConnection _connection;
    private IDbTransaction? _transaction;
    private bool _disposed;

    public UnitOfWork(IConfiguration configuration)
    {
        _connection = new SqlConnection(
            configuration.GetConnectionString("DefaultConnection"));
        _connection.Open();
    }

    public IDbConnection Connection => _connection;
    public IDbTransaction? Transaction => _transaction;

    public Task BeginTransactionAsync()
    {
        _transaction = _connection.BeginTransaction();
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
