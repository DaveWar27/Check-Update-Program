$ErrorActionPreference = 'SilentlyContinue'
$env:WINGET_DISABLE_PROGRESS_ANIMATION = '1'
winget source update --disable-interactivity
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host 'Errore durante l''aggiornamento delle sorgenti.' -ForegroundColor Red
    exit $code
}
Write-Host 'Sorgenti aggiornate correttamente.' -ForegroundColor Green
exit 0
