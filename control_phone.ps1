# Espejo + control del celular desde la PC.
# Uso: .\control_phone.ps1
# En la ventana: click = toque, rueda = scroll, teclado = escribir.

$ErrorActionPreference = "Stop"
$preferredId = "RFCT42JGPXE"

$scrcpyDir = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "Genymobile.scrcpy*" } |
  ForEach-Object { Get-ChildItem $_.FullName -Directory -Filter "scrcpy-win64-*" } |
  Select-Object -First 1 -ExpandProperty FullName

if (-not $scrcpyDir -or -not (Test-Path "$scrcpyDir\scrcpy.exe")) {
  Write-Host "scrcpy no esta instalado. Corre:" -ForegroundColor Red
  Write-Host '  winget install --id Genymobile.scrcpy -e --source winget'
  exit 1
}

$adbSdk = "$env:LOCALAPPDATA\Android\sdk\platform-tools"
if (-not (Test-Path "$adbSdk\adb.exe")) {
  $adbSdk = "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
}

$env:Path = "$scrcpyDir;$adbSdk;" + $env:Path
Set-Location $scrcpyDir

Write-Host "Abriendo pantalla del celular..." -ForegroundColor Green
Write-Host "Puedes tocar y mover todo desde la PC." -ForegroundColor Cyan
.\scrcpy.exe -s $preferredId --max-size 1024 --stay-awake --window-title "AgroApp - Celular"
