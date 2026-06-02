$ErrorActionPreference = 'Stop'

$ForwardArgs = $args
$InputLines = @($input)

if ($InputLines.Count -gt 0) {
  ($InputLines -join [Environment]::NewLine) | & browser-harness @ForwardArgs
} else {
  & browser-harness @ForwardArgs
}

exit $LASTEXITCODE
