param(
  [string]$InstallRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CodexSkillsPath = (Join-Path $env:USERPROFILE '.codex\skills')
)

$ErrorActionPreference = 'Stop'

$ToolDir = Join-Path $InstallRoot 'tool'
$OpenCliDir = Join-Path $ToolDir 'OpenCLI'
$BrowserHarnessDir = Join-Path $ToolDir 'browser-harness'

New-Item -ItemType Directory -Force -Path $ToolDir, $CodexSkillsPath | Out-Null

Copy-Item -Recurse -Force -LiteralPath (Join-Path $InstallRoot 'skills\linkedin-post-video') -Destination $CodexSkillsPath
Copy-Item -Recurse -Force -LiteralPath (Join-Path $InstallRoot 'skills\linkedin-post-text') -Destination $CodexSkillsPath
Copy-Item -Recurse -Force -LiteralPath (Join-Path $InstallRoot 'skills\linkedin-comment') -Destination $CodexSkillsPath

if (-not (Test-Path -LiteralPath $OpenCliDir)) {
  git clone https://github.com/jackwener/OpenCLI.git $OpenCliDir
}

if (-not (Test-Path -LiteralPath $BrowserHarnessDir)) {
  git clone https://github.com/browser-use/browser-harness.git $BrowserHarnessDir
}

Copy-Item -Force -Path (Join-Path $InstallRoot 'tools\wrappers\*.ps1') -Destination $ToolDir
Copy-Item -Force -LiteralPath (Join-Path $InstallRoot 'tools\opencli-overrides\clis\linkedin\post-video.js') -Destination (Join-Path $OpenCliDir 'clis\linkedin\post-video.js')

node (Join-Path $InstallRoot 'scripts\patch-opencli-manifest.mjs') $OpenCliDir

Push-Location $OpenCliDir
try {
  npm install
  npm run build
} finally {
  Pop-Location
}

if (Get-Command pipx -ErrorAction SilentlyContinue) {
  pipx install --force $BrowserHarnessDir
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
  python -m pip install -e $BrowserHarnessDir
}

Write-Output 'Installed LinkedIn operator skills and local tool workflow.'
Write-Output "Tools: $ToolDir"
Write-Output "Skills: $CodexSkillsPath"
Write-Output 'Next: run .\tool\browser-stack.ps1 doctor'
