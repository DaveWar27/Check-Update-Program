@echo off
setlocal EnableExtensions
title Aggiornamento automatico con WinGet
color 07
cls

cd /d "%~dp0"

set "LOGDIR=%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
set "RC=0"
set "TPMPS1=%~dp0controlloTMP.ps1"
set "NETPS1=%~dp0controlloRete.ps1"
set "CLEANPS1=%~dp0puliziaCache.ps1"
set "APP_EXPORT=%~dp0lista-app-winget.json"
set "MINFREEGB=5"
set "UPDATERC=0"
set "STOREUPDATERC=0"
set "DRIVERRC=0"
set "PNPRC=0"
set "HASMSSTORE=NO"

set "ST_NET=NON ESEGUITO"
set "ST_DISK=NON ESEGUITO"
set "ST_CLEAN=NON ESEGUITO"
set "ST_SOURCE=NON ESEGUITO"
set "ST_WINGET=NON ESEGUITO"
set "ST_STORE=NON ESEGUITO"
set "ST_PNP=NON ESEGUITO"
set "ST_DRIVER=NON ESEGUITO"
set "ST_TPM=NON ESEGUITO"

powershell -NoProfile -Command "Write-Host '========================================' -ForegroundColor Cyan; Write-Host '    Aggiornamento automatico con WinGet' -ForegroundColor Cyan; Write-Host '========================================' -ForegroundColor Cyan"
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    powershell -NoProfile -Command "Write-Host 'Richiesta privilegi di amministratore...' -ForegroundColor Yellow"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%TPMPS1%" (
    powershell -NoProfile -Command "Write-Host 'ERRORE: file controlloTMP.ps1 non trovato.' -ForegroundColor Red"
    set "ST_TPM=ERRORE - FILE MANCANTE"
    set "RC=2"
    goto END
)

if not exist "%NETPS1%" (
    powershell -NoProfile -Command "Write-Host 'ERRORE: file controlloRete.ps1 non trovato.' -ForegroundColor Red"
    set "ST_NET=ERRORE - FILE MANCANTE"
    set "RC=3"
    goto END
)

if not exist "%CLEANPS1%" (
    powershell -NoProfile -Command "Write-Host 'ERRORE: file puliziaCache.ps1 non trovato.' -ForegroundColor Red"
    set "ST_CLEAN=ERRORE - FILE MANCANTE"
    set "RC=4"
    goto END
)

powershell -NoProfile -Command "Write-Host '[1/9] Controllo connessione a server specifici...' -ForegroundColor Cyan"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%NETPS1%"
if not "%errorlevel%"=="0" (
    set "ST_NET=ERRORE"
    set "RC=%errorlevel%"
    goto END
) else (
    set "ST_NET=OK"
)

echo.
powershell -NoProfile -Command "Write-Host '[2/9] Controllo spazio libero su disco C:...' -ForegroundColor Cyan"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$min = %MINFREEGB%; ^
try { ^
    $d = New-Object System.IO.DriveInfo('C'); ^
    if (-not $d.IsReady) { Write-Host 'ERRORE DISCO: unita C: non pronta.' -ForegroundColor Red; exit 21 } ^
    $free = [math]::Floor($d.AvailableFreeSpace / 1GB); ^
    Write-Host ('Spazio libero su C:: ' + $free + ' GB') -ForegroundColor Gray; ^
    if ($free -lt $min) { ^
        Write-Host 'ERRORE DISCO: spazio libero insufficiente su C:.' -ForegroundColor Red; ^
        Write-Host ('Spazio disponibile: ' + $free + ' GB') -ForegroundColor Yellow; ^
        Write-Host ('Spazio minimo richiesto: ' + $min + ' GB') -ForegroundColor Yellow; ^
        exit 12 ^
    } else { ^
        Write-Host 'Spazio disco OK.' -ForegroundColor Green; ^
        exit 0 ^
    } ^
} catch { ^
    Write-Host 'ERRORE DISCO: impossibile leggere lo spazio libero su C:.' -ForegroundColor Red; ^
    exit 22 ^
}"
if not "%errorlevel%"=="0" (
    set "ST_DISK=ERRORE"
    set "RC=%errorlevel%"
    goto END
) else (
    set "ST_DISK=OK"
)

echo.
powershell -NoProfile -Command "Write-Host '[3/9] Pulizia temporanei e cache...' -ForegroundColor Cyan"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CLEANPS1%"
if not "%errorlevel%"=="0" (
    set "ST_CLEAN=ERRORE"
    set "RC=%errorlevel%"
    goto END
) else (
    set "ST_CLEAN=OK"
)

echo.
powershell -NoProfile -Command "Write-Host '[4/9] Aggiornamento sorgenti...' -ForegroundColor Cyan"
winget source update
if not "%errorlevel%"=="0" (
    set "RC=%errorlevel%"
    set "ST_SOURCE=ERRORE"
    powershell -NoProfile -Command "Write-Host 'Errore durante l''aggiornamento delle sorgenti.' -ForegroundColor Red"
    winget error %RC%
    goto END
) else (
    set "ST_SOURCE=OK"
    powershell -NoProfile -Command "Write-Host 'Sorgenti aggiornate correttamente.' -ForegroundColor Green"
)

echo.
powershell -NoProfile -Command "Write-Host '[5/9] Aggiornamento pacchetti WinGet classici...' -ForegroundColor Cyan"
winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent --disable-interactivity --verbose-logs
set "UPDATERC=%errorlevel%"
if not "%UPDATERC%"=="0" (
    powershell -NoProfile -Command "Write-Host 'ERRORE DOWNLOAD/UPDATE: primo tentativo fallito.' -ForegroundColor Red"
    winget error %UPDATERC%
    powershell -NoProfile -Command "Write-Host 'Riprovo una sola volta...' -ForegroundColor Yellow"
    winget source update
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent --disable-interactivity --verbose-logs
    set "UPDATERC=%errorlevel%"
    if not "%UPDATERC%"=="0" (
        set "ST_WINGET=ERRORE"
        powershell -NoProfile -Command "Write-Host 'ERRORE DOWNLOAD/UPDATE: anche il secondo tentativo e fallito.' -ForegroundColor Red"
        winget error %UPDATERC%
        set "RC=%UPDATERC%"
    ) else (
        set "ST_WINGET=OK DOPO RITENTATIVO"
        powershell -NoProfile -Command "Write-Host 'Recupero riuscito al secondo tentativo.' -ForegroundColor Green"
    )
) else (
    set "ST_WINGET=OK"
    powershell -NoProfile -Command "Write-Host 'Aggiornamento pacchetti WinGet completato.' -ForegroundColor Green"
)

echo.
powershell -NoProfile -Command "Write-Host '[6/9] Aggiornamento app Microsoft Store...' -ForegroundColor Cyan"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = winget source list; if ($s -match 'msstore') { [Console]::WriteLine('YES') } else { [Console]::WriteLine('NO') }"`) do set "HASMSSTORE=%%A"

if /I "%HASMSSTORE%"=="YES" (
    winget upgrade --all -s msstore --include-unknown --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
    set "STOREUPDATERC=%errorlevel%"
    if not "%STOREUPDATERC%"=="0" (
        set "ST_STORE=ERRORE"
        powershell -NoProfile -Command "Write-Host 'ERRORE STORE: aggiornamento app Microsoft fallito.' -ForegroundColor Red"
        winget error %STOREUPDATERC%
        if "%RC%"=="0" set "RC=%STOREUPDATERC%"
    ) else (
        set "ST_STORE=OK"
        powershell -NoProfile -Command "Write-Host 'Aggiornamento app Microsoft Store completato.' -ForegroundColor Green"
    )
) else (
    set "ST_STORE=ATTENZIONE - SORGENTE ASSENTE"
    powershell -NoProfile -Command "Write-Host 'AVVISO STORE: sorgente msstore non trovata.' -ForegroundColor Yellow"
)

echo.
powershell -NoProfile -Command "Write-Host '[7/9] Scansione hardware con PnPUtil...' -ForegroundColor Cyan"
pnputil /scan-devices
set "PNPRC=%errorlevel%"
if not "%PNPRC%"=="0" (
    set "ST_PNP=ERRORE"
    powershell -NoProfile -Command "Write-Host 'ERRORE PNP: scansione hardware non riuscita.' -ForegroundColor Red"
    if "%RC%"=="0" set "RC=%PNPRC%"
) else (
    set "ST_PNP=OK"
    powershell -NoProfile -Command "Write-Host 'Scansione hardware completata.' -ForegroundColor Green"
)

echo.
powershell -NoProfile -Command "Write-Host '[8/9] Controllo aggiornamenti driver...' -ForegroundColor Cyan"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { if (Get-Module -ListAvailable -Name PSWindowsUpdate) { Import-Module PSWindowsUpdate -Force; $u = Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -IgnoreReboot; if ($u) { Write-Host 'Driver disponibili trovati tramite Windows Update.' -ForegroundColor Yellow; Install-WindowsUpdate -MicrosoftUpdate -Category Drivers -AcceptAll -IgnoreReboot -Confirm:$false | Out-Null; exit 0 } else { Write-Host 'Nessun aggiornamento driver trovato.' -ForegroundColor Green; exit 0 } } else { Write-Host 'AVVISO DRIVER: modulo PSWindowsUpdate non presente.' -ForegroundColor Yellow; exit 40 } } catch { Write-Host 'ERRORE DRIVER: controllo driver non riuscito.' -ForegroundColor Red; exit 41 }"
set "DRIVERRC=%errorlevel%"

if "%DRIVERRC%"=="40" (
    set "ST_DRIVER=ATTENZIONE - MODULO ASSENTE"
    powershell -NoProfile -Command "Write-Host 'Controllo driver saltato: modulo PSWindowsUpdate assente.' -ForegroundColor Yellow"
) else if "%DRIVERRC%"=="41" (
    set "ST_DRIVER=ERRORE"
    if "%RC%"=="0" set "RC=41"
) else (
    set "ST_DRIVER=OK"
    powershell -NoProfile -Command "Write-Host 'Controllo driver completato.' -ForegroundColor Green"
)

echo.
powershell -NoProfile -Command "Write-Host '[9/9] Aggiornamento lista applicazioni Winget...' -ForegroundColor Cyan"
winget export -o "%APP_EXPORT%" --include-versions --accept-source-agreements
if not "%errorlevel%"=="0" (
    powershell -NoProfile -Command "Write-Host 'Avviso: impossibile aggiornare la lista applicazioni Winget.' -ForegroundColor Yellow"
) else (
    powershell -NoProfile -Command "Write-Host 'Lista applicazioni aggiornata in: %APP_EXPORT%' -ForegroundColor Green"
)

echo.
powershell -NoProfile -Command "Write-Host '[TPM] Controllo e riparazione TPM...' -ForegroundColor Magenta"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TPMPS1%"
if not "%errorlevel%"=="0" (
    set "ST_TPM=ERRORE"
    if "%RC%"=="0" set "RC=%errorlevel%"
) else (
    set "ST_TPM=OK"
)

:END
echo.
powershell -NoProfile -Command "Write-Host 'Pulizia log WinGet...' -ForegroundColor Gray"
if exist "%LOGDIR%" del /q "%LOGDIR%\*.log" 2>nul

echo.
powershell -NoProfile -Command "Write-Host '============== RIASSUNTO FINALE ==============' -ForegroundColor Cyan"

call :PrintStatus "Rete" "%ST_NET%"
call :PrintStatus "Spazio disco" "%ST_DISK%"
call :PrintStatus "Pulizia cache" "%ST_CLEAN%"
call :PrintStatus "Sorgenti WinGet" "%ST_SOURCE%"
call :PrintStatus "Pacchetti WinGet" "%ST_WINGET%"
call :PrintStatus "Microsoft Store" "%ST_STORE%"
call :PrintStatus "PnP / hardware" "%ST_PNP%"
call :PrintStatus "Driver" "%ST_DRIVER%"
call :PrintStatus "TPM" "%ST_TPM%"

echo.
if not "%RC%"=="0" (
    powershell -NoProfile -Command "Write-Host 'Esito complessivo: COMPLETATO CON ERRORI (codice %RC%)' -ForegroundColor Red"
) else (
    powershell -NoProfile -Command "Write-Host 'Esito complessivo: COMPLETATO CON SUCCESSO' -ForegroundColor Green"
)

echo.
set /p "__END__=Premi INVIO per chiudere..."
exit /b %RC%

:PrintStatus
set "LBL=%~1"
set "VAL=%~2"
echo %VAL% | findstr /b /c:"OK" >nul
if "%errorlevel%"=="0" (
    powershell -NoProfile -Command "Write-Host '%LBL%: %VAL%' -ForegroundColor Green"
    goto :eof
)

echo %VAL% | findstr /b /c:"ATTENZIONE" >nul
if "%errorlevel%"=="0" (
    powershell -NoProfile -Command "Write-Host '%LBL%: %VAL%' -ForegroundColor Yellow"
    goto :eof
)

echo %VAL% | findstr /b /c:"ERRORE" >nul
if "%errorlevel%"=="0" (
    powershell -NoProfile -Command "Write-Host '%LBL%: %VAL%' -ForegroundColor Red"
    goto :eof
)

powershell -NoProfile -Command "Write-Host '%LBL%: %VAL%' -ForegroundColor Gray"
goto :eof