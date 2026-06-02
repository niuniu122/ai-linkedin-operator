param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$entry = Join-Path $scriptDir "OpenCLI\dist\src\main.js"
$defaultProfile = "daily-login"
$stackStatePath = Join-Path $scriptDir "browser-stack-state.json"

function Save-BrowserStackTarget {
    param(
        [string] $Session,
        [string] $Url,
        [string] $Page
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return
    }

    $state = [ordered]@{
        source = "opencli"
        profile = $defaultProfile
        session = $Session
        url = $Url
        page = $Page
        updated_at = [DateTimeOffset]::UtcNow.ToString("o")
    }

    $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $stackStatePath -Encoding UTF8
}

function Try-Save-BrowserOpenTarget {
    param(
        [string[]] $ArgsForOpenCli,
        [object[]] $Output
    )

    if ($ArgsForOpenCli.Count -lt 4) {
        return
    }

    if ($ArgsForOpenCli[0] -ne "browser" -or $ArgsForOpenCli[2] -ne "open") {
        return
    }

    $session = $ArgsForOpenCli[1]
    $url = $null
    $page = $null
    $rawOutput = (($Output | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()

    if (-not [string]::IsNullOrWhiteSpace($rawOutput)) {
        try {
            $json = $rawOutput | ConvertFrom-Json -ErrorAction Stop
            $url = $json.url
            $page = $json.page
        } catch {
            $url = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = $ArgsForOpenCli[-1]
    }

    Save-BrowserStackTarget -Session $session -Url $url -Page $page
}

$oldProfileSet = Test-Path Env:\OPENCLI_PROFILE
$oldProfile = $env:OPENCLI_PROFILE
$env:OPENCLI_PROFILE = $defaultProfile

try {
    $shouldCaptureOutput = $Arguments.Count -ge 3 -and $Arguments[0] -eq "browser" -and $Arguments[2] -eq "open"

    if ($shouldCaptureOutput) {
        $output = & node $entry @Arguments
        $exitCode = $LASTEXITCODE

        if ($null -ne $output) {
            $output | Write-Output
        }

        if ($exitCode -eq 0) {
            Try-Save-BrowserOpenTarget -ArgsForOpenCli $Arguments -Output $output
        }
    } else {
        & node $entry @Arguments
        $exitCode = $LASTEXITCODE
    }
} finally {
    if ($oldProfileSet) {
        $env:OPENCLI_PROFILE = $oldProfile
    } else {
        Remove-Item Env:\OPENCLI_PROFILE -ErrorAction SilentlyContinue
    }
}

exit $exitCode
