param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$entry = Join-Path $scriptDir "OpenCLI\dist\src\main.js"

& node $entry @Arguments
exit $LASTEXITCODE
