IIS Pre-Deploy Checklist — Spinrise ERP V2

  ---
  1. IIS Features (Windows Features)

  Check these are enabled via Server Manager → Add Roles and Features → Web Server (IIS):

  ┌───────────────────┬──────────────────────────┬─────────────────────────────────┐
  │      Feature      │  Path in Server Manager  │           Why needed            │
  ├───────────────────┼──────────────────────────┼─────────────────────────────────┤
  │ Static Content    │ Web Server → Common HTTP │ Serve index.html, JS, CSS       │
  ├───────────────────┼──────────────────────────┼─────────────────────────────────┤
  │ Default Document  │ Web Server → Common HTTP │ Load index.html on root request │
  ├───────────────────┼──────────────────────────┼─────────────────────────────────┤
  │ HTTP Errors       │ Web Server → Common HTTP │ Show proper error pages         │
  ├───────────────────┼──────────────────────────┼─────────────────────────────────┤
  │ Request Filtering │ Web Server → Security    │ Default security rules          │
  ├───────────────────┼──────────────────────────┼─────────────────────────────────┤
  │ URL Authorization │ Web Server → Security    │ Optional but good practice      │
  └───────────────────┴──────────────────────────┴─────────────────────────────────┘

  Quick check via PowerShell (run on the server):
  Get-WindowsFeature -Name Web-* | Where-Object { $_.InstallState -eq 'Installed' }

  ---
  2. ASP.NET Core Hosting Bundle (.NET 8)

  This is mandatory for the backend to run under IIS.

  Check:
  dotnet --list-runtimes
  # Must show: Microsoft.AspNetCore.App 8.x.x

  Check the IIS module is registered:
  IIS Manager → Server node → Modules → look for "AspNetCoreModuleV2"

  If missing → download and install .NET 8 Hosting Bundle from Microsoft, then run iisreset.

  ---
  3. URL Rewrite Module 2.x

  Required for:
  - SPA fallback (React Router — page refresh 404 fix)
  - API proxy rule in web.config

  Check:
  IIS Manager → Server node → Modules → look for "RewriteModule"

  Or via PowerShell:
  Get-Item "C:\Windows\System32\inetsrv\rewrite.dll" -ErrorAction SilentlyContinue

  If missing → install from: https://www.iis.net/downloads/microsoft/url-rewrite

  ---
  4. Application Request Routing (ARR) 3.x — CRITICAL

  This is the one most people miss.

  URL Rewrite alone cannot proxy to another server. When web.config rewrites /api/* to http://<backend-ip>:5001/api/..., IIS needs ARR installed to actually
  make that outbound HTTP call.

  Without ARR → the rewrite rule silently fails → all API calls return 502 Bad Gateway or serve a blank response.

  Check:
  IIS Manager → Server node → Modules → look for "ApplicationRequestRouting"

  Or:
  Get-Item "C:\Windows\System32\inetsrv\arr.dll" -ErrorAction SilentlyContinue

  If missing → install from: https://www.iis.net/downloads/microsoft/application-request-routing

  After installing ARR — enable proxy at server level (mandatory step):
  IIS Manager → Server node → Application Request Routing Cache
  → Server Proxy Settings → check "Enable proxy" → Apply

  If "Enable proxy" is not checked, ARR is installed but does nothing.

  ---
  5. App Pools

  ┌─────────────┬──────────────────┬───────────────┬──────────┐
  │  App Pool   │ .NET CLR Version │ Pipeline Mode │ Platform │
  ├─────────────┼──────────────────┼───────────────┼──────────┤
  │ SpinriseAPI │ No Managed Code  │ Integrated    │ 64-bit   │
  ├─────────────┼──────────────────┼───────────────┼──────────┤
  │ SpinriseWeb │ No Managed Code  │ Integrated    │ 64-bit   │
  └─────────────┴──────────────────┴───────────────┴──────────┘

  Check via PowerShell:
  Import-Module WebAdministration
  Get-WebConfiguration system.applicationHost/applicationPools/add |
    Where-Object { $_.name -match "Spinrise" } |
    Select-Object name, managedRuntimeVersion, processModel

  Identity: Check what account the app pool runs as — it must have:
  - Read access to the site root folder
  - Read/Write on ItemImagesPath folder

  ---
  6. Site Bindings

  Check:
  IIS Manager → Sites → SpinriseAPI  → Bindings → port 5001
                      → SpinriseWeb → Bindings → port 3000

  Also confirm Windows Firewall allows inbound on both ports:
  netsh advfirewall firewall show rule name=all | findstr "5001\|3000"

  If missing:
  netsh advfirewall firewall add rule name="Spinrise API 5001" dir=in action=allow protocol=TCP localport=5001
  netsh advfirewall firewall add rule name="Spinrise Web 3000" dir=in action=allow protocol=TCP localport=3000

  ---
  7. web.config on the Frontend Site

  The spinrise-web folder must have a web.config with both rules. If it's missing or empty, React Router page refreshes return 404 and API calls fail.

  Check it exists:
  <IIS-site-path>\spinrise-web\web.config

  Open it and confirm both rules are present:
  - API Proxy rule (match ^api/(.*))
  - SPA Fallback rule (match .* with IsFile/IsDirectory negation)

  ---
  8. Folder Permissions

  ┌───────────────────────┬─────────────────────────┬──────────────┐
  │        Folder         │        App Pool         │  Permission  │
  ├───────────────────────┼─────────────────────────┼──────────────┤
  │ <API site root>       │ IIS AppPool\SpinriseAPI │ Read         │
  ├───────────────────────┼─────────────────────────┼──────────────┤
  │ <Web site root>       │ IIS AppPool\SpinriseWeb │ Read         │
  ├───────────────────────┼─────────────────────────┼──────────────┤
  │ ItemImagesPath folder │ IIS AppPool\SpinriseAPI │ Read + Write │
  └───────────────────────┴─────────────────────────┴──────────────┘

  Check:
  icacls "E:\SpinriseV2\Server\Spinrise.API"
  icacls "C:\SpinriseData\ItemImages"

  ---
  Summary — Install Order (fresh server)

  1. IIS role (Server Manager)
  2. .NET 8 Hosting Bundle          → iisreset after install
  3. URL Rewrite 2.x                → iisreset after install
  4. ARR 3.x                        → iisreset after install
  5. Enable ARR proxy (IIS Manager → Server → ARR → Server Proxy Settings)
  6. Create App Pools (SpinriseAPI, SpinriseWeb)
  7. Create Sites with correct bindings
  8. Set folder permissions
  9. Proceed with DEPLOY_STEPS.txt

  ---
  The most common failure on a fresh IIS server is ARR not installed (or installed but proxy not enabled) — everything looks fine but all /api/* calls
  return 502.
