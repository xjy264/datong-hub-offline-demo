@echo off
chcp 65001 >nul
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo 正在申请管理员权限...
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo =====================================================
echo 大同示意图 Windows 分阶段部署向导
echo 每一步成功后才会进入下一步，出现红色信息时请停止。
echo =====================================================

call :run 01 "环境只读检测" "scripts\01-check-environment.ps1"
if errorlevel 1 goto :failed
if exist "reports\environment-report.html" start "" "reports\environment-report.html"
call :confirm
if errorlevel 1 goto :cancelled

if exist "C:\ProgramData\DatongMap\config\stage-02.complete" (
  call :reuse "阶段02配置"
  if not errorlevel 1 goto :stage03
)
call :run 02 "确认配置与生成证书" "scripts\02-configure.ps1"
if errorlevel 1 goto :failed
call :confirm
if errorlevel 1 goto :cancelled

:stage03
if exist "C:\ProgramData\DatongMap\config\stage-03.complete" (
  call :reuse "阶段03数据库"
  if not errorlevel 1 goto :stage04
)
call :run 03 "准备MySQL数据库" "scripts\03-prepare-database.ps1"
if errorlevel 1 goto :failed
call :confirm
if errorlevel 1 goto :cancelled

:stage04
if exist "C:\ProgramData\DatongMap\config\stage-04.complete" (
  call :reuse "阶段04服务安装"
  if not errorlevel 1 goto :stage05
)
call :run 04 "安装Windows服务" "scripts\04-install-services.ps1"
if errorlevel 1 goto :failed
:stage05
call :run 05 "部署验收" "scripts\05-verify.ps1"
if errorlevel 1 goto :failed
if exist "reports\deployment-result.html" start "" "reports\deployment-result.html"
echo.
echo [成功] 服务端部署完成。接下来给客户端运行“客户端证书安装.cmd”。
pause
exit /b 0

:run
echo.
echo ---------- 阶段%1：%~2 ----------
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0%~3"
exit /b %errorlevel%

:confirm
echo.
choice /C YN /N /M "本阶段结果已确认，继续下一步？[Y/N] "
if errorlevel 2 exit /b 1
exit /b 0

:reuse
choice /C YN /N /M "检测到已完成的%~1，是否直接复用并继续？[Y/N] "
if errorlevel 2 exit /b 1
exit /b 0

:failed
echo.
echo [停止] 当前阶段出现异常。
if exist "C:\ProgramData\DatongMap\config\deployment-settings.json" (
  echo 正在生成脱敏诊断包...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\collect-diagnostics.ps1"
)
echo 请把reports目录或诊断ZIP交给远程技术人员。
pause
exit /b 2

:cancelled
echo 部署已由操作人员暂停，可稍后重新运行本向导。
pause
exit /b 1
