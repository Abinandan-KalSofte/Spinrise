using Spinrise.Application.Areas.Security.Division.DTOs;

namespace Spinrise.Application.Areas.Security.Division.Interfaces;

public interface IDivisionRepository
{
    Task<IEnumerable<ActiveDivisionDto>> GetActiveDivisionsAsync();
}
