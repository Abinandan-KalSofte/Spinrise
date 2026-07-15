namespace Spinrise.Reports.Core.Interfaces;

public interface IPdfReport<TRequest>
{
    Task<byte[]> GenerateAsync(TRequest request, CancellationToken ct = default);
}
