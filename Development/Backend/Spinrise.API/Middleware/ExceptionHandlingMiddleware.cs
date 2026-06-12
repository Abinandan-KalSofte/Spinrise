using System.Net;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Spinrise.Shared.Models;

namespace Spinrise.API.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Unhandled exception | {Method} {Path} | User: {User} | {ExceptionType}: {Message}",
                context.Request.Method,
                context.Request.Path,
                context.User?.Identity?.Name ?? "anonymous",
                ex.GetType().Name,
                ex.Message);

            await WriteErrorResponse(context, ex);
        }
    }

    private static async Task WriteErrorResponse(HttpContext context, Exception ex)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, message) = Classify(ex);

        context.Response.StatusCode = statusCode;
        var response = ApiResponse.Fail(message);
        await context.Response.WriteAsync(
            JsonSerializer.Serialize(response, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            }));
    }

    private static (int statusCode, string message) Classify(Exception ex) => ex switch
    {
        // ── Business rule violations from service layer ──────────────────────────
        InvalidOperationException => (
            (int)HttpStatusCode.BadRequest,
            ex.Message),

        // ── Input validation failures (argument parsing in service layer) ────────
        ArgumentException => (
            (int)HttpStatusCode.BadRequest,
            ex.Message),

        // ── Authorisation failures ───────────────────────────────────────────────
        UnauthorizedAccessException => (
            (int)HttpStatusCode.Forbidden,
            ex.Message.Length > 0 ? ex.Message : "You are not authorised to perform this action."),

        // ── Concurrent edit conflicts ────────────────────────────────────────────
        ConcurrencyConflictException => (
            (int)HttpStatusCode.Conflict,
            ex.Message),

        // ── Business rule conflict (e.g. GRN raised, cannot delete) ─────────────
        BusinessConflictException => (
            (int)HttpStatusCode.Conflict,
            ex.Message),

        // ── Database exceptions ──────────────────────────────────────────────────
        SqlException sqlEx => (
            (int)HttpStatusCode.BadRequest,
            MapSqlException(sqlEx)),

        // ── Unexpected / infrastructure errors ───────────────────────────────────
        _ => (
            (int)HttpStatusCode.InternalServerError,
            "Something went wrong. Please try again or contact your administrator if the problem persists.")
    };

    // ── SQL error number → user-friendly message ─────────────────────────────────

    private static string MapSqlException(SqlException ex) => ex.Number switch
    {
        // Duplicate key (unique constraint)
        2601 or 2627 =>
            "A record with these details already exists. Please check for duplicates and try again.",

        // Foreign key constraint — insert/update references non-existent row
        547 =>
            "This operation references data that does not exist or has been removed. Please refresh and try again.",

        // NOT NULL constraint
        515 =>
            "A required field value is missing. Please fill in all mandatory fields and try again.",

        // String or binary data truncated
        8152 =>
            "One or more values entered are too long for the allowed field length. Please shorten them and try again.",

        // Arithmetic overflow
        8115 =>
            "A calculated value is out of range. Please check the quantities or rates entered.",

        // Deadlock
        1205 =>
            "The system was processing another request at the same time. Please try again.",

        // Request timeout
        -2 =>
            "The request took too long to complete. Please try again.",

        // All other SQL errors — sanitize message text before forwarding
        _ => SanitizeSqlMessage(ex.Message)
    };

    // ── Strip technical SQL terms from RAISERROR messages ────────────────────────
    // Legitimate user-authored RAISERROR messages (e.g. "PR already approved") pass through.
    // SQL Server system messages that leaked via CATCH/THROW are replaced.

    private static readonly string[] TechnicalSqlTerms =
    [
        "object '", "constraint '", "index '", "column '", "dbo.",
        "PO_", "PP_", "IN_ITEM", "IN_DEP", "IN_SCC",
        "mm_", "PR_EMP", "ksp_", "usp_",
        "Violation of", "conflicted with",
        "Cannot insert", "Cannot update", "Cannot delete"
    ];

    private static string SanitizeSqlMessage(string message)
    {
        bool hasTechnicalTerms = TechnicalSqlTerms.Any(term =>
            message.Contains(term, StringComparison.OrdinalIgnoreCase));

        return hasTechnicalTerms
            ? "The operation could not be completed due to a data error. Please try again or contact your administrator."
            : message;
    }
}
