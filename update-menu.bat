@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
chcp 65001 >nul
color 0B
title Update Manager Leggero

set "MAINPS1=%~dp0update-main.ps1"
set "CFGFILE=%~dp0update-settings.ini"

call :loadDefaults
call :loadConfig

:menu
cls
echo ========================================
echo     UPDATE MANAGER LEGGERO PERSISTENTE
echo ========================================
echo.
echo Le impostazioni vengono salvate automaticamente.
echo.
call :refreshStatus

echo 1. Pulizia cache                  [!S1!]
echo 2. Aggiorna sorgenti WinGet       [!S2!]
echo 3. Aggiorna pacchetti WinGet      [!S3!]
echo 4. Scansione hardware PnP         [!S4!]
echo 5. Controllo driver               [!S5!]
echo 6. Controllo TPM SecureBoot UEFI  [!S6!]
echo 7. Export lista app WinGet        [!S7!]
echo.
echo R. Esegui adesso
echo A. Attiva tutto
echo L. Profilo leggero consigliato
echo D. Ripristina default
echo Q. Esci
echo.
set /p "CHOICE=Scelta: "

if /I "%CHOICE%"=="1" call :toggle OPT_CACHE
if /I "%CHOICE%"=="2" call :toggle OPT_SOURCES
if /I "%CHOICE%"=="3" call :toggle OPT_WINGET
if /I "%CHOICE%"=="4" call :toggle OPT_PNP
if /I "%CHOICE%"=="5" call :toggle OPT_DRIVERS
if /I "%CHOICE%"=="6" call :toggle OPT_TPM
if /I "%CHOICE%"=="7" call :toggle OPT_EXPORT
if /I "%CHOICE%"=="A" goto allon
if /I "%CHOICE%"=="L" goto light
if /I "%CHOICE%"=="D" goto defaults
if /I "%CHOICE%"=="R" goto run
if /I "%CHOICE%"=="Q" exit /b 0
goto menu

:loadDefaults
set "OPT_CACHE=1"
set "OPT_SOURCES=1"
set "OPT_WINGET=1"
set "OPT_PNP=0"
set "OPT_DRIVERS=0"
set "OPT_TPM=0"
set "OPT_EXPORT=1"
exit /b

:loadConfig
if not exist "%CFGFILE%" (
    call :saveConfig
    exit /b
)
for /f "usebackq tokens=1,* delims==" %%A in ("%CFGFILE%") do (
    if /I "%%A"=="OPT_CACHE" set "OPT_CACHE=%%B"
    if /I "%%A"=="OPT_SOURCES" set "OPT_SOURCES=%%B"
    if /I "%%A"=="OPT_WINGET" set "OPT_WINGET=%%B"
    if /I "%%A"=="OPT_PNP" set "OPT_PNP=%%B"
    if /I "%%A"=="OPT_DRIVERS" set "OPT_DRIVERS=%%B"
    if /I "%%A"=="OPT_TPM" set "OPT_TPM=%%B"
    if /I "%%A"=="OPT_EXPORT" set "OPT_EXPORT=%%B"
)
exit /b

:saveConfig
(
    echo OPT_CACHE=%OPT_CACHE%
    echo OPT_SOURCES=%OPT_SOURCES%
    echo OPT_WINGET=%OPT_WINGET%
    echo OPT_PNP=%OPT_PNP%
    echo OPT_DRIVERS=%OPT_DRIVERS%
    echo OPT_TPM=%OPT_TPM%
    echo OPT_EXPORT=%OPT_EXPORT%
) > "%CFGFILE%"
exit /b

:refreshStatus
if "%OPT_CACHE%"=="1" (set "S1=ON ") else set "S1=OFF"
if "%OPT_SOURCES%"=="1" (set "S2=ON ") else set "S2=OFF"
if "%OPT_WINGET%"=="1" (set "S3=ON ") else set "S3=OFF"
if "%OPT_PNP%"=="1" (set "S4=ON ") else set "S4=OFF"
if "%OPT_DRIVERS%"=="1" (set "S5=ON ") else set "S5=OFF"
if "%OPT_TPM%"=="1" (set "S6=ON ") else set "S6=OFF"
if "%OPT_EXPORT%"=="1" (set "S7=ON ") else set "S7=OFF"
exit /b

:toggle
if "!%~1!"=="1" (
    set "%~1=0"
) else (
    set "%~1=1"
)
call :saveConfig
exit /b

:allon
set "OPT_CACHE=1"
set "OPT_SOURCES=1"
set "OPT_WINGET=1"
set "OPT_PNP=1"
set "OPT_DRIVERS=1"
set "OPT_TPM=1"
set "OPT_EXPORT=1"
call :saveConfig
goto menu

:light
set "OPT_CACHE=1"
set "OPT_SOURCES=1"
set "OPT_WINGET=1"
set "OPT_PNP=0"
set "OPT_DRIVERS=0"
set "OPT_TPM=0"
set "OPT_EXPORT=1"
call :saveConfig
goto menu

:defaults
call :loadDefaults
call :saveConfig
goto menu

:run
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%MAINPS1%" (
    echo.
    echo ERRORE: file update-main.ps1 non trovato.
    pause
    exit /b 1
)

echo.
echo Avvio procedura...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MAINPS1%" ^
 -DoCache %OPT_CACHE% ^
 -DoSources %OPT_SOURCES% ^
 -DoWinget %OPT_WINGET% ^
 -DoPnP %OPT_PNP% ^
 -DoDrivers %OPT_DRIVERS% ^
 -DoTPM %OPT_TPM% ^
 -DoExport %OPT_EXPORT%
set "RC=%errorlevel%"

echo.
set /p "__END__=Premi INVIO per chiudere..."
exit /b %RC%
