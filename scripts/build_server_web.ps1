<#
.SYNOPSIS
  Builds the self-hosted ("server") web version of Keyla: the landing page at
  the root of a folder, with the Flutter web app underneath it at /app/.

.DESCRIPTION
  Produces build/server_web/ and a Keyla_upload.zip you can extract onto a
  plain static/PHP host. This is the same layout the GitHub Pages workflow
  deploys, just with a base href pointing at your own host instead of
  /KeyLa/app/.

.PARAMETER BasePath
  URL path the site will be served from, with leading and trailing slashes.
  e.g. '/ARIF(KyLa)/' -> https://your-host.com/ARIF(KyLa)/

.PARAMETER ServerBaseUrl
  Base URL of the ARIF(KyLa) PHP endpoints, compiled into the app via
  --dart-define. Must be reachable from the browser and CORS-permitted.

.EXAMPLE
  ./scripts/build_server_web.ps1 -BasePath '/ARIF(KyLa)/' -ServerBaseUrl 'https://ruetandroiddevelopers.com/ARIF(KyLa)/server'
#>
param(
  [string]$BasePath = '/ARIF(KyLa)/',
  [string]$ServerBaseUrl = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$app = Join-Path $repo 'keyla_v1'
$out = Join-Path $repo 'build\server_web'

if (-not $BasePath.StartsWith('/') -or -not $BasePath.EndsWith('/')) {
  throw "BasePath must start and end with '/': got '$BasePath'"
}

Write-Host "==> Fetching sodium.js for web (required, else the app hangs at splash)"
Push-Location $app
try {
  dart run sodium_libs:update_web
  if ($LASTEXITCODE -ne 0) { throw "sodium_libs:update_web failed" }

  $buildArgs = @('build', 'web', '--release', '--base-href', "$BasePath`app/")
  if ($ServerBaseUrl) { $buildArgs += @('--dart-define', "SERVER_BASE_URL=$ServerBaseUrl") }

  Write-Host "==> flutter $($buildArgs -join ' ')"
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) { throw "flutter build web failed" }
} finally {
  Pop-Location
}

Write-Host "==> Assembling $out"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force -Path (Join-Path $out 'app') | Out-Null
Copy-Item -Recurse -Force (Join-Path $repo 'landing\*') $out
Copy-Item -Recurse -Force (Join-Path $app 'build\web\*') (Join-Path $out 'app')

$zip = Join-Path $repo 'Keyla_upload.zip'
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
Write-Host "==> Done."
Write-Host "    Site : $out"
Write-Host "    Zip  : $zip   (extract into the folder served at $BasePath)"
