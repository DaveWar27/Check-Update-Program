$ErrorActionPreference = 'SilentlyContinue'

function Stop-ServiceForce {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }

    if ($svc.Status -eq 'Running' -or $svc.Status -eq 'StartPending') {
        Write-Host "Arresto servizio '$Name' in corso..." -ForegroundColor Gray
        # Avvia l'arresto senza bloccarsi (NoWait)
        Stop-Service -Name $Name -Force -NoWait -ErrorAction SilentlyContinue
    }

    # Aspetta massimo 5 secondi
    $timeout = 5
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $timeout) {
        $svc.Refresh()
        if ($svc.Status -eq 'Stopped') { return }
        Start-Sleep -Milliseconds 500
    }

    # Se dopo 5 secondi è ancora incastrato (es. in 'StopPending'), killa il PID!
    $svc.Refresh()
    if ($svc.Status -ne 'Stopped') {
        Write-Host "Il servizio '$Name' e bloccato. Chiusura forzata del processo..." -ForegroundColor Yellow
        $wmiSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
        if ($wmiSvc -and $wmiSvc.ProcessId -gt 0) {
            Stop-Process -Id $wmiSvc.ProcessId -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }
}

try {
    # Calcola spazio iniziale
    $tempSize = 0
    $tempFolders = @($env:TEMP, "$env:windir\Temp", "$env:LOCALAPPDATA\Temp")
    foreach ($f in $tempFolders) {
        if (Test-Path $f) {
            $items = Get-ChildItem -Path $f -Recurse -File -ErrorAction SilentlyContinue
            if ($items) {
                $tempSize += ($items | Measure-Object -Property Length -Sum).Sum
            }
        }
    }

    $sizeMB = [math]::Round($tempSize / 1MB, 2)
    Write-Host ("Spazio occupato da TEMP e Windows TEMP: " + $sizeMB + " MB") -ForegroundColor Green

    # Pulizia Windows Update e cache DNS
    Write-Host "Pulizia cache Windows Update e DNS..." -ForegroundColor Gray
    
    # Arresto sicuro (senza loop infinito)
    Stop-ServiceForce -Name "wuauserv"
    Stop-ServiceForce -Name "bits"
    Stop-ServiceForce -Name "cryptsvc"

    # Svuota cartelle Windows Update
    $sd = "$env:windir\SoftwareDistribution\Download"
    if (Test-Path $sd) {
        Remove-Item -Path "$sd\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Ripulisci DNS
    Clear-DnsClientCache -ErrorAction SilentlyContinue

    # Riavvio servizi essenziali
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    Start-Service -Name "bits" -ErrorAction SilentlyContinue
    Start-Service -Name "cryptsvc" -ErrorAction SilentlyContinue

    # Pulizia Temp
    foreach ($f in $tempFolders) {
        if (Test-Path $f) {
            Remove-Item -Path "$f\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Pulizia cache completata con successo." -ForegroundColor Green
    exit 0
} catch {
    Write-Host ("ERRORE PULIZIA: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}