$ErrorActionPreference = 'Stop'
try {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host 'PSWindowsUpdate non trovato, installazione in corso...' -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
        Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module PSWindowsUpdate -Force -AcceptLicense -ErrorAction Stop | Out-Null
    }
    Import-Module PSWindowsUpdate -Force
    $u = Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -IgnoreReboot -ErrorAction Stop
    if ($u) {
        Write-Host 'Driver disponibili trovati.' -ForegroundColor Yellow
        $u | Select-Object -ExpandProperty Title
    }
    else {
        Write-Host 'Nessun aggiornamento driver trovato.' -ForegroundColor Green
    }
    exit 0
}
catch {
    Write-Host ('ERRORE DRIVER: ' + $_.Exception.Message) -ForegroundColor Red
    exit 41
}
