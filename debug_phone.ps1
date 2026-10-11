# Debug AgroApp en el celular USB (reinicia ADB y espera el device).
# Uso: .\debug_phone.ps1

$ErrorActionPreference = "Stop"
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
}

Set-Location $PSScriptRoot

if (Test-Path $adb) {
  Write-Host "Reiniciando ADB..." -ForegroundColor Cyan
  & $adb kill-server | Out-Null
  & $adb start-server | Out-Null
  Start-Sleep -Seconds 2
  & $adb devices -l
} else {
  Write-Host "No encontre adb.exe; sigo con flutter devices" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Esperando celular (hasta 60s)..." -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds(60)
$deviceId = $null

while ((Get-Date) -lt $deadline) {
  $jsonText = flutter devices --machine 2>$null | Out-String
  if (-not [string]::IsNullOrWhiteSpace($jsonText)) {
    try {
      $devices = $jsonText | ConvertFrom-Json
      $phone = @(
        $devices | Where-Object {
          $_.targetPlatform -like "android*" -and
          $_.id -notlike "emulator-*" -and
          $_.emulator -ne $true
        }
      ) | Select-Object -First 1
      if ($null -ne $phone) {
        $deviceId = $phone.id
        Write-Host "OK: $($phone.name) ($deviceId)" -ForegroundColor Green
        break
      }
    } catch {}
  }
  Start-Sleep -Seconds 2
}

if (-not $deviceId) {
  Write-Host "No hay celular. Haz esto:" -ForegroundColor Red
  Write-Host "  1) Cable USB (modo transferencia / no solo carga)"
  Write-Host "  2) Opciones de desarrollador -> Depuracion USB ON"
  Write-Host "  3) En el celu acepta 'Permitir depuracion USB'"
  Write-Host "  4) Prueba otro cable/puerto"
  flutter devices
  exit 1
}

Write-Host "Lanzando..." -ForegroundColor Green
flutter run -d $deviceId --device-timeout 60
