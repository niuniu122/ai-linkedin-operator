param(
  [int]$Port = 9222
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Profile = Join-Path $ScriptRoot 'browser-harness-profile'
$OpenCliExtension = Join-Path $ScriptRoot 'OpenCLI\extension'
$CdpUrl = "http://127.0.0.1:$Port"

try {
  $response = Invoke-WebRequest -UseBasicParsing "$CdpUrl/json/version" -TimeoutSec 1
  if ($response.StatusCode -eq 200) {
    Write-Output "Browser Harness Chrome is already listening at $CdpUrl"
    exit 0
  }
} catch {
}

$Chrome = $null
$RunningChrome = Get-Process chrome -ErrorAction SilentlyContinue | Select-Object -First 1
if ($RunningChrome -and $RunningChrome.Path) {
  $Chrome = $RunningChrome.Path
}

if (-not $Chrome) {
  $Candidates = @(
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
  )
  $Chrome = $Candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $Chrome) {
  throw 'Chrome executable not found.'
}

New-Item -ItemType Directory -Force -Path $Profile | Out-Null
$ProfileArg = $Profile
try {
  $FileSystem = New-Object -ComObject Scripting.FileSystemObject
  $ProfileArg = $FileSystem.GetFolder($Profile).ShortPath
} catch {
}

$Arguments = @(
  "--remote-debugging-port=$Port",
  "--user-data-dir=`"$ProfileArg`"",
  '--no-first-run'
)

if (Test-Path -LiteralPath (Join-Path $OpenCliExtension 'manifest.json')) {
  $ExtensionArg = $OpenCliExtension
  try {
    $FileSystem = New-Object -ComObject Scripting.FileSystemObject
    $ExtensionArg = $FileSystem.GetFolder($OpenCliExtension).ShortPath
  } catch {
  }
  $Arguments += "--disable-extensions-except=`"$ExtensionArg`""
  $Arguments += "--load-extension=`"$ExtensionArg`""
}

$Arguments += 'about:blank'
$ArgumentLine = $Arguments -join ' '
Start-Process -FilePath $Chrome -ArgumentList $ArgumentLine
Write-Output "Started Browser Harness Chrome at $CdpUrl"
