param(
    [string]$SummaryPath,
    [string]$SkippedPath,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'SilentlyContinue'

if ($SummaryPath) { Remove-Item $SummaryPath -Force -ErrorAction SilentlyContinue }
if ($SkippedPath) { Remove-Item $SkippedPath -Force -ErrorAction SilentlyContinue }

function Add-Summary {
    param([string]$Text)
    if ($SummaryPath) {
        Add-Content -Path $SummaryPath -Value $Text
    }
}

function Add-Skipped {
    param([string]$Text)
    if ($SkippedPath) {
        Add-Content -Path $SkippedPath -Value $Text
    }
}

function Get-WingetUpgradeIds {
    $lines = winget upgrade --accept-source-agreements 2>$null
    $start = $false
    $ids = @()

    foreach ($line in $lines) {
        if ($line -match '^-{3,}') {
            $start = $true
            continue
        }

        if (-not $start) { continue }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = ($line -replace '\s{2,}', '|').Split('|')
        if ($parts.Count -ge 2) {
            $id = $parts[1].Trim()
            if ($id -and $id -notmatch 'upgrades available') {
                $ids += $id
            }
        }
    }

    return $ids | Select-Object -Unique
}

function Wait-ProcessWithCountdown {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds,
        [string]$PackageId
    )

    $startTime = Get-Date

    while (-not $Process.HasExited) {
        $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
        $remaining = $TimeoutSeconds - $elapsed

        if ($remaining -le 0) {
            Write-Progress -Activity "Aggiornamento $PackageId" -Status "Timeout raggiunto" -PercentComplete 100 -SecondsRemaining 0 -Completed
            return $false
        }

        $percent = [math]::Floor(($elapsed / $TimeoutSeconds) * 100)
        if ($percent -gt 100) { $percent = 100 }

        Write-Progress `
            -Activity "Aggiornamento $PackageId" `
            -Status "Tempo rimanente: $remaining secondi" `
            -PercentComplete $percent `
            -SecondsRemaining $remaining

        Start-Sleep -Seconds 1
        $Process.Refresh()
    }

    Write-Progress -Activity "Aggiornamento $PackageId" -Completed
    return $true
}

$ok = 0
$skip = 0
$err = 0

$ids = Get-WingetUpgradeIds

if (-not $ids -or $ids.Count -eq 0) {
    Write-Host 'Nessun aggiornamento WinGet disponibile.' -ForegroundColor Green
    Add-Summary 'Nessun aggiornamento WinGet disponibile.'
    exit 0
}

foreach ($id in $ids) {
    Write-Host ("Aggiorno pacchetto: " + $id) -ForegroundColor Gray

    $argList = @(
        'upgrade'
        '--id', $id
        '--accept-package-agreements'
        '--accept-source-agreements'
        '--silent'
        '--disable-interactivity'
    )

    $proc = Start-Process -FilePath 'winget' -ArgumentList $argList -PassThru -WindowStyle Hidden
    $completed = Wait-ProcessWithCountdown -Process $proc -TimeoutSeconds $TimeoutSeconds -PackageId $id

    if (-not $completed -and -not $proc.HasExited) {
        Write-Host ("ATTENZIONE: timeout su " + $id + ", aggiornamento saltato.") -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Add-Summary ("[SKIP-TIMEOUT] " + $id)
        Add-Skipped ($id + " - timeout")
        $skip++
        continue
    }

    $exitCode = $proc.ExitCode

    if ($exitCode -eq 0) {
        Write-Host ("OK: " + $id + " aggiornato.") -ForegroundColor Green
        Add-Summary ("[OK] " + $id)
        $ok++
    }
    else {
        Write-Host ("ERRORE: " + $id + " non aggiornato. Codice " + $exitCode) -ForegroundColor Red
        Add-Summary ("[ERR] " + $id + " - codice " + $exitCode)
        $err++
    }
}

Write-Host ("Risultato WinGet -> OK: " + $ok + " | Saltati: " + $skip + " | Errori: " + $err) -ForegroundColor Cyan
Add-Summary ("Risultato WinGet -> OK: " + $ok + " | Saltati: " + $skip + " | Errori: " + $err)

if ($err -gt 0) {
    exit 51
}
elseif ($skip -gt 0) {
    exit 50
}
else {
    exit 0
}