$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$StartChrome = Join-Path $ScriptRoot 'start-browser-harness-chrome.ps1'

& $StartChrome | Out-Null
$env:BU_CDP_URL = 'http://127.0.0.1:9222'

$ForwardArgs = $args
$InputLines = @($input)

if ($InputLines.Count -gt 0) {
  ($InputLines -join [Environment]::NewLine) | & browser-harness @ForwardArgs
} else {
  & browser-harness @ForwardArgs
}

exit $LASTEXITCODE
