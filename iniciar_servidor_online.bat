@echo off
title GeoVisor PDU Anta - Servidor Cloudflare
cd /d "%~dp0"

echo ==============================================================================
echo  GEOVISOR PDU ANTA (2024 - 2034) - SERVIDOR PUBLICO CON CLOUDFLARE TUNNEL
echo ==============================================================================
echo.

if not exist "tools\cloudflared.exe" (
    echo [*] Descargando herramienta Cloudflare Tunnel...
    if not exist "tools" mkdir "tools"
    curl.exe -L -o "tools\cloudflared.exe" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
)

set "RSCRIPT_CMD=Rscript.exe"
where Rscript.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    for /d %%D in ("C:\Program Files\R\R-*") do (
        if exist "%%D\bin\x64\Rscript.exe" set "RSCRIPT_CMD=%%D\bin\x64\Rscript.exe"
        if exist "%%D\bin\Rscript.exe" set "RSCRIPT_CMD=%%D\bin\Rscript.exe"
    )
)

echo [1/2] Iniciando el GeoVisor en segundo plano (puerto 3838)...
start "" /B "%RSCRIPT_CMD%" -e "shiny::runApp(appDir='.', host='127.0.0.1', port=3838)"
timeout /t 3 /nobreak >nul

echo [2/2] Conectando tunel HTTPS seguro con Cloudflare...
echo.
echo ==============================================================================
echo   BUSCA ABAJO EL ENLACE QUE TERMINA EN: .trycloudflare.com
echo   Ese enlace es publico: puedes abrirlo en celulares, computadoras o compartirlo.
echo   Para cerrar el servidor, presiona Ctrl + C o cierra esta ventana.
echo ==============================================================================
echo.

tools\cloudflared.exe tunnel --url http://127.0.0.1:3838

:: Al salir, detener proceso Shiny
taskkill /F /IM Rscript.exe >nul 2>&1
echo Servidor cerrado.
pause

