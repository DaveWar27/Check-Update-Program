param([string]$OutputPath)
$ErrorActionPreference = 'SilentlyContinue'
winget export -o "$OutputPath" --include-versions --accept-source-agreements
$code = $LASTEXITCODE
if ($code -ne 0) { exit $code }
Write-Host ('Lista applicazioni aggiornata in: ' + $OutputPath) -ForegroundColor Green
exit 0
