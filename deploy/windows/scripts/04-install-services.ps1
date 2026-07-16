[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
Write-DatongStage '阶段04：安装项目Windows服务'
if (-not (Test-DatongAdministrator)) { throw '请使用管理员PowerShell运行本阶段。' }
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
$packageRoot = $settings.PackageRoot
$properties = Join-Path $DataRoot 'config\application-windows.properties'
$winsw = Join-Path $packageRoot 'runtime\winsw\WinSW-x64.exe'
$minio = Join-Path $packageRoot 'runtime\minio\minio.exe'
$mc = Join-Path $packageRoot 'runtime\minio\mc.exe'
$java = Join-Path $packageRoot 'runtime\java\bin\java.exe'
$jar = Join-Path $packageRoot 'app\datong-map-server.jar'
foreach ($required in @($properties, $winsw, $minio, $mc, $java, $jar)) {
    if (-not (Test-Path $required)) { throw "部署包缺少文件：$required" }
}

function Xml([string]$value) { return [Security.SecurityElement]::Escape($value) }
function Render([string]$template, [hashtable]$tokens) {
    $content = Get-Content $template -Raw -Encoding UTF8
    foreach ($key in $tokens.Keys) { $content = $content.Replace("@@$key@@", [string]$tokens[$key]) }
    if ($content -match '@@[A-Z_]+@@') { throw "服务模板存在未替换项目：$($Matches[0])" }
    return $content
}
function Install-WrappedService([string]$name, [string]$exe, [string]$xml) {
    if (Get-Service $name -ErrorAction SilentlyContinue) {
        Stop-Service $name -Force -ErrorAction SilentlyContinue
        & $exe uninstall | Out-Null
    }
    & $exe install
    if ($LASTEXITCODE -ne 0) { throw "Windows服务安装失败：$name" }
}

$serviceDir = Join-Path $DataRoot 'services'
$minioData = Join-Path $DataRoot 'minio\data'
$minioLogs = Join-Path $DataRoot 'logs\minio'
$backendLogs = Join-Path $DataRoot 'logs\backend'
New-Item -ItemType Directory -Force -Path $serviceDir, $minioData, $minioLogs, $backendLogs | Out-Null

$minioServiceExe = Join-Path $serviceDir 'DatongMapMinIO.exe'
$backendServiceExe = Join-Path $serviceDir 'DatongMapBackend.exe'
Copy-Item $winsw $minioServiceExe -Force
Copy-Item $winsw $backendServiceExe -Force

$minioXml = Render (Join-Path $packageRoot 'service\minio.xml.template') @{
    MINIO_EXE = Xml $minio
    MINIO_DATA = Xml $minioData
    MINIO_USER = Xml $settings.MinioAccessKey
    MINIO_PASSWORD = Xml $settings.MinioSecretKey
    LOG_PATH = Xml $minioLogs
}
$minioXml | Set-Content (Join-Path $serviceDir 'DatongMapMinIO.xml') -Encoding UTF8
Install-WrappedService 'DatongMapMinIO' $minioServiceExe $minioXml
Start-Service 'DatongMapMinIO'

$mysqlDependency = if ($settings.OwnsMySqlService) { '<depend>' + (Xml $settings.MySqlServiceName) + '</depend>' } else { '' }
$backendXml = Render (Join-Path $packageRoot 'service\backend.xml.template') @{
    JAVA_EXE = Xml $java
    APP_JAR = Xml $jar
    APP_CONFIG = Xml $properties
    MYSQL_DEPENDENCY = $mysqlDependency
    LOG_PATH = Xml $backendLogs
}
$backendXml | Set-Content (Join-Path $serviceDir 'DatongMapBackend.xml') -Encoding UTF8
Install-WrappedService 'DatongMapBackend' $backendServiceExe $backendXml

$deadline = (Get-Date).AddSeconds(60)
do { Start-Sleep -Seconds 2; $minioReady = $null -ne (Get-DatongPortOwner 9011) } while (-not $minioReady -and (Get-Date) -lt $deadline)
if (-not $minioReady) { throw "MinIO启动超时，请查看 $minioLogs" }
$mcConfig = Join-Path $env:TEMP ('datong-mc-install-' + [guid]::NewGuid().ToString('N'))
try {
    & $mc --config-dir $mcConfig alias set local http://127.0.0.1:9011 $settings.MinioAccessKey $settings.MinioSecretKey | Out-Null
    & $mc --config-dir $mcConfig mb --ignore-existing local/datong-map | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'MinIO存储桶初始化失败。' }
} finally { Remove-Item $mcConfig -Recurse -Force -ErrorAction SilentlyContinue }
Start-Service 'DatongMapBackend'

$ruleName = 'DatongMap-HTTPS-8012'
Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $settings.ServerPort -Profile Domain,Private | Out-Null
$clientDir = Join-Path $packageRoot 'client'
New-Item -ItemType Directory -Force -Path $clientDir | Out-Null
Copy-Item $settings.ClientCertificatePath (Join-Path $clientDir 'datong-map.cer') -Force
$backupTaskCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $packageRoot 'scripts\backup.ps1') + '" -DataRoot "' + $DataRoot + '" -BackupRoot "' + $settings.BackupRoot + '"'
& schtasks.exe /Create /TN 'DatongMap-DailyBackup' /SC DAILY /ST 02:00 /RU SYSTEM /TR $backupTaskCommand /F | Out-Null
if ($LASTEXITCODE -ne 0) { throw '每日备份计划任务创建失败。' }
Set-DatongPrivateAcl (Join-Path $DataRoot 'config')
Set-DatongPrivateAcl $serviceDir
Set-Content (Join-Path $DataRoot 'config\stage-04.complete') (Get-Date).ToString('o') -Encoding ASCII
Write-Host '服务安装完成。下一步：运行 scripts\05-verify.ps1' -ForegroundColor Green
