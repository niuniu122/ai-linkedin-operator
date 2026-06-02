$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$HarnessExe = Join-Path $env:USERPROFILE '.local\bin\browser-harness.exe'
$StackStatePath = Join-Path $ScriptRoot 'browser-stack-state.json'
if (-not (Test-Path -LiteralPath $HarnessExe)) {
  $HarnessExe = (Get-Command browser-harness.exe -ErrorAction Stop).Source
}

$ForwardArgs = $args
$InputLines = @($input)
$AutoSync = $env:BROWSER_STACK_SKIP_SYNC -ne '1' -and $env:BROWSER_STACK_AUTO_SYNC -ne '0'

if ($ForwardArgs -contains '--no-sync') {
  $AutoSync = $false
  $ForwardArgs = @($ForwardArgs | Where-Object { $_ -ne '--no-sync' })
}

if ($ForwardArgs -contains '--doctor' -or $ForwardArgs -contains '--reload') {
  $AutoSync = $false
}

$OldNameSet = Test-Path Env:\BU_NAME
$OldName = $env:BU_NAME
$OldCdpSet = Test-Path Env:\BU_CDP_URL
$OldCdp = $env:BU_CDP_URL

function Restore-HarnessEnv {
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

function Get-AutoSyncPrelude {
  if (-not $AutoSync -or -not (Test-Path -LiteralPath $StackStatePath)) {
    return $null
  }

  try {
    $State = Get-Content -Raw -LiteralPath $StackStatePath | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return $null
  }

  if (-not $State.url) {
    return $null
  }

  $TargetJson = $State.url | ConvertTo-Json -Compress

  return @"
try:
    from urllib.parse import urldefrag
    __browser_stack_target = $TargetJson
    __browser_stack_target_clean = urldefrag(__browser_stack_target)[0].rstrip("/")
    __browser_stack_tabs = list_tabs(include_chrome=False)
    __browser_stack_matches = [
        t for t in __browser_stack_tabs
        if t.get("url", "").startswith(__browser_stack_target)
    ]
    if not __browser_stack_matches and __browser_stack_target_clean:
        __browser_stack_matches = [
            t for t in __browser_stack_tabs
            if urldefrag(t.get("url", ""))[0].rstrip("/").startswith(__browser_stack_target_clean)
        ]
    if __browser_stack_matches:
        switch_tab(__browser_stack_matches[0])
except Exception:
    pass
"@
}

$env:BU_NAME = 'harness-real'
$env:BU_CDP_URL = ''

try {
  $PipelineLines = @()
  $Prelude = Get-AutoSyncPrelude
  if ($Prelude) {
    $PipelineLines += $Prelude
  }
  $PipelineLines += $InputLines

  if ($InputLines.Count -gt 0) {
    ($PipelineLines -join [Environment]::NewLine) | & $HarnessExe @ForwardArgs
  } else {
    & $HarnessExe @ForwardArgs
  }
  $ExitCode = $LASTEXITCODE
} finally {
  Restore-HarnessEnv
}

exit $ExitCode
