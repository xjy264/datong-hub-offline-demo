@echo off
chcp 65001 >nul
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set /p SERVER_NAME=请输入服务器名称（服务端电脑名）：
set /p SERVER_IP=请输入服务器局域网IP：
set CERT_FILE=%~dp0client\datong-map.cer
if not exist "%CERT_FILE%" (
  echo 证书文件缺失：%CERT_FILE%
  pause
  exit /b 2
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-client-certificate.ps1" -CertificatePath "%CERT_FILE%" -ServerName "%SERVER_NAME%"
if errorlevel 1 (
  pause
  exit /b 2
)
echo 访问地址：https://%SERVER_IP%:8012
start "" "https://%SERVER_IP%:8012"
pause
