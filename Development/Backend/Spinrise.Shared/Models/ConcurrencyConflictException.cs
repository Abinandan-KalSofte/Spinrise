namespace Spinrise.Shared.Models;

public sealed class ConcurrencyConflictException : Exception
{
    public IReadOnlyList<(decimal PrNo, decimal PrSno)> ConflictItems { get; }

    public ConcurrencyConflictException(IEnumerable<(decimal, decimal)> items)
        : base("One or more records were modified by another user. Please refresh and try again.")
    {
        ConflictItems = items.ToList();
    }
}
