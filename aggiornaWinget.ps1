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

$upgradeList = @()
$lines = winget upgrade --accept-source-agreements --disable-interactivity 2>$null
foreach ($line in $lines) {
    if ($line -match '^\s*$') { continue }
    if ($line -match '^-+$') { continue }
    if ($line -match '^Name\s+Id\s+') { continue }
    if ($line -match 'upgrades available') { continue }
    if ($line -match 'No installed package') { continue }
    if ($line -match '^(.+?)\s{2,}([^\s]+)\s{2,}([^\s]+)\s{2,}([^\s]+)\s*$') {
        $name = $matches[1].Trim()
        $id = $matches[2].Trim()
        if ($id) { $upgradeList += [pscustomobject]@{ Name = $name; Id = $id } }
    }
}

if (-not $upgradeList -or $upgradeList.Count -eq 0) {
    Write-Host 'Nessun aggiornamento WinGet trovato.' -ForegroundColor Green
    exit 0
}

$hadSkipped = $false
$hadFailed = $false

foreach ($pkg in $upgradeList) {
    if ($ignoredIds -contains $pkg.Id) {
        Write-Host (("Saltato da lista esclusioni: {0}" -f $pkg.Id)) -ForegroundColor Yellow
        if ($SkippedPath) { Add-Content -Path $SkippedPath -Value (("IGNORED - {0} ({1})" -f $pkg.Name, $pkg.Id)) }
        $hadSkipped = $true
        continue
    }

    Write-Host (("Aggiorno: {0} ({1})" -f $pkg.Name, $pkg.Id)) -ForegroundColor Cyan
    $p = Start-Process -FilePath 'winget' -ArgumentList @(
        'upgrade', '--id', $pkg.Id,
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--silent',
        '--disable-interactivity'
    ) -PassThru -WindowStyle Hidden

    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        try { $p.Kill() } catch {}
        Write-Host (("Saltato per timeout: {0}" -f $pkg.Id)) -ForegroundColor Yellow
        if ($SkippedPath) { Add-Content -Path $SkippedPath -Value (("TIMEOUT - {0} ({1})" -f $pkg.Name, $pkg.Id)) }
        $hadSkipped = $true
        continue
    }

    if ($p.ExitCode -eq 0) {
        Write-Host (("OK: {0}" -f $pkg.Id)) -ForegroundColor Green
        if ($SummaryPath) { Add-Content -Path $SummaryPath -Value (("OK - {0} ({1})" -f $pkg.Name, $pkg.Id)) }
    }
    else {
        Write-Host (("Fallito: {0} (codice {1})" -f $pkg.Id, $p.ExitCode)) -ForegroundColor Yellow
        if ($SkippedPath) { Add-Content -Path $SkippedPath -Value (("FAILED({2}) - {0} ({1})" -f $pkg.Name, $pkg.Id, $p.ExitCode)) }
        $hadFailed = $true
    }
}

if ($hadFailed) { exit 51 }
if ($hadSkipped) { exit 50 }
exit 0
