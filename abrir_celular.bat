@echo off
setlocal
set "SCRCPY_DIR=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.1"
set "ADB_DIR=%LOCALAPPDATA%\Android\sdk\platform-tools"
set "PATH=%SCRCPY_DIR%;%ADB_DIR%;%PATH%"

if not exist "%SCRCPY_DIR%\scrcpy.exe" (
  echo No se encontro scrcpy en:
  echo %SCRCPY_DIR%
  pause
  exit /b 1
)

cd /d "%SCRCPY_DIR%"
echo Abriendo pantalla del celular...
scrcpy.exe -s RFCT42JGPXE --max-size 1024 --stay-awake --window-title "AgroApp - Celular"
if errorlevel 1 pause
