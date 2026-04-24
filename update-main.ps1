param(
    [int]$DoCache = 1,
    [int]$DoSources = 1,
    [int]$DoWinget = 1,
    [int]$DoPnP = 0,
    [int]$DoDrivers = 0,
    [int]$DoTPM = 0,
    [int]$DoExport = 1
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WingetSummary = Join-Path $env:TEMP 'winget_summary.txt'
$WingetSkipped = Join-Path $env:TEMP 'winget_skipped.txt'
$AppExport = Join-Path $ScriptRoot 'lista-app-winget.json'
$LogDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'
$WingetTimeout = 180

$ctx = [ordered]@{
    Cache = if ($DoCache) { 'IN ATTESA' } else { 'DISATTIVATO' }
    Sorgenti = if ($DoSources) { 'IN ATTESA' } else { 'DISATTIVATO' }
    WinGet = if ($DoWinget) { 'IN ATTESA' } else { 'DISATTIVATO' }
    PnP = if ($DoPnP) { 'IN ATTESA' } else { 'DISATTIVATO' }
    Driver = if ($DoDrivers) { 'IN ATTESA' } else { 'DISATTIVATO' }
    TPM = if ($DoTPM) { 'IN ATTESA' } else { 'DISATTIVATO' }
    Export = if ($DoExport) { 'IN ATTESA' } else { 'DISATTIVATO' }
}
$globalRC = 0

function Invoke-StepScript {
    param(
        [string]$ScriptName,
        [hashtable]$Arguments = @{}
    )
    $path = Join-Path $ScriptRoot $ScriptName
    if (-not (Test-Path $path)) { throw ("File mancante: {0}" -f $ScriptName) }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path)
    foreach ($k in $Arguments.Keys) { $argList += @("-$k", [string]$Arguments[$k]) }
    Write-Host ("Eseguo: {0}" -f $ScriptName) -ForegroundColor DarkGray
    & powershell.exe @argList | Out-Host
    return [int]$LASTEXITCODE
}

function Set-StatusColor {
    param([string]$Label,[string]$Value)
    if ($Value -like 'OK*') { $c = 'Green' }
    elseif ($Value -like 'ATTENZIONE*') { $c = 'Yellow' }
    elseif ($Value -like 'ERRORE*') { $c = 'Red' }
    elseif ($Value -like 'DISATTIVATO*') { $c = 'DarkGray' }
    else { $c = 'Gray' }
    Write-Host ("{0}: {1}" -f $Label, $Value) -ForegroundColor $c
}

function Run-OptionalStep {
    param([string]$Name,[int]$Enabled,[scriptblock]$Action)
    if (-not $Enabled) { return }
    try { & $Action }
    catch {
        $ctx[$Name] = 'ERRORE BLOCCANTE'
        if ($globalRC -eq 0) { $script:globalRC = 1 }
        Write-Host ("ERRORE in {0}: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}

Remove-Item $WingetSummary -Force -ErrorAction SilentlyContinue
Remove-Item $WingetSkipped -Force -ErrorAction SilentlyContinue

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '       Update Manager Leggero' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Run-OptionalStep -Name 'Cache' -Enabled $DoCache -Action {
    Write-Host '[1] Pulizia cache...' -ForegroundColor Cyan
    $code = Invoke-StepScript -ScriptName 'puliziaCache.ps1'
    if ($code -eq 0) { $ctx.Cache = 'OK' } else { $ctx.Cache = "ERRORE - CODICE $code"; if ($globalRC -eq 0) { $script:globalRC = $code } }
}

Run-OptionalStep -Name 'Sorgenti' -Enabled $DoSources -Action {
    Write-Host ''
    Write-Host '[2] Aggiornamento sorgenti WinGet...' -ForegroundColor Cyan
    $code = Invoke-StepScript -ScriptName 'aggiornaSorgenti.ps1'
    if ($code -eq 0) { $ctx.Sorgenti = 'OK' } else { $ctx.Sorgenti = "ERRORE - CODICE $code"; if ($globalRC -eq 0) { $script:globalRC = $code } }
}

Run-OptionalStep -Name 'WinGet' -Enabled $DoWinget -Action {
    Write-Host ''
    Write-Host '[3] Aggiornamento pacchetti WinGet...' -ForegroundColor Cyan
    $code = Invoke-StepScript -ScriptName 'aggiornaWinget.ps1' -Arguments @{ SummaryPath = $WingetSummary; SkippedPath = $WingetSkipped; TimeoutSeconds = $WingetTimeout }
    if ($code -eq 0) { $ctx.WinGet = 'OK' }
    elseif ($code -eq 50) { $ctx.WinGet = 'ATTENZIONE - PACCHETTI SALTATI' }
    elseif ($code -eq 51) { $ctx.WinGet = 'ATTENZIONE - ALCUNI PACCHETTI FALLITI'; if ($globalRC -eq 0) { $script:globalRC = 51 } }
    else { $ctx.WinGet = "ERRORE - CODICE $code"; if ($globalRC -eq 0) { $script:globalRC = $code } }
}

Run-OptionalStep -Name 'PnP' -Enabled $DoPnP -Action {
    Write-Host ''
    Write-Host '[4] Scansione hardware PnP...' -ForegroundColor Cyan
    $code = Invoke-StepScript -ScriptName 'scansionePnP.ps1'
    if ($code -eq 0) { $ctx.PnP = 'OK' } else { $ctx.PnP = "ERRORE - CODICE $code"; if ($globalRC -eq 0) { $script:globalRC = $code } }
}

Run-OptionalStep -Name 'Driver' -Enabled $DoDrivers -Action {
    Write-Host ''
    Write-Host '[5] Controllo driver...' -ForegroundColor Cyan
    $code = Invoke-StepScript -ScriptName 'controlloDriver.ps1'
    if ($code -eq 0) { $ctx.Driver = 'OK' } else { $ctx.Driver = "ATTENZIONE - CODICE $code"; if ($globalRC -eq 0) { $script:globalRC = $code } }
}

Run-OptionalStep -Name 'TPM' -Enabled $DoTPM -Action {
    Write-Host ''
    Write-Host '[6] Controllo TPM / Secure Boot / UEFI...' -ForegroundColor Magenta
    $code = Invoke-StepScript -ScriptName 'controlloTPM.ps1'
    if ($code -eq 0) { $ctx.TPM = 'OK' } else { $ctx.TPM = 'ATTENZIONE - REQUISITI NON VALIDI'; if ($globalRC -eq 0) { $script:globalRC = $code } }
}

Run-OptionalStep -Name 'Export' -Enabled $DoExport -Action {
    Write-Host ''
    Write-Host '[7] Export lista applicazioni WinGet...' -ForegroundColor Cyan
    $code = Invoke-StepScript -ScriptName 'exportWinget.ps1' -Arguments @{ OutputPath = $AppExport }
    if ($code -eq 0) { $ctx.Export = 'OK' } else { $ctx.Export = 'ATTENZIONE - EXPORT NON RIUSCITO' }
}

Write-Host ''
Write-Host 'Pulizia log WinGet...' -ForegroundColor Gray
if (Test-Path $LogDir) {
    Get-ChildItem -Path $LogDir -Filter '*.log' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '============== RIASSUNTO FINALE ==============' -ForegroundColor Cyan
Set-StatusColor 'Pulizia cache' $ctx.Cache
Set-StatusColor 'Sorgenti WinGet' $ctx.Sorgenti
Set-StatusColor 'Pacchetti WinGet' $ctx.WinGet
Set-StatusColor 'PnP / hardware' $ctx.PnP
Set-StatusColor 'Driver' $ctx.Driver
Set-StatusColor 'TPM / Secure Boot / UEFI' $ctx.TPM
Set-StatusColor 'Export lista app' $ctx.Export

if (Test-Path $WingetSummary) {
    Write-Host ''
    Write-Host 'Dettaglio aggiornamenti WinGet:' -ForegroundColor Cyan
    Get-Content $WingetSummary
}
if (Test-Path $WingetSkipped) {
    Write-Host ''
    Write-Host 'Pacchetti non completati:' -ForegroundColor Yellow
    Get-Content $WingetSkipped
}
Write-Host ''
if ($globalRC -ne 0) { Write-Host ("Esito complessivo: COMPLETATO CON AVVISI/ERRORI (codice {0})" -f $globalRC) -ForegroundColor Yellow }
else { Write-Host 'Esito complessivo: COMPLETATO CON SUCCESSO' -ForegroundColor Green }
exit $globalRC
