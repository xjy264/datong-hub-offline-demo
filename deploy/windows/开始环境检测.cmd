@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\01-check-environment.ps1"
set EXIT_CODE=%ERRORLEVEL%
if exist "%~dp0reports\environment-report.html" start "" "%~dp0reports\environment-report.html"
echo.
echo 环境检测结束，退出代码：%EXIT_CODE%
echo 请查看 reports\environment-report.html。
pause
exit /b %EXIT_CODE%
