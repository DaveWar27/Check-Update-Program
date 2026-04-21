$ErrorActionPreference = 'SilentlyContinue'

function Get-FolderFilesSizeBytes {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    $files = Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue
    if (-not $files) {
        return 0
    }

    $sum = ($files | Measure-Object Length -Sum).Sum
    if (-not $sum) { return 0 }
    return [int64]$sum
}

function Remove-FolderContentSafe {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Get-ChildItem -LiteralPath $Path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Format-MB {
    param([double]$Value)
    return [math]::Round($Value, 2).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
}

try {
    $tempBytes = 0
    $wuBytes = 0

    $tempPaths = @(
        $env:TEMP,
        'C:\Windows\Temp'
    )

    foreach ($p in $tempPaths) {
        $tempBytes += Get-FolderFilesSizeBytes -Path $p
    }

    foreach ($p in $tempPaths) {
        Remove-FolderContentSafe -Path $p
    }

    Write-Host ("Spazio liberato da TEMP e Windows TEMP: " + (Format-MB ($tempBytes / 1MB)) + " MB") -ForegroundColor Green

    $wuPath = 'C:\Windows\SoftwareDistribution\Download'
    $wuBytes = Get-FolderFilesSizeBytes -Path $wuPath

    Write-Host 'Pulizia cache Windows Update...' -ForegroundColor Gray
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name bits -Force -ErrorAction SilentlyContinue

    Remove-FolderContentSafe -Path $wuPath

    Start-Service -Name bits -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue

    Write-Host ("Spazio liberato da cache Windows Update: " + (Format-MB ($wuBytes / 1MB)) + " MB") -ForegroundColor Green

    $totalBytes = $tempBytes + $wuBytes
    Write-Host ("Totale spazio liberato dalla pulizia: " + (Format-MB ($totalBytes / 1MB)) + " MB") -ForegroundColor Magenta

    exit 0
}
catch {
    Write-Host 'ERRORE PULIZIA: pulizia temporanei/cache non riuscita.' -ForegroundColor Red
    exit 30
}