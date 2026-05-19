namespace Spinrise.Shared.Models;

public class ApiResponse<T>
{
    public bool Success { get; init; }
    public string Message { get; init; } = string.Empty;
    public T? Data { get; init; }
    public IReadOnlyList<string>? Warnings { get; init; }
    public object? Errors { get; init; }

    public static ApiResponse<T> Ok(T data, string message = "Success") =>
        new() { Success = true, Message = message, Data = data };

    public static ApiResponse<T> Fail(string message, object? errors = null) =>
        new() { Success = false, Message = message, Errors = errors };
}
