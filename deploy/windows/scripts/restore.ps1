[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BackupPath,
    [string]$DataRoot = 'C:\ProgramData\DatongMap'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
foreach ($path in @((Join-Path $BackupPath 'mysql.sql'), (Join-Path $BackupPath 'minio'))) {
    if (-not (Test-Path $path)) { throw "备份内容缺少：$path" }
}
& (Join-Path $PSScriptRoot 'backup.ps1') -DataRoot $DataRoot
Stop-Service 'DatongMapBackend' -Force -ErrorAction SilentlyContinue
$mysql = Join-Path (Split-Path $settings.MySqlExecutable -Parent) 'mysql.exe'
$env:MYSQL_PWD = $settings.MySqlPassword
Get-Content (Join-Path $BackupPath 'mysql.sql') -Raw | & $mysql --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$($settings.MySqlUser)" $settings.MySqlDatabase
$restoreExit = $LASTEXITCODE
$env:MYSQL_PWD = $null
if ($restoreExit -ne 0) { throw 'MySQL恢复失败。' }
$mc = Join-Path $settings.PackageRoot 'runtime\minio\mc.exe'
$mcConfig = Join-Path $env:TEMP ('datong-mc-restore-' + (Get-Date -Format 'yyyyMMddHHmmss'))
try {
    & $mc --config-dir $mcConfig alias set local http://127.0.0.1:9011 $settings.MinioAccessKey $settings.MinioSecretKey | Out-Null
    & $mc --config-dir $mcConfig mirror --overwrite --remove (Join-Path $BackupPath 'minio') local/datong-map
    if ($LASTEXITCODE -ne 0) { throw 'MinIO恢复失败。' }
} finally { Remove-Item $mcConfig -Recurse -Force -ErrorAction SilentlyContinue }
Start-Service 'DatongMapBackend'
& (Join-Path $PSScriptRoot '05-verify.ps1') -DataRoot $DataRoot
