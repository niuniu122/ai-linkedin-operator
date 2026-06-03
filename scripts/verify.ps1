$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Required = @(
  'skills\linkedin-post-video\SKILL.md',
  'skills\linkedin-post-text\SKILL.md',
  'skills\linkedin-comment\SKILL.md',
  'skills\linkedin-low-risk-connect\SKILL.md',
  'skills\linkedin-browser-stack\SKILL.md',
  'tools\wrappers\opencli.ps1',
  'tools\wrappers\browser-stack.ps1',
  'tools\wrappers\browser-harness.ps1',
  'tools\wrappers\browser-harness-isolated.ps1',
  'tools\wrappers\start-browser-harness-chrome.ps1',
  'tools\opencli-overrides\clis\linkedin\post-video.js',
  'tools\opencli-overrides\manifest\linkedin-post-video.json',
  'scripts\patch-opencli-manifest.mjs',
  'scripts\install.ps1'
)

foreach ($Rel in $Required) {
  $Path = Join-Path $Root $Rel
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required file: $Rel"
  }
}

Get-Content -Raw -LiteralPath (Join-Path $Root 'tools\opencli-overrides\manifest\linkedin-post-video.json') | ConvertFrom-Json | Out-Null
Write-Output 'Package verification passed.'
