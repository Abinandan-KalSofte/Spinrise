# Spinrise ERP V2

Enterprise ERP system — clean rebuild, module by module.

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | ASP.NET Core 8, Dapper, SQL Server |
| Frontend | React 19, TypeScript 6, Vite 8, Ant Design 6, Zustand |
| Database | SQL Server 2016 |
| Tests | xUnit + Moq + FluentAssertions (backend), Vitest (frontend) |

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Node.js 18+ and npm
- Network access to SQL Server at `172.16.16.52\sql2016`
- Databases: `SpinRiseSaranya`, `JAT`

## Getting Started

### 1. Clone

```bash
git clone <repo-url>
cd SpinriseV2
```

### 2. Backend Config

Create `Development/Backend/Spinrise.API/appsettings.Development.json` — obtain from the lead developer (not stored in repo):

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "<SpinRiseSaranya connection string>",
    "JATConnection": "<JAT connection string>"
  }
}
```

### 3. Frontend Config

Create `Development/spinrise-web/.env.local` — obtain from the lead developer:

```
VITE_API_BASE_URL=http://localhost:5000
```

### 4. Install and Run

**Backend**
```bash
cd Development/Backend
dotnet restore
dotnet run --project Spinrise.API
# API runs at http://localhost:5000
```

**Frontend** (new terminal)
```bash
cd Development/spinrise-web
npm install
npm run dev
# UI runs at http://localhost:5173
```

## Project Structure

```
Development/
├── Backend/
│   ├── Spinrise.API/            # Controllers, middleware, routing
│   ├── Spinrise.Application/    # Services, DTOs, interfaces
│   ├── Spinrise.Infrastructure/ # Dapper repositories, Unit of Work
│   ├── Spinrise.Domain/         # Core entities
│   ├── Spinrise.Shared/         # ApiResponse, utilities, constants
│   ├── Spinrise.DBScripts/      # SQL stored procedures
│   └── Spinrise.Tests/          # xUnit unit tests
└── spinrise-web/                # React frontend
    └── src/
        ├── features/            # Feature modules (pr, auth, ...)
        └── shared/              # Axios client, UI wrappers, hooks
```

## Dev Commands

### Backend
```bash
dotnet build Spinrise.sln                              # build all
dotnet test Spinrise.Tests/Spinrise.Tests.csproj       # run tests
dotnet run --project Spinrise.API                      # dev server
```

### Frontend
```bash
npm run dev      # dev server → http://localhost:5173
npm run build    # production build → dist/
npm run test     # Vitest unit tests
npm run lint     # ESLint
```

## Branch Strategy

Feature branches follow the pattern `feature/mXX-<slug>` and merge into `main`.

```
main
└── feature/m01-pr          # Purchase Requisition module
└── feature/m02-po          # (example next module)
```
