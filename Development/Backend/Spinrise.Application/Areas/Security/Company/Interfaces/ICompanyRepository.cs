using Spinrise.Application.Areas.Security.Company.DTOs;

namespace Spinrise.Application.Areas.Security.Company.Interfaces;

public interface ICompanyRepository
{
    Task<IEnumerable<ActiveCompanyDto>> GetActiveCompaniesAsync();
    Task<IEnumerable<ActiveCompanyDto>> GetActiveCompaniesAsync(string dbName);
}
