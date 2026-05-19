namespace Spinrise.Shared.Models;

public class ApiResponse
{
    public bool Success { get; init; }
    public string Message { get; init; } = string.Empty;
    public IReadOnlyList<string>? Warnings { get; init; }
    public object? Errors { get; init; }

    public static ApiResponse Ok(string message = "Success") =>
        new() { Success = true, Message = message };

    public static ApiResponse Fail(string message, object? errors = null) =>
        new() { Success = false, Message = message, Errors = errors };
}
