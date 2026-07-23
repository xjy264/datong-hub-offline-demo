@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting administrator privileges...
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\reinstall.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
if exist "%~dp0reports\deployment-status.html" start "" "%~dp0reports\deployment-status.html"
pause
exit /b %EXIT_CODE%
