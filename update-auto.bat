@echo off
setlocal EnableExtensions
cd /d "%~dp0"
chcp 65001 >nul

title Update Manager Auto

set "MAINPS1=%~dp0update-main.ps1"
set "CFGFILE=%~dp0update-settings.ini"

if not exist "%CFGFILE%" (
    (
        echo OPT_CACHE=1
        echo OPT_SOURCES=1
        echo OPT_WINGET=1
        echo OPT_PNP=0
        echo OPT_DRIVERS=0
        echo OPT_TPM=0
        echo OPT_EXPORT=1
    ) > "%CFGFILE%"
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

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%MAINPS1%" (
    echo ERRORE: file update-main.ps1 non trovato.
    pause
    exit /b 1
)

echo Avvio automatico con configurazione salvata...
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
