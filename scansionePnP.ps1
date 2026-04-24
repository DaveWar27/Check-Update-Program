pnputil /scan-devices
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host 'ERRORE PNP: scansione hardware non riuscita.' -ForegroundColor Red
    exit $code
}
Write-Host 'Scansione hardware completata.' -ForegroundColor Green
exit 0
