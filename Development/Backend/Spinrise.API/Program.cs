using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using QuestPDF.Infrastructure;
using Serilog;
using Spinrise.API.Middleware;
using Spinrise.Application.Areas.Security.Auth.Interfaces;
using Spinrise.Application.Areas.Security.Auth.Services;
using Spinrise.Application.Areas.Security.Division.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.Services;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.Services;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.Services;
using Spinrise.Application.Areas.Security.Company.Interfaces;
using Spinrise.Infrastructure.Areas.Security.Company;
using Spinrise.Application.Areas.Security.Database.Interfaces;
using Spinrise.Infrastructure.Areas.Security.Database;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.Services;
using Spinrise.Infrastructure.Areas.PurchaseOrder.FinalLevelApproval;
using Spinrise.Infrastructure.Areas.Security.Auth;
using Spinrise.Infrastructure.Areas.Security.Division;
using Spinrise.Infrastructure.Areas.PurchaseOrder.PurchaseRequisition;
using Spinrise.Infrastructure.Areas.PurchaseOrder.Amendment;
using Spinrise.Infrastructure.Areas.PurchaseOrder.FirstLevelApproval;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.Services;
using Spinrise.Infrastructure.Areas.PurchaseOrder.PoEntry;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Interfaces;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.Services;
using Spinrise.Infrastructure.Areas.PurchaseOrder.PrReport;
using Dapper;
using Spinrise.Infrastructure.Data;

SqlMapper.AddTypeHandler(new DateOnlyTypeHandler());
QuestPDF.Settings.License = LicenseType.Community;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .ReadFrom.Configuration(ctx.Configuration));

// ── CORS ──────────────────────────────────────────────────────────────────
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(allowedOrigins)
     .AllowAnyHeader()
     .AllowAnyMethod()
     .AllowCredentials()));

// ── JWT Authentication ─────────────────────────────────────────────────────
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));

var jwtSection = builder.Configuration.GetSection("Jwt");
var secretKey = jwtSection["SecretKey"] ?? throw new InvalidOperationException("Jwt:SecretKey not configured.");
var issuer = jwtSection["Issuer"] ?? "Spinrise.API";
var audience = jwtSection["Audience"] ?? "Spinrise.Frontend";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = issuer,
            ValidateAudience = true,
            ValidAudience = audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero,
            NameClaimType = "email",
            RoleClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
        };
    });

builder.Services.AddAuthorization(o =>
    o.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build());

// ── MVC / Controllers ──────────────────────────────────────────────────────
builder.Services.AddControllers();

// ── Swagger ────────────────────────────────────────────────────────────────
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "Spinrise API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new()
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header
    });
    c.AddSecurityRequirement(new()
    {
        {
            new() { Reference = new() { Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "Bearer" } },
            []
        }
    });
});

// ── Infrastructure / DI ────────────────────────────────────────────────────
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<IDbConnectionFactory, DbConnectionFactory>();
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped<IDatabaseRepository, DatabaseRepository>();
builder.Services.AddScoped<IAuthUserStore, DbAuthUserStore>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddSingleton<IRefreshTokenStore, InMemoryRefreshTokenStore>();
builder.Services.AddScoped<IDivisionRepository, DivisionRepository>();
builder.Services.AddScoped<IPrRepository, PrRepository>();
builder.Services.AddScoped<IPrService, PrService>();
builder.Services.AddScoped<IPrAmendmentRepository, PrAmendmentRepository>();
builder.Services.AddScoped<IPrAmendmentService, PrAmendmentService>();
builder.Services.AddScoped<IPrForeclosureRepository, PrForeclosureRepository>();
builder.Services.AddScoped<IPrForeclosureService, PrForeclosureService>();
builder.Services.AddScoped<IPrCancellationRepository, PrCancellationRepository>();
builder.Services.AddScoped<IPrCancellationService, PrCancellationService>();
builder.Services.AddScoped<IPrFirstApprovalRepository, PrFirstApprovalRepository>();
builder.Services.AddScoped<IPrFirstApprovalService, PrFirstApprovalService>();
builder.Services.AddScoped<IFinalLevelApprovalRepository, FinalLevelApprovalRepository>();
builder.Services.AddScoped<IFinalLevelApprovalService, FinalLevelApprovalService>();
builder.Services.AddScoped<ICompanyRepository, CompanyRepository>();
builder.Services.AddScoped<IPoEntryRepository, PoEntryRepository>();
builder.Services.AddScoped<IPoEntryService, PoEntryService>();
builder.Services.AddScoped<IPrReportRepository, PrReportRepository>();
builder.Services.AddScoped<IPrReportService, PrReportService>();
builder.Services.AddScoped<Spinrise.Reports.Areas.PurchaseOrder.Reports.PrItemwisePdfReport>();
builder.Services.AddScoped<Spinrise.Reports.Areas.PurchaseOrder.Reports.PrDeptWisePdfReport>();
builder.Services.AddScoped<Spinrise.Reports.Areas.PurchaseOrder.Reports.PrDateWisePdfReport>();

// ══════════════════════════════════════════════════════════════════════════
var app = builder.Build();
// ══════════════════════════════════════════════════════════════════════════

app.UseSerilogRequestLogging();
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseMiddleware<DbNameMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
