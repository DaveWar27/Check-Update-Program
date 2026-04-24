$ErrorActionPreference = 'SilentlyContinue'
Write-Host 'Pulizia file temporanei utente...' -ForegroundColor Gray
Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'Pulizia file temporanei di Windows...' -ForegroundColor Gray
Get-ChildItem -Path "$env:WINDIR\Temp" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'Pulizia cache Windows Update...' -ForegroundColor Gray
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service bits -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:WINDIR\SoftwareDistribution\Download" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Start-Service bits -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue
Write-Host 'Pulizia cache completata.' -ForegroundColor Green
exit 0
