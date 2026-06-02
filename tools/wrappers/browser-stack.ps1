param(
  [string]$Command = 'doctor',

  [Parameter(ValueFromPipeline = $true)]
  [string]$InputObject,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ForwardArgs
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OpenCli = Join-Path $ScriptRoot 'opencli.ps1'
$Harness = Join-Path $ScriptRoot 'browser-harness.ps1'
$HarnessIsolated = Join-Path $ScriptRoot 'browser-harness-isolated.ps1'

function Invoke-HarnessReal {
  param([string[]]$ArgsForHarness)

  $HadCdpUrl = Test-Path Env:\BU_CDP_URL
  $OldCdpUrl = $env:BU_CDP_URL
  Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
  try {
    & $Harness @ArgsForHarness
    return $LASTEXITCODE
  } finally {
    if ($HadCdpUrl) {
      $env:BU_CDP_URL = $OldCdpUrl
    } else {
      Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
    }
  }
}

switch ($Command) {
  'doctor' {
    Write-Output '== OpenCLI Browser Bridge =='
    & $OpenCli doctor
    $OpenCliCode = $LASTEXITCODE

    Write-Output ''
    Write-Output '== Browser Harness on real Chrome =='
    $HadCdpUrl = Test-Path Env:\BU_CDP_URL
    $OldCdpUrl = $env:BU_CDP_URL
    Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
    try {
      @'
print(page_info())
'@ | & $Harness | Out-Null
      & $Harness --doctor
      $HarnessCode = $LASTEXITCODE
    } finally {
      if ($HadCdpUrl) {
        $env:BU_CDP_URL = $OldCdpUrl
      } else {
        Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
      }
    }

    if ($HarnessCode -ne 0) {
      Write-Output ''
      Write-Output 'Shared real-Chrome mode is not ready. Run: .\tool\browser-stack.ps1 setup-real'
    }

    if ($OpenCliCode -ne 0 -or $HarnessCode -ne 0) { exit 1 }
    exit 0
  }

  'setup-real' {
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

    Start-Process -FilePath $Chrome -ArgumentList 'chrome://inspect/#remote-debugging'
    Write-Output 'Opened chrome://inspect/#remote-debugging.'
    Write-Output 'In Chrome, enable "Allow remote debugging for this browser instance".'
    Write-Output 'If Chrome asks "Allow remote debugging?", click Allow.'
    Write-Output 'Then rerun: .\tool\browser-stack.ps1 doctor'
    exit 0
  }

  'switch-real' {
    Invoke-HarnessReal @('--reload') | Out-Null
    Write-Output 'Browser Harness daemon reset for real Chrome discovery.'
    exit 0
  }

  'switch-isolated' {
    & $HarnessIsolated --reload | Out-Null
    @'
print(page_info())
'@ | & $HarnessIsolated | Out-Null
    Write-Output 'Browser Harness daemon reset for isolated 9222 Chrome.'
    Write-Output 'Note: this isolated profile is a Browser Harness fallback, not the shared OpenCLI Browser Bridge profile.'
    exit 0
  }

  'opencli' {
    & $OpenCli @ForwardArgs
    exit $LASTEXITCODE
  }

  'harness-real' {
    $HadCdpUrl = Test-Path Env:\BU_CDP_URL
    $OldCdpUrl = $env:BU_CDP_URL
    Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
    try {
      $InputLines = if ($PSBoundParameters.ContainsKey('InputObject')) { @($InputObject) } else { @($input) }
      if ($InputLines.Count -gt 0) {
        ($InputLines -join [Environment]::NewLine) | & $Harness @ForwardArgs
      } else {
        & $Harness @ForwardArgs
      }
      exit $LASTEXITCODE
    } finally {
      if ($HadCdpUrl) {
        $env:BU_CDP_URL = $OldCdpUrl
      } else {
        Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
      }
    }
  }

  'harness-isolated' {
    $InputLines = if ($PSBoundParameters.ContainsKey('InputObject')) { @($InputObject) } else { @($input) }
    if ($InputLines.Count -gt 0) {
      ($InputLines -join [Environment]::NewLine) | & $HarnessIsolated @ForwardArgs
    } else {
      & $HarnessIsolated @ForwardArgs
    }
    exit $LASTEXITCODE
  }

  default {
    Write-Output 'Usage: .\tool\browser-stack.ps1 <command>'
    Write-Output ''
    Write-Output 'Commands:'
    Write-Output '  doctor            Check OpenCLI and Browser Harness shared real-Chrome readiness'
    Write-Output '  setup-real        Open Chrome remote-debugging settings for shared real-Chrome mode'
    Write-Output '  switch-real       Reset Browser Harness daemon for real Chrome discovery'
    Write-Output '  switch-isolated   Reset Browser Harness daemon for isolated 9222 fallback'
    Write-Output '  opencli ...       Pass through to OpenCLI'
    Write-Output '  harness-real ...  Pass through to Browser Harness with BU_CDP_URL cleared'
    Write-Output '  harness-isolated ... Pass through to Browser Harness with BU_CDP_URL=9222'
    exit 2
  }
}
