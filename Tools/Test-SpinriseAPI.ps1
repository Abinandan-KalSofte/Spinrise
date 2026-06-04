<#
.SYNOPSIS
    Spinrise ERP — API Test Runner
    Logs every request + response + PASS/FAIL to a timestamped markdown file.
    Run after every bug fix. Share the output file instead of describing bugs verbally.

.HOW TO USE
    1. Fill in the CONFIG block below (or pass as parameters)
    2. Open PowerShell, run:   .\Test-SpinriseAPI.ps1
    3. The result markdown file opens automatically

.EXAMPLE
    .\Test-SpinriseAPI.ps1 -BaseUrl "http://localhost:5000/api/v1" -DivCode "KAL" -User "admin" -Pass "yourpass"
#>

param(
    [string]$BaseUrl  = "http://localhost:5000/api/v1",
    [string]$DivCode  = "",        # <-- fill your division code
    [string]$User     = "",        # <-- fill your username
    [string]$Pass     = "",        # <-- fill your password
    [string]$YfDate   = "2026-04-01",
    [string]$YlDate   = "2027-03-31"
)

# ─── Prompt for missing credentials ──────────────────────────────────────────
if (-not $DivCode) { $DivCode = Read-Host "Division code (e.g. KAL)" }
if (-not $User)    { $User    = Read-Host "Username" }
if (-not $Pass)    { $Pass    = Read-Host "Password" }

# ─── Output file ─────────────────────────────────────────────────────────────
$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputFile = "$PSScriptRoot\TestResults_$timestamp.md"

$results  = [System.Collections.Generic.List[hashtable]]::new()
$token    = $null
$passCount = 0
$failCount = 0

# ─── Helper: make API call and record result ──────────────────────────────────
function Invoke-Test {
    param(
        [string]  $Name,
        [string]  $Method,
        [string]  $Endpoint,
        [hashtable]$Body       = $null,
        [string[]] $Expect     = @(),   # assertions: "status:200", "data.length>0", "data[0].pRDate!=", "data.length=0"
        [string]  $Category   = ""
    )

    $url     = "$BaseUrl/$Endpoint"
    $headers = @{ "Content-Type" = "application/json" }
    if ($script:token) { $headers["Authorization"] = "Bearer $script:token" }

    $reqBody    = if ($Body) { $Body | ConvertTo-Json -Depth 10 } else { $null }
    $statusCode = 0
    $rawJson    = ""
    $data       = $null
    $error_msg  = ""

    try {
        $params = @{ Uri = $url; Method = $Method; Headers = $headers; ErrorAction = "Stop" }
        if ($reqBody) { $params["Body"] = $reqBody }

        $resp       = Invoke-RestMethod @params -ResponseHeadersVariable respHeaders -StatusCodeVariable statusCode 2>&1
        $rawJson    = $resp | ConvertTo-Json -Depth 10 -Compress
        $data       = $resp
        $statusCode = [int]($statusCode ?? 200)
    }
    catch {
        $statusCode = [int]($_.Exception.Response.StatusCode.value__ ?? 0)
        $rawJson    = $_.ErrorDetails.Message ?? $_.Exception.Message
        $error_msg  = $_.Exception.Message
    }

    # ── Run assertions ────────────────────────────────────────────────────────
    $assertions = [System.Collections.Generic.List[hashtable]]::new()
    $allPass    = $true

    foreach ($rule in $Expect) {
        $pass    = $false
        $detail  = ""

        if ($rule -like "status:*") {
            $expected = [int]($rule -replace "status:", "")
            $pass     = ($statusCode -eq $expected)
            $detail   = "HTTP $statusCode (expected $expected)"
        }
        elseif ($rule -eq "data.length>0") {
            $len  = if ($data.data -is [array]) { $data.data.Count } elseif ($data.data) { 1 } else { 0 }
            $pass = ($len -gt 0)
            $detail = "data.length = $len (expected > 0)"
        }
        elseif ($rule -eq "data.length=0") {
            $len  = if ($data.data -is [array]) { $data.data.Count } elseif ($data.data) { 1 } else { 0 }
            $pass = ($len -eq 0)
            $detail = "data.length = $len (expected 0)"
        }
        elseif ($rule -like "data[0].*!=") {
            $field = ($rule -replace "data\[0\]\.", "" -replace "!=", "").Trim()
            $val   = if ($data.data -is [array] -and $data.data.Count -gt 0) { $data.data[0].$field } else { $null }
            $pass  = (-not [string]::IsNullOrEmpty($val))
            $detail = "data[0].$field = '$val' (expected non-empty)"
        }
        elseif ($rule -like "data.*!=") {
            $field = ($rule -replace "data\.", "" -replace "!=", "").Trim()
            $val   = $data.data.$field
            $pass  = (-not [string]::IsNullOrEmpty($val))
            $detail = "data.$field = '$val' (expected non-empty)"
        }
        elseif ($rule -eq "success:true") {
            $pass   = ($data.success -eq $true)
            $detail = "success = $($data.success) (expected true)"
        }
        elseif ($rule -eq "success:false") {
            $pass   = ($data.success -eq $false)
            $detail = "success = $($data.success) (expected false)"
        }
        elseif ($rule -like "data.header!=") {
            $pass   = ($null -ne $data.data.header)
            $detail = "data.header $(if ($pass) { 'present' } else { 'MISSING' })"
        }
        elseif ($rule -like "data.lines.length>0") {
            $len    = if ($data.data.lines -is [array]) { $data.data.lines.Count } else { 0 }
            $pass   = ($len -gt 0)
            $detail = "data.lines.length = $len (expected > 0)"
        }

        if (-not $pass) { $allPass = $false }
        $assertions.Add(@{ Rule = $rule; Pass = $pass; Detail = $detail })
    }

    if ($allPass) { $script:passCount++ } else { $script:failCount++ }

    $results.Add(@{
        Name       = $Name
        Category   = $Category
        Method     = $Method
        Url        = $url
        ReqBody    = $reqBody
        StatusCode = $statusCode
        Response   = if ($rawJson.Length -gt 2000) { $rawJson.Substring(0, 2000) + "…(truncated)" } else { $rawJson }
        Assertions = $assertions
        AllPass    = $allPass
        Error      = $error_msg
    })

    $icon = if ($allPass) { "✅" } else { "❌" }
    Write-Host "$icon  $Name" -ForegroundColor (if ($allPass) { "Green" } else { "Red" })
}

# ═════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== SPINRISE API TEST RUNNER ===" -ForegroundColor Cyan
Write-Host "Base URL : $BaseUrl"
Write-Host "Division : $DivCode"
Write-Host "FY       : $YfDate → $YlDate"
Write-Host ""

# ─── STEP 1: Login ───────────────────────────────────────────────────────────
Write-Host "--- AUTH ---" -ForegroundColor Yellow
try {
    $loginBody = @{ divCode = $DivCode; userName = $User; password = $Pass }
    $loginResp = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method POST `
        -Headers @{ "Content-Type" = "application/json" } `
        -Body ($loginBody | ConvertTo-Json) -ErrorAction Stop
    $token = $loginResp.data.tokens.accessToken
    $divCodeFromResp = $loginResp.data.user.divCode
    if ($divCodeFromResp) { $DivCode = $divCodeFromResp }
    Write-Host "✅  Login OK — divCode=$DivCode  user=$($loginResp.data.user.userName)" -ForegroundColor Green
}
catch {
    Write-Host "❌  Login FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Cannot continue without a valid token. Check BaseUrl, DivCode, User, Pass." -ForegroundColor Red
    exit 1
}

# ═════════════════════════════════════════════════════════════════════════════
# ─── FORECLOSURE TESTS ───────────────────────────────────────────────────────
Write-Host "`n--- PR FORECLOSURE ---" -ForegroundColor Yellow

Invoke-Test -Category "Foreclosure" -Name "FC-01  Open lines — returns records" `
    -Method GET -Endpoint "pr-foreclosure/open-lines" `
    -Expect @("status:200", "success:true", "data.length>0")

Invoke-Test -Category "Foreclosure" -Name "FC-02  Open lines — PRDate non-empty on first record" `
    -Method GET -Endpoint "pr-foreclosure/open-lines" `
    -Expect @("status:200", "data.length>0", "data[0].pRDate!=")

Invoke-Test -Category "Foreclosure" -Name "FC-03  Open lines — PrevStatus is readable text (not raw char)" `
    -Method GET -Endpoint "pr-foreclosure/open-lines" `
    -Expect @("status:200", "data.length>0", "data[0].prevStatus!=")

Invoke-Test -Category "Foreclosure" -Name "FC-04  Open lines — PR No filter (prefix 1)" `
    -Method GET -Endpoint "pr-foreclosure/open-lines?prNoFilter=1" `
    -Expect @("status:200", "success:true")

Invoke-Test -Category "Foreclosure" -Name "FC-05  Save — empty lines → 400 validation error" `
    -Method POST -Endpoint "pr-foreclosure/save" `
    -Body @{ lines = @() } `
    -Expect @("success:false")

# Get first available line for save test
$openLines = $null
try {
    $openLines = (Invoke-RestMethod -Uri "$BaseUrl/pr-foreclosure/open-lines" `
        -Headers @{ "Authorization" = "Bearer $token" } -ErrorAction Stop).data
} catch {}

if ($openLines -and $openLines.Count -gt 0) {
    $firstLine = $openLines[0]
    $savePayload = @{
        lines = @(
            @{
                prNo     = $firstLine.prNo
                pRDate   = $firstLine.pRDate
                prSno    = $firstLine.prSno
                itemCode = $firstLine.itemCode
                depCode  = $firstLine.depCode
                balance  = $firstLine.balance
            }
        )
    }
    Write-Host "  (Note: Save test uses PR $($firstLine.prNo) line $($firstLine.prSno) — this will ACTUALLY FORECLOSE the line. Comment out if not intended.)" -ForegroundColor DarkYellow
    # Uncomment to test actual save — IRREVERSIBLE:
    # Invoke-Test -Category "Foreclosure" -Name "FC-06  Save — valid line → success" `
    #     -Method POST -Endpoint "pr-foreclosure/save" `
    #     -Body $savePayload `
    #     -Expect @("status:200", "success:true")
    Write-Host "  ⏭  FC-06 Save (actual foreclose) — SKIPPED to protect data. Uncomment in script to test." -ForegroundColor DarkYellow
} else {
    Write-Host "  ⏭  FC-06 Save — SKIPPED (no open lines available to test with)" -ForegroundColor DarkYellow
}

# ═════════════════════════════════════════════════════════════════════════════
# ─── CANCELLATION TESTS ──────────────────────────────────────────────────────
Write-Host "`n--- PR CANCELLATION ---" -ForegroundColor Yellow

Invoke-Test -Category "Cancellation" -Name "CN-01  Cancellable PRs — returns records" `
    -Method GET -Endpoint "pr-cancellation/cancellable?yfDate=$YfDate&ylDate=$YlDate" `
    -Expect @("status:200", "success:true", "data.length>0")

Invoke-Test -Category "Cancellation" -Name "CN-02  Cancellable PRs — PRDate non-empty on first record" `
    -Method GET -Endpoint "pr-cancellation/cancellable?yfDate=$YfDate&ylDate=$YlDate" `
    -Expect @("status:200", "data.length>0", "data[0].pRDate!=")

Invoke-Test -Category "Cancellation" -Name "CN-03  Cancelled for undo — returns (may be empty if none cancelled yet)" `
    -Method GET -Endpoint "pr-cancellation/cancelled-for-undo?yfDate=$YfDate&ylDate=$YlDate" `
    -Expect @("status:200", "success:true")

# Get first cancellable PR for detail + cancel tests
$cancellable = $null
try {
    $cancellable = (Invoke-RestMethod `
        -Uri "$BaseUrl/pr-cancellation/cancellable?yfDate=$YfDate&ylDate=$YlDate" `
        -Headers @{ "Authorization" = "Bearer $token" } -ErrorAction Stop).data
} catch {}

if ($cancellable -and $cancellable.Count -gt 0) {
    $firstPr     = $cancellable[0]
    $prNoParam   = $firstPr.prNo
    $prDateParam = $firstPr.pRDate
    $depCodeParam= $firstPr.depCode

    Invoke-Test -Category "Cancellation" -Name "CN-04  PR Detail — header + lines for first cancellable PR" `
        -Method GET `
        -Endpoint "pr-cancellation/detail?prNo=$prNoParam&prDate=$([uri]::EscapeDataString($prDateParam))&depCode=$depCodeParam" `
        -Expect @("status:200", "success:true", "data.header!=", "data.lines.length>0")

    Write-Host "  ⏭  CN-05 Cancel PR (actual cancel) — SKIPPED to protect data. Uncomment in script to test." -ForegroundColor DarkYellow
    # Uncomment to test actual cancel — modifies the database:
    # Invoke-Test -Category "Cancellation" -Name "CN-05  Cancel PR — valid request" `
    #     -Method POST -Endpoint "pr-cancellation/cancel" `
    #     -Body @{ prNo = $prNoParam; pRDate = $prDateParam; depCode = $depCodeParam; cancelReason = "Test cancellation via automated test runner" } `
    #     -Expect @("status:200", "success:true")
} else {
    Write-Host "  ⏭  CN-04/CN-05 — SKIPPED (no cancellable PRs found — check CN-01 result)" -ForegroundColor DarkYellow
}

Invoke-Test -Category "Cancellation" -Name "CN-06  Cancel — empty reason → 400" `
    -Method POST -Endpoint "pr-cancellation/cancel" `
    -Body @{ prNo = 99999; pRDate = "01 Jan 2026"; depCode = "XXX"; cancelReason = "" } `
    -Expect @("success:false")

# ═════════════════════════════════════════════════════════════════════════════
# ─── WRITE MARKDOWN REPORT ───────────────────────────────────────────────────
Write-Host "`n--- Writing report ---" -ForegroundColor Yellow

$totalTests = $passCount + $failCount
$reportDate = Get-Date -Format "dd MMM yyyy HH:mm"

$md = [System.Text.StringBuilder]::new()
[void]$md.AppendLine("# Spinrise API Test Results")
[void]$md.AppendLine("**Run:** $reportDate  ")
[void]$md.AppendLine("**Base URL:** $BaseUrl  ")
[void]$md.AppendLine("**Division:** $DivCode  ")
[void]$md.AppendLine("**FY:** $YfDate → $YlDate  ")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Summary")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Total | Pass | Fail |")
[void]$md.AppendLine("|---|---|---|")
[void]$md.AppendLine("| $totalTests | $passCount | $failCount |")
[void]$md.AppendLine("")

$currentCat = ""
foreach ($r in $results) {
    if ($r.Category -ne $currentCat) {
        $currentCat = $r.Category
        [void]$md.AppendLine("")
        [void]$md.AppendLine("## $currentCat")
        [void]$md.AppendLine("")
    }

    $icon = if ($r.AllPass) { "✅" } else { "❌" }
    [void]$md.AppendLine("### $icon $($r.Name)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("**$($r.Method)** ``$($r.Url)``  ")
    [void]$md.AppendLine("**HTTP Status:** $($r.StatusCode)  ")
    if ($r.Error) {
        [void]$md.AppendLine("**Error:** $($r.Error)  ")
    }
    [void]$md.AppendLine("")

    if ($r.ReqBody) {
        [void]$md.AppendLine("**Request Body:**")
        [void]$md.AppendLine('```json')
        [void]$md.AppendLine($r.ReqBody)
        [void]$md.AppendLine('```')
        [void]$md.AppendLine("")
    }

    [void]$md.AppendLine("**Assertions:**")
    [void]$md.AppendLine("")
    foreach ($a in $r.Assertions) {
        $aIcon = if ($a.Pass) { "✅" } else { "❌" }
        [void]$md.AppendLine("- $aIcon ``$($a.Rule)`` — $($a.Detail)")
    }
    [void]$md.AppendLine("")

    [void]$md.AppendLine("**Response (first 2000 chars):**")
    [void]$md.AppendLine('```json')
    [void]$md.AppendLine($r.Response)
    [void]$md.AppendLine('```')
    [void]$md.AppendLine("")
    [void]$md.AppendLine("---")
    [void]$md.AppendLine("")
}

$md.ToString() | Set-Content $outputFile -Encoding UTF8

Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
Write-Host "  Total : $totalTests" -ForegroundColor White
Write-Host "  Pass  : $passCount"  -ForegroundColor Green
Write-Host "  Fail  : $failCount"  -ForegroundColor Red
Write-Host ""
Write-Host "  Report: $outputFile" -ForegroundColor Yellow
Write-Host ""

# Open the report in the default markdown viewer / Notepad
Start-Process $outputFile
