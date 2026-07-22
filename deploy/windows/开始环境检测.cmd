@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\01-check-environment.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
if exist "%~dp0reports\environment-report.html" start "" "%~dp0reports\environment-report.html"
pause
exit /b %EXIT_CODE%
