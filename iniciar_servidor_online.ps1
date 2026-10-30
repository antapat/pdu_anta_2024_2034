param(
    [int]$Puerto = 3838
)

$raiz = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $raiz

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " GEOVISOR PDU ANTA (2024 - 2034) - SERVIDOR PUBLICO CON CLOUDFLARE TUNNEL" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

$cloudflared = Join-Path $raiz "tools\cloudflared.exe"
if (-not (Test-Path $cloudflared)) {
    Write-Host "[*] Descargando herramienta Cloudflare Tunnel..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path (Join-Path $raiz "tools") -Force | Out-Null
    curl.exe -L -o $cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
}

Write-Host "[1/2] Iniciando el GeoVisor en http://127.0.0.1:$Puerto ..." -ForegroundColor Yellow
$rProcess = Start-Process -FilePath "Rscript.exe" -ArgumentList "-e `"shiny::runApp(appDir='.', host='127.0.0.1', port=$Puerto)`"" -PassThru -NoNewWindow

Start-Sleep -Seconds 3

Write-Host "[2/2] Estableciendo tunel HTTPS seguro con Cloudflare..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  >> BUSCA ABAJO LA LINEA QUE DICE: https://...trycloudflare.com <<" -ForegroundColor Green
Write-Host "  >> ESE ES EL ENLACE QUE PUEDES COMPARTIR Y ABRIR EN CUALQUIER CELULAR <<" -ForegroundColor Green
Write-Host ""
Write-Host "  [Para detener el servidor, presiona Ctrl + C en esta ventana]" -ForegroundColor Magenta
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

try {
    & $cloudflared tunnel --url "http://127.0.0.1:$Puerto"
} finally {
    Write-Host "`nCerrando servidor GeoVisor..." -ForegroundColor Yellow
    if ($rProcess -and -not $rProcess.HasExited) {
        Stop-Process -Id $rProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Servidor detenido correctamente." -ForegroundColor Green
}

