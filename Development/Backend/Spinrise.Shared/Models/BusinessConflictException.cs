namespace Spinrise.Shared.Models;

public sealed class BusinessConflictException : Exception
{
    public BusinessConflictException(string message) : base(message) { }
}
