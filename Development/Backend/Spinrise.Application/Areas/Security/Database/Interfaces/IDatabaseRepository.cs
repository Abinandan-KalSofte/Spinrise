namespace Spinrise.Application.Areas.Security.Database.Interfaces;

public interface IDatabaseRepository
{
    Task<IEnumerable<string>> GetDatabasesAsync();
}
