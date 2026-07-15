namespace Spinrise.Reports.Core.Interfaces;

public interface IXlsxReport<TRequest>
{
    Task<byte[]> GenerateAsync(TRequest request, CancellationToken ct = default);
}
