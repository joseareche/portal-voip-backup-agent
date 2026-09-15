@echo off
REM Build PortalVoIPBackupAgent for Windows amd64
REM Requires Go 1.20+ on PATH (or set GO_BIN)
setlocal
if defined GO_BIN (
  set "GOEXE=%GO_BIN%"
) else (
  set "GOEXE=go"
)
set CGO_ENABLED=0
set GOOS=windows
set GOARCH=amd64
cd /d "%~dp0.."
"%GOEXE%" build -ldflags="-s -w" -o "PortalVoIPBackupAgent.exe" .\cmd\PortalVoIPBackupAgent
if errorlevel 1 exit /b 1
echo Built: %cd%\PortalVoIPBackupAgent.exe
