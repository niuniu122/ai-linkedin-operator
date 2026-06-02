[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Position = 0)]
  [string]$Command = 'doctor',

  [Parameter(ValueFromPipeline = $true)]
  [string]$InputObject,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ForwardArgs
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OpenCli = Join-Path $ScriptRoot 'opencli.ps1'
$HarnessLogin = Join-Path $ScriptRoot 'browser-harness.ps1'
$HarnessIsolated = Join-Path $ScriptRoot 'browser-harness-isolated.ps1'
$HarnessExe = Join-Path $env:USERPROFILE '.local\bin\browser-harness.exe'
$OpenCliProfile = 'daily-login'
$script:OpenCliFixedExitCode = 0
if (-not (Test-Path -LiteralPath $HarnessExe)) {
  $HarnessExe = (Get-Command browser-harness.exe -ErrorAction Stop).Source
}

function Invoke-OpenCliFixed {
  param(
    [string[]]$ArgsForOpenCli
  )

  $OldProfileSet = Test-Path Env:\OPENCLI_PROFILE
  $OldProfile = $env:OPENCLI_PROFILE
  $env:OPENCLI_PROFILE = $OpenCliProfile
  try {
    & $OpenCli @ArgsForOpenCli
    $script:OpenCliFixedExitCode = $LASTEXITCODE
  } finally {
    if ($OldProfileSet) {
      $env:OPENCLI_PROFILE = $OldProfile
    } else {
      Remove-Item Env:\OPENCLI_PROFILE -ErrorAction SilentlyContinue
    }
  }
}

function Invoke-HarnessReal {
  param(
    [string[]]$ArgsForHarness,
    [string[]]$PipelineLines
  )

  $OldNameSet = Test-Path Env:\BU_NAME
  $OldName = $env:BU_NAME
  $OldCdpSet = Test-Path Env:\BU_CDP_URL
  $OldCdp = $env:BU_CDP_URL

  $env:BU_NAME = 'harness-real'
  $env:BU_CDP_URL = ''
  try {
    if ($PipelineLines.Count -gt 0) {
      ($PipelineLines -join [Environment]::NewLine) | & $HarnessExe @ArgsForHarness
    } else {
      & $HarnessExe @ArgsForHarness
    }
    return $LASTEXITCODE
  } finally {
    if ($OldNameSet) {
      $env:BU_NAME = $OldName
    } else {
      Remove-Item Env:\BU_NAME -ErrorAction SilentlyContinue
    }

    if ($OldCdpSet) {
      $env:BU_CDP_URL = $OldCdp
    } else {
      Remove-Item Env:\BU_CDP_URL -ErrorAction SilentlyContinue
    }
  }
}

switch ($Command) {
  'doctor' {
    Write-Output '== OpenCLI Browser Bridge =='
    Invoke-OpenCliFixed -ArgsForOpenCli @('doctor')
    $OpenCliCode = $script:OpenCliFixedExitCode

    Write-Output ''
    Write-Output '== Browser Harness daily-login Chrome =='
    @'
print(page_info())
'@ | & $HarnessLogin | Out-Null
    $HarnessProbeCode = $LASTEXITCODE
    & $HarnessLogin --doctor

    if ($OpenCliCode -ne 0 -or $HarnessProbeCode -ne 0) { exit 1 }
    exit 0
  }

  'verify-login' {
    $Marker = "https://example.com/?opencli_harness_login=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    Write-Output "Opening marker via OpenCLI daily-login profile: $Marker"
    Invoke-OpenCliFixed -ArgsForOpenCli @('browser', 'stack', 'open', $Marker)
    $OpenCliCode = $script:OpenCliFixedExitCode
    if ($OpenCliCode -ne 0) { exit $OpenCliCode }

    Start-Sleep -Seconds 1
    $Probe = @"
marker = '$Marker'
matches = [t for t in list_tabs(include_chrome=False) if t.get('url', '').startswith(marker)]
if not matches:
    raise RuntimeError('OpenCLI marker was not visible in Browser Harness daily-login tabs')
switch_tab(matches[0])
print(page_info())
"@
    $Probe | & $HarnessLogin
    $HarnessCode = $LASTEXITCODE
    if ($HarnessCode -ne 0) { exit $HarnessCode }

    Write-Output 'OK: OpenCLI daily-login profile and Browser Harness share the logged-in Chrome state'
    exit 0
  }

  'verify-fixed' {
    Write-Output 'verify-fixed is deprecated for default work; running verify-login instead.'
    & $MyInvocation.MyCommand.Path -Command verify-login
    exit $LASTEXITCODE
  }

  'doctor-real' {
    Write-Output '== Browser Harness on real Chrome =='
    $ProbeCode = Invoke-HarnessReal -ArgsForHarness @() -PipelineLines @('print(page_info())')
    $DoctorCode = Invoke-HarnessReal -ArgsForHarness @('--doctor') -PipelineLines @()
    if ($ProbeCode -ne 0 -or $DoctorCode -ne 0) { exit 1 }
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
    Write-Output 'Chrome may still ask "Allow remote debugging?" for real-Chrome mode.'
    Write-Output 'Use .\tool\browser-stack.ps1 harness-isolated for the fixed no-login fallback.'
    exit 0
  }

  'switch-real' {
    $Code = Invoke-HarnessReal -ArgsForHarness @('--reload') -PipelineLines @()
    if ($Code -ne 0) { exit $Code }
    Write-Output 'Browser Harness real-Chrome daemon reset. This mode may trigger Chrome Allow prompts.'
    exit 0
  }

  'switch-isolated' {
    & $HarnessIsolated --reload | Out-Null
    @'
print(page_info())
'@ | & $HarnessIsolated | Out-Null
    Write-Output 'Browser Harness isolated daemon reset.'
    exit 0
  }

  'switch-fixed' {
    & $HarnessIsolated --reload | Out-Null
    @'
print(page_info())
'@ | & $HarnessIsolated | Out-Null
    Write-Output 'Browser Harness isolated daemon reset.'
    exit 0
  }

  'opencli' {
    Invoke-OpenCliFixed -ArgsForOpenCli $ForwardArgs
    exit $script:OpenCliFixedExitCode
  }

  'harness-real' {
    $InputLines = if ($PSBoundParameters.ContainsKey('InputObject')) { @($InputObject) } else { @($input) }
    $Code = Invoke-HarnessReal -ArgsForHarness $ForwardArgs -PipelineLines $InputLines
    exit $Code
  }

  'harness-login' {
    $InputLines = if ($PSBoundParameters.ContainsKey('InputObject')) { @($InputObject) } else { @($input) }
    if ($InputLines.Count -gt 0) {
      ($InputLines -join [Environment]::NewLine) | & $HarnessLogin @ForwardArgs
    } else {
      & $HarnessLogin @ForwardArgs
    }
    exit $LASTEXITCODE
  }

  'sync-opencli-tab' {
    @'
print(page_info())
'@ | & $HarnessLogin
    exit $LASTEXITCODE
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

  'harness-fixed' {
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
    Write-Output '  doctor            Check OpenCLI daily-login and Browser Harness daily-login'
    Write-Output '  doctor-real       Check Browser Harness against daily Chrome; may prompt'
    Write-Output '  setup-real        Open Chrome remote-debugging settings for daily Chrome mode'
    Write-Output '  switch-real       Reset Browser Harness real-Chrome daemon; may prompt'
    Write-Output '  switch-isolated   Reset isolated Browser Harness daemon'
    Write-Output '  switch-fixed      Alias of switch-isolated'
    Write-Output '  verify-login      Verify OpenCLI and Browser Harness share daily logged-in state'
    Write-Output '  verify-fixed      Deprecated alias of verify-login'
    Write-Output '  opencli ...       Pass through to OpenCLI using profile daily-login'
    Write-Output '  harness-login ... Fallback Browser Harness on daily logged-in Chrome'
    Write-Output '  sync-opencli-tab  Switch Browser Harness to the last OpenCLI-opened tab'
    Write-Output '  harness-real ...  Raw Browser Harness on daily Chrome'
    Write-Output '  harness-isolated ... Explicit empty no-login Browser Harness'
    Write-Output '  harness-fixed ... Alias of harness-isolated'
    exit 2
  }
}
