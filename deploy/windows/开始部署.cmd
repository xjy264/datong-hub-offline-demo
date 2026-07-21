@echo off
chcp 65001 >nul
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo 正在申请管理员权限，请在弹窗中选择“是”...
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
  exit /b
)

echo =====================================================
echo 大同示意图 Windows 一键部署
echo 部署期间请保持本窗口打开，系统将自动完成全部五个阶段。
echo =====================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1"
set EXIT_CODE=%ERRORLEVEL%
if exist "%~dp0reports\deployment-status.html" start "" "%~dp0reports\deployment-status.html"

echo.
if "%EXIT_CODE%"=="0" (
  echo [完成] 部署成功，浏览器将显示验收结果。
) else (
  echo [停止] 部署在某个阶段出现异常，浏览器将显示失败位置。
  echo 请把页面中标出的诊断ZIP发送给技术人员。
)
pause
exit /b %EXIT_CODE%
