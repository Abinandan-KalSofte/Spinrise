@echo off
setlocal enabledelayedexpansion

:: ================================================================
:: Spinrise ERP V2 -- Export Package Builder
::
:: Builds frontend + backend and packages them into a single
:: timestamped folder ready to transfer to the IIS server.
::
:: Output: D:\SpinriseV2\Exports\SpinriseV2_Package_YYYYMMDD_HHMM\
::   Spinrise.API\       .NET 8 publish output
::   spinrise-web\       Vite production build
::   Database\           merged.sql  (SpinRiseSaranya -- M01 PR)
::                       merged_jat.sql (JAT -- M02 RMI PO, when available)
::   DEPLOY_STEPS.txt    Step-by-step deployment guide
::
:: Usage: Double-click or run from any directory.
::        No Administrator rights required for packaging.
:: ================================================================

:: -- Configuration ------------------------------------------------
set SOLUTION_ROOT=D:\SpinriseV2\Development
set FRONTEND_SRC=%SOLUTION_ROOT%\spinrise-web
set BACKEND_PROJ=%SOLUTION_ROOT%\Backend\Spinrise.API\Spinrise.API.csproj
set DB_DIR=%SOLUTION_ROOT%\Backend\Spinrise.DBScripts
set EXPORT_ROOT=D:\SpinriseV2\Exports

:: -- Server references (from CLAUDE.md) ---------------------------
set SERVER_IP=172.16.16.40
set DB_SERVER=172.16.16.52\sql2016
set DB_NAME=SpinRiseSaranya
set DB_NAME_JAT=JAT
set API_PORT=5001
set WEB_PORT=3000

:: -- Timestamp via PowerShell (locale-safe) -----------------------
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmm"') do set TS=%%i
set PACKAGE_DIR=%EXPORT_ROOT%\SpinriseV2_Package_%TS%

:: -- Sub-folders --------------------------------------------------
set FE_OUT=%PACKAGE_DIR%\spinrise-web
set BE_OUT=%PACKAGE_DIR%\Spinrise.API
set DB_OUT=%PACKAGE_DIR%\Database
set TXT=%PACKAGE_DIR%\DEPLOY_STEPS.txt

:: ----------------------------------------------------------------
title Spinrise ERP V2 -- Export Package Builder
echo.
echo ================================================================
echo   Spinrise ERP V2  -  Export Package Builder
echo   %DATE%  %TIME%
echo ================================================================
echo   Output: %PACKAGE_DIR%
echo ================================================================
echo.

:: -- Pre-flight checks --------------------------------------------
where dotnet >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] dotnet CLI not found in PATH.
    echo         Install .NET 8 SDK: https://dotnet.microsoft.com/download
    pause
    exit /b 1
)

where npm >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] npm not found in PATH.
    echo         Install Node.js LTS: https://nodejs.org
    pause
    exit /b 1
)

if not exist "%BACKEND_PROJ%" (
    echo [ERROR] Backend project not found:
    echo         %BACKEND_PROJ%
    pause
    exit /b 1
)

if not exist "%FRONTEND_SRC%\package.json" (
    echo [ERROR] Frontend source not found:
    echo         %FRONTEND_SRC%
    pause
    exit /b 1
)

if not exist "%DB_DIR%\merged.sql" (
    echo [ERROR] merged.sql not found:
    echo         %DB_DIR%\merged.sql
    pause
    exit /b 1
)

:: -- Create output folders ----------------------------------------
if not exist "%EXPORT_ROOT%" mkdir "%EXPORT_ROOT%"
mkdir "%PACKAGE_DIR%"
mkdir "%FE_OUT%"
mkdir "%BE_OUT%"
mkdir "%DB_OUT%"

:: ================================================================
::  STEP 1 -- Frontend build
:: ================================================================
echo [1/3] Building frontend (npm run build)...
cd /d "%FRONTEND_SRC%"
@REM call npm run build
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Frontend build failed. Fix errors above and retry.
    rd /s /q "%PACKAGE_DIR%" >nul 2>&1
    pause
    exit /b 1
)

echo [1/3] Copying dist to package...
robocopy "%FRONTEND_SRC%\dist" "%FE_OUT%" /E /NJH /NJS /NFL /NDL
if %errorlevel% gtr 7 (
    echo [ERROR] robocopy failed with exit code %errorlevel%
    rd /s /q "%PACKAGE_DIR%" >nul 2>&1
    pause
    exit /b 1
)
echo [1/3] Frontend done.
echo.

:: ================================================================
::  STEP 2 -- Backend publish
:: ================================================================
echo [2/3] Publishing backend (dotnet publish -c Release)...
dotnet publish "%BACKEND_PROJ%" -c Release -o "%BE_OUT%" --no-self-contained
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Backend publish failed. Fix errors above and retry.
    rd /s /q "%PACKAGE_DIR%" >nul 2>&1
    pause
    exit /b 1
)
echo [2/3] Backend done.
echo.

:: ================================================================
::  STEP 3 -- Database scripts
:: ================================================================
echo [3/3] Copying database scripts...

:: M01 -- SpinRiseSaranya
copy "%DB_DIR%\merged.sql" "%DB_OUT%\merged.sql" >nul
echo         merged.sql       (M01 - SpinRiseSaranya)

:: M02 -- JAT (copy only if file exists; M02 may not be built yet)
if exist "%DB_DIR%\merged_jat.sql" (
    copy "%DB_DIR%\merged_jat.sql" "%DB_OUT%\merged_jat.sql" >nul
    echo         merged_jat.sql   (M02 - JAT)
) else (
    echo         merged_jat.sql   [SKIPPED - M02 not yet built]
)

echo [3/3] Database done.
echo.

:: ================================================================
::  Write DEPLOY_STEPS.txt
:: ================================================================
echo Writing DEPLOY_STEPS.txt...

(
echo ================================================================
echo  Spinrise ERP V2 -- Deployment Package
echo  Built   : %DATE%  %TIME%
echo  Package : SpinriseV2_Package_%TS%
echo ================================================================
echo.
echo PACKAGE CONTENTS
echo ----------------
echo   Spinrise.API\       .NET 8 publish output ^(backend^)
echo   spinrise-web\       Vite production build ^(frontend^)
echo   Database\           SQL scripts for all stored procedures
echo     merged.sql        M01 PR -- database: %DB_NAME%
echo     merged_jat.sql    M02 RMI PO -- database: %DB_NAME_JAT% ^(if present^)
echo   DEPLOY_STEPS.txt    This file
echo.
echo SERVER DETAILS
echo --------------
echo   Frontend URL : http://%SERVER_IP%:%WEB_PORT%
echo   Backend  URL : http://%SERVER_IP%:%API_PORT%
echo   DB Server    : %DB_SERVER%
echo   DB M01       : %DB_NAME%
echo   DB M02       : %DB_NAME_JAT%
echo.
echo PRE-REQUISITES ON TARGET SERVER
echo --------------------------------
echo   OS       : Windows Server 2016+
echo   IIS      : Enabled with ASP.NET Core Hosting Bundle ^(.NET 8^)
echo   App Pools: SpinriseAPI  ^(No Managed Code, 64-bit, port %API_PORT%^)
echo              SpinriseWeb  ^(No Managed Code, 64-bit, port %WEB_PORT%^)
echo   DB Access: Server must reach %DB_SERVER%
echo.
echo NOTE: These steps assume IIS sites and app pools are already
echo configured on the target server. This is an UPDATE deploy only.
echo.
echo ================================================================
echo  STEP 1 -- DATABASE  ^(run first, before restarting any app^)
echo ================================================================
echo.
echo   1a. M01 -- SpinRiseSaranya
echo       Open SSMS ^> Connect to: %DB_SERVER%
echo       Select database: %DB_NAME%
echo       Open: Database\merged.sql from this package
echo       Press F5 ^> Confirm "Commands completed successfully"
echo.
echo   1b. M02 -- JAT  ^(skip if merged_jat.sql is not in this package^)
echo       Select database: %DB_NAME_JAT%
echo       Open: Database\merged_jat.sql from this package
echo       Press F5 ^> Confirm "Commands completed successfully"
echo.
echo   IMPORTANT: Run DB scripts BEFORE deploying backend or frontend.
echo   All stored procedure changes are contained in these files.
echo.
echo ================================================================
echo  STEP 2 -- BACKEND  ^(Spinrise.API -- port %API_PORT%^)
echo ================================================================
echo.
echo   IIS site path example: E:\SpinriseV2\Server\Spinrise.API\
echo   ^(Adjust to the actual site path configured in IIS^)
echo.
echo   1. Open IIS Manager on the target server
echo   2. Application Pools ^> SpinriseAPI ^> Stop
echo      OR from Administrator cmd:
echo      %%windir%%\system32\inetsrv\appcmd stop apppool /apppool.name:"SpinriseAPI"
echo.
echo   3. BACKUP current files ^(recommended^):
echo      xcopy "E:\SpinriseV2\Server\Spinrise.API"
echo            "E:\SpinriseV2\Server\Spinrise.API_bak_%TS%" /E /I /Q
echo.
echo   4. CHECK appsettings.json before copying:
echo      Verify ConnectionStrings DefaultConnection points to %DB_SERVER%
echo      Database: %DB_NAME%
echo.
echo   5. Copy new backend files:
echo      robocopy "Spinrise.API" "E:\SpinriseV2\Server\Spinrise.API" /E /PURGE
echo.
echo   6. Start the app pool:
echo      %%windir%%\system32\inetsrv\appcmd start apppool /apppool.name:"SpinriseAPI"
echo.
echo   7. Verify: http://%SERVER_IP%:%API_PORT%/swagger
echo.
echo ================================================================
echo  STEP 3 -- FRONTEND  ^(spinrise-web -- port %WEB_PORT%^)
echo ================================================================
echo.
echo   IIS site path example: E:\SpinriseV2\Server\spinrise-web\
echo   ^(Adjust to the actual site path configured in IIS^)
echo.
echo   1. Stop app pool:
echo      %%windir%%\system32\inetsrv\appcmd stop apppool /apppool.name:"SpinriseWeb"
echo.
echo   2. Copy new frontend files:
echo      robocopy "spinrise-web" "E:\SpinriseV2\Server\spinrise-web" /E /PURGE
echo.
echo   3. Start app pool:
echo      %%windir%%\system32\inetsrv\appcmd start apppool /apppool.name:"SpinriseWeb"
echo.
echo   4. Verify: http://%SERVER_IP%:%WEB_PORT%
echo.
echo ================================================================
echo  STEP 4 -- SMOKE TEST
echo ================================================================
echo.
echo   1. Open http://%SERVER_IP%:%WEB_PORT% and log in
echo   2. Navigate to Purchase ^> Requisition
echo   3. Confirm the PR list loads without errors
echo   4. Open an existing PR -- verify fields, lookup popups, print
echo   5. Navigate with arrow buttons -- confirm correct order
echo   6. Click Print -- confirm PDF downloads with letterhead
echo.
echo ================================================================
echo  ROLLBACK
echo ================================================================
echo.
echo   Backend:
echo   1. Stop SpinriseAPI app pool
echo   2. Restore the _bak_%TS% folder created in Step 2.3
echo   3. Start SpinriseAPI app pool
echo.
echo   Frontend:
echo   1. Stop SpinriseWeb app pool
echo   2. Restore previous spinrise-web folder contents
echo   3. Start SpinriseWeb app pool
echo.
echo   Database:
echo   Stored procedures use CREATE OR ALTER -- they cannot be
echo   auto-rolled back. Re-run merged.sql from the previous
echo   package to restore the prior SP version if needed.
echo.
echo ================================================================
echo  Developer : Abinandan N  ^(abinandan.n@kalsofte.com^)
echo  Project   : Spinrise ERP V2
echo ================================================================
) > "%TXT%"

:: ================================================================
::  Done
:: ================================================================
echo.
echo ================================================================
echo   Package ready!
echo   %PACKAGE_DIR%
echo ================================================================
echo.
echo   Spinrise.API\       Backend publish
echo   spinrise-web\       Frontend build
echo   Database\           merged.sql (+ merged_jat.sql if present)
echo   DEPLOY_STEPS.txt    Deployment guide
echo.
echo   Transfer this folder to %SERVER_IP% and follow
echo   DEPLOY_STEPS.txt step by step.
echo.
pause
