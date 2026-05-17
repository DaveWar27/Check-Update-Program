param(
    [string]$SummaryPath,
    [string]$SkippedPath,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'SilentlyContinue'
$env:WINGET_DISABLE_PROGRESS_ANIMATION = '1'

$ignoredIds = @(
    'Microsoft.VisualStudio.Community',
    'Microsoft.VisualStudio.2022.Community',
    'Blitz.Blitz'
)

if ($SummaryPath) { Remove-Item $SummaryPath -Force -ErrorAction SilentlyContinue }
if ($SkippedPath) { Remove-Item $SkippedPath -Force -ErrorAction SilentlyContinue }

$upgradeOutput = winget upgrade --accept-source-agreements --disable-interactivity 2>$null | Out-String
$lines = $upgradeOutput -split "`r`n" | ForEach-Object { $_.Trim() }

$headerIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^Name\s+Id\s+Version\s+Available') {
        $headerIndex = $i
        break
    }
}

if ($headerIndex -eq -1) {
    Write-Host 'Formato output winget non riconosciuto.' -ForegroundColor Red
    exit 52
}

$headerLine = $lines[$headerIndex]
$idStart = $headerLine.IndexOf('Id')
$versionStart = $headerLine.IndexOf('Version', $idStart)
$availStart = $headerLine.IndexOf('Available', $versionStart)
$sourceStart = $headerLine.IndexOf('Source', $availStart)

$upgradeList = @()
for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('-')) { continue }
    if ($line.Length -lt $availStart) { continue }

    $name = $line.Substring(0, $idStart).Trim()
    $id = $line.Substring($idStart, $versionStart - $idStart).Trim()

    if ($id) {
        $upgradeList += [PSCustomObject]@{
            Name = $name
            Id   = $id
        }
    }
}

$totalPkgs = $upgradeList.Count
if ($totalPkgs -eq 0) {
    Write-Host 'Nessun aggiornamento WinGet trovato.' -ForegroundColor Green
    exit 0
}

Write-Host "Trovati $totalPkgs pacchetti da aggiornare." -ForegroundColor Cyan

$hadSkipped = $false
$hadFailed = $false

for ($index = 0; $index -lt $upgradeList.Count; $index++) {
    $pkg = $upgradeList[$index]
    $currentProgress = [math]::Round((($index + 1) / $totalPkgs) * 100, 0)

    Write-Progress -Activity "Aggiornamento WinGet" -Status "($($index + 1)/$totalPkgs) $($pkg.Name)" -PercentComplete $currentProgress

    if ($ignoredIds -contains $pkg.Id) {
        Write-Host ("Saltato: {0}" -f $pkg.Id) -ForegroundColor Yellow
        if ($SkippedPath) { Add-Content -Path $SkippedPath -Value ("IGNORED - {0} ({1})" -f $pkg.Name, $pkg.Id) }
        $hadSkipped = $true
        continue
    }

    Write-Host ("Inizio: {0}" -f $pkg.Id) -ForegroundColor Cyan
    $p = Start-Process -FilePath 'winget' -ArgumentList @(
        'upgrade', '--id', $pkg.Id,
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--silent',
        '--disable-interactivity'
    ) -PassThru -WindowStyle Hidden

    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        try { $p.Kill() } catch {}
        Write-Host ("Timeout: {0}" -f $pkg.Id) -ForegroundColor Yellow
        if ($SkippedPath) { Add-Content -Path $SkippedPath -Value ("TIMEOUT - {0} ({1})" -f $pkg.Name, $pkg.Id) }
        $hadSkipped = $true
        continue
    }

    if ($p.ExitCode -eq 0) {
        Write-Host ("OK: {0}" -f $pkg.Id) -ForegroundColor Green
        if ($SummaryPath) { Add-Content -Path $SummaryPath -Value ("OK - {0} ({1})" -f $pkg.Name, $pkg.Id) }
    }
    else {
        Write-Host ("Fallito: {0} (cod. {1})" -f $pkg.Id, $p.ExitCode) -ForegroundColor Yellow
        if ($SkippedPath) { Add-Content -Path $SkippedPath -Value ("FAILED({2}) - {0} ({1})" -f $pkg.Name, $pkg.Id, $p.ExitCode) }
        $hadFailed = $true
    }
}

Write-Progress -Activity "Aggiornamento WinGet" -Completed

if ($hadFailed) { exit 51 }
if ($hadSkipped) { exit 50 }
exit 0