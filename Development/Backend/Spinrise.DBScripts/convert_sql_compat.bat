@echo off
setlocal

:: convert_sql_compat.bat
:: ---------------------------------------------------------------
:: Reads  : merged.sql              (source - keep with CREATE OR ALTER)
:: Creates: merged_compatible.sql   (deploy to SQL Server 2012/2014/2016 RTM)
::
:: Run from: Development\Backend\Spinrise.DBScripts\
::           OR double-click - path is detected automatically
:: ---------------------------------------------------------------

set "BATCHDIR=%~dp0"
set "SRCFILE=%BATCHDIR%merged.sql"
set "OUTFILE=%BATCHDIR%merged_compatible.sql"
set "CONVPS=%TEMP%\spinrise_conv_%RANDOM%.ps1"

if not exist "%SRCFILE%" (
    echo.
    echo  ERROR: merged.sql not found at:
    echo    %SRCFILE%
    echo.
    echo  Run this batch from the Spinrise.DBScripts folder.
    echo.
    pause
    exit /b 1
)

:: Write the PowerShell conversion script line by line
:: Note: ^^ in batch echo outputs a single ^ to the file
::       ^& in batch echo outputs & to the file

>  "%CONVPS%" echo $srcFile = '%SRCFILE%'
>> "%CONVPS%" echo $outFile = '%OUTFILE%'
>> "%CONVPS%" echo $content = [System.IO.File]::ReadAllText($srcFile, [System.Text.Encoding]::UTF8)
>> "%CONVPS%" echo $count   = [regex]::Matches($content, 'CREATE OR ALTER PROCEDURE').Count
>> "%CONVPS%" echo $result  = [regex]::Replace(
>> "%CONVPS%" echo     $content,
>> "%CONVPS%" echo     '(?m)^^CREATE OR ALTER PROCEDURE\s+([\w.\[\]]+)',
>> "%CONVPS%" echo     {
>> "%CONVPS%" echo         param($m)
>> "%CONVPS%" echo         $p = $m.Groups[1].Value
>> "%CONVPS%" echo         "IF OBJECT_ID('$p', 'P') IS NULL`r`n    EXEC('CREATE PROCEDURE $p AS SET NOCOUNT ON')`r`nGO`r`nALTER PROCEDURE $p"
>> "%CONVPS%" echo     }
>> "%CONVPS%" echo )
>> "%CONVPS%" echo [System.IO.File]::WriteAllText($outFile, $result, [System.Text.Encoding]::UTF8)
>> "%CONVPS%" echo Write-Host ''
>> "%CONVPS%" echo Write-Host '  ============================================' -ForegroundColor Cyan
>> "%CONVPS%" echo Write-Host '   Spinrise SQL Compatibility Converter' -ForegroundColor Cyan
>> "%CONVPS%" echo Write-Host '  ============================================' -ForegroundColor Cyan
>> "%CONVPS%" echo Write-Host ''
>> "%CONVPS%" echo Write-Host "  Procedures converted : $count" -ForegroundColor Green
>> "%CONVPS%" echo Write-Host "  Output file          : $outFile" -ForegroundColor Green
>> "%CONVPS%" echo Write-Host ''
>> "%CONVPS%" echo Write-Host '  Source (unchanged)   : merged.sql'
>> "%CONVPS%" echo Write-Host '  Deploy to live DB    : merged_compatible.sql' -ForegroundColor Yellow
>> "%CONVPS%" echo Write-Host ''
>> "%CONVPS%" echo Write-Host '  Steps to deploy:' -ForegroundColor White
>> "%CONVPS%" echo Write-Host '    1. Open merged_compatible.sql in SSMS'
>> "%CONVPS%" echo Write-Host '    2. Connect to your live SQL Server'
>> "%CONVPS%" echo Write-Host '    3. Select the correct database (JAT or SpinRiseSaranya)'
>> "%CONVPS%" echo Write-Host '    4. Press F5 to execute'
>> "%CONVPS%" echo Write-Host ''
>> "%CONVPS%" echo Read-Host 'Press Enter to close'

powershell -NoProfile -ExecutionPolicy Bypass -File "%CONVPS%"
set "PSCODE=%errorlevel%"
del "%CONVPS%" 2>nul

if %PSCODE% neq 0 (
    echo.
    echo  CONVERSION FAILED. See error above.
    echo.
    pause
    exit /b 1
)
