$ErrorActionPreference = 'SilentlyContinue'

$targets = @(
    @{ Host = 'internetbeacon.msedge.net'; Port = 443 },
    @{ Host = 'github.com'; Port = 443 }
)

$failed = @()

foreach ($t in $targets) {
    try {
        $ok = Test-NetConnection -ComputerName $t.Host -Port $t.Port -InformationLevel Quiet
        if ($ok) {
            Write-Host ("OK: " + $t.Host + ":" + $t.Port) -ForegroundColor Green
        }
        else {
            Write-Host ("ERRORE SERVER: " + $t.Host + ":" + $t.Port) -ForegroundColor Red
            $failed += ($t.Host + ":" + $t.Port)
        }
    }
    catch {
        Write-Host ("ERRORE SERVER: " + $t.Host + ":" + $t.Port) -ForegroundColor Red
        $failed += ($t.Host + ":" + $t.Port)
    }
}

if ($failed.Count -gt 0) {
    Write-Host "ERRORE INTERNET: uno o piu server richiesti non sono raggiungibili." -ForegroundColor Red
    exit 10
}

Write-Host "Controllo server completato con successo." -ForegroundColor Green
exit 0