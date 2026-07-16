[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [string]$AdministratorUser = 'root',
    [securestring]$AdministratorPassword
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
Write-DatongStage '阶段03：准备MySQL数据库'
if (-not (Test-DatongAdministrator)) { throw '请使用管理员PowerShell运行本阶段。' }
$settingsPath = Join-Path $DataRoot 'config\deployment-settings.json'
$settings = Read-DatongJson $settingsPath
$packageRoot = $settings.PackageRoot
$mysql = Join-Path $packageRoot 'runtime\mysql\bin\mysql.exe'
$mysqldump = Join-Path $packageRoot 'runtime\mysql\bin\mysqldump.exe'
if (-not (Test-Path $mysql) -or -not (Test-Path $mysqldump)) { throw '完整离线包缺少MySQL客户端工具。' }
$adminPasswordPlain = ''

if ($settings.MySqlMode -eq 'Bundled') {
    $mysqlRoot = Join-Path $packageRoot 'runtime\mysql'
    $mysqld = Join-Path $mysqlRoot 'bin\mysqld.exe'
    if (-not (Test-Path $mysqld) -or -not (Test-Path $mysql)) {
        throw '部署包缺少runtime\mysql，请把环境报告交给远程技术人员重新制作完整离线包。'
    }
    $vcRuntime = Join-Path $packageRoot 'runtime\prerequisites\vc_redist.x64.exe'
    if (-not (Test-Path $vcRuntime)) { throw '完整离线包缺少Microsoft Visual C++运行库安装程序。' }
    $vcProcess = Start-Process -FilePath $vcRuntime -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
    if ($vcProcess.ExitCode -notin @(0, 1638, 3010)) { throw "Microsoft Visual C++运行库安装失败，退出代码：$($vcProcess.ExitCode)" }
    $mysqlData = Join-Path $DataRoot 'mysql\data'
    $mysqlConfig = Join-Path $DataRoot 'mysql\my.ini'
    New-Item -ItemType Directory -Force -Path (Split-Path $mysqlConfig -Parent) | Out-Null
    $mysqlConfigText = @"
[mysqld]
basedir=$($mysqlRoot.Replace('\','/'))
datadir=$($mysqlData.Replace('\','/'))
port=$($settings.MySqlPort)
bind-address=127.0.0.1
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
[client]
port=$($settings.MySqlPort)
default-character-set=utf8mb4
"@
    $mysqlConfigText | Set-Content $mysqlConfig -Encoding ASCII
    if (-not (Test-Path $mysqlData)) {
        & $mysqld "--defaults-file=$mysqlConfig" --initialize-insecure
        if ($LASTEXITCODE -ne 0) { throw '项目独立MySQL初始化失败。' }
    }
    if (-not (Get-Service $settings.MySqlServiceName -ErrorAction SilentlyContinue)) {
        & $mysqld "--defaults-file=$mysqlConfig" --install $settings.MySqlServiceName
        if ($LASTEXITCODE -ne 0) { throw '项目独立MySQL服务注册失败。' }
        & sc.exe config $settings.MySqlServiceName start= auto | Out-Null
    }
    Start-Service $settings.MySqlServiceName
    $deadline = (Get-Date).AddSeconds(60)
    do {
        Start-Sleep -Seconds 2
        & $mysql --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" --user=root -e 'SELECT 1' 2>$null
        $ready = $LASTEXITCODE -eq 0
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw '项目独立MySQL启动超时。' }
    $env:MYSQL_PWD = ''
} else {
    $adminPassword = if ($AdministratorPassword) { $AdministratorPassword } else { Read-Host "请输入 $AdministratorUser 的MySQL密码（仅用于本次建库）" -AsSecureString }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword)
    try { $adminPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer); $env:MYSQL_PWD = $adminPasswordPlain }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    & $mysql --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$AdministratorUser" --batch --skip-column-names -e 'SELECT VERSION()'
    if ($LASTEXITCODE -ne 0) { $env:MYSQL_PWD = $null; throw '现有MySQL连接验证失败，请把错误截图和环境报告交给远程技术人员。' }
}

$databaseExistsRaw = & $mysql --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$AdministratorUser" --batch --skip-column-names -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$($settings.MySqlDatabase)'"
if ($LASTEXITCODE -ne 0) { $env:MYSQL_PWD = $null; throw '数据库状态检查失败。' }
$databaseExists = ([int](($databaseExistsRaw | Select-Object -Last 1).ToString().Trim())) -gt 0
$tables = @()
if ($databaseExists) {
    $tables = @(& $mysql --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$AdministratorUser" --batch --skip-column-names -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$($settings.MySqlDatabase)'")
    if ($LASTEXITCODE -ne 0) { $env:MYSQL_PWD = $null; throw '数据库表检查失败。' }
}
$decision = Get-DatongDatabaseDecision $databaseExists $tables
if ($decision.Action -eq 'Stop') {
    $env:MYSQL_PWD = $null
    throw "$($decision.Reason) 已保留原数据库，请将环境报告交给远程技术人员。"
}
if ($decision.Action -eq 'Upgrade') {
    $preUpgrade = Join-Path $settings.BackupRoot ('pre-upgrade-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $preUpgrade | Out-Null
    & $mysqldump --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$AdministratorUser" --single-transaction --no-tablespaces $settings.MySqlDatabase | Set-Content (Join-Path $preUpgrade 'mysql.sql') -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { $env:MYSQL_PWD = $null; throw '升级前数据库备份失败。' }
}

$sql = @"
CREATE DATABASE IF NOT EXISTS ``$($settings.MySqlDatabase)`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$($settings.MySqlUser)'@'127.0.0.1' IDENTIFIED BY '$($settings.MySqlPassword)';
ALTER USER '$($settings.MySqlUser)'@'127.0.0.1' IDENTIFIED BY '$($settings.MySqlPassword)';
GRANT ALL PRIVILEGES ON ``$($settings.MySqlDatabase)``.* TO '$($settings.MySqlUser)'@'127.0.0.1';
FLUSH PRIVILEGES;
"@
& $mysql --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$AdministratorUser" -e $sql
$exitCode = $LASTEXITCODE
$env:MYSQL_PWD = $null
if ($exitCode -ne 0) { throw '业务数据库或账号创建失败。' }

$propertiesPath = Join-Path $DataRoot 'config\application-windows.properties'
$forwardDataRoot = $DataRoot.Replace('\','/')
$forwardPfx = $settings.CertificatePath.Replace('\','/')
$properties = @"
spring.profiles.active=windows
server.port=$($settings.ServerPort)
server.ssl.enabled=true
server.ssl.key-store=file:$forwardPfx
server.ssl.key-store-password=$($settings.CertificatePassword)
server.ssl.key-store-type=PKCS12
spring.datasource.url=jdbc:mysql://127.0.0.1:$($settings.MySqlPort)/$($settings.MySqlDatabase)?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai
spring.datasource.username=$($settings.MySqlUser)
spring.datasource.password=$($settings.MySqlPassword)
app.production=true
app.auth.cookie-secure=true
app.jwt.secret=$($settings.JwtSecret)
app.minio.endpoint=http://127.0.0.1:9011
app.minio.access-key=$($settings.MinioAccessKey)
app.minio.secret-key=$($settings.MinioSecretKey)
app.minio.bucket=datong-map
management.health.redis.enabled=false
logging.file.name=$forwardDataRoot/logs/backend/application.log
"@
$properties | Set-Content $propertiesPath -Encoding UTF8
Set-DatongPrivateAcl (Split-Path $propertiesPath -Parent)
Set-Content (Join-Path $DataRoot 'config\stage-03.complete') (Get-Date).ToString('o') -Encoding ASCII
Write-Host '数据库准备完成。下一步：运行 scripts\04-install-services.ps1' -ForegroundColor Green
