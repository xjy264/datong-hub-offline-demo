[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [string]$BackupRoot = 'C:\ProgramData\DatongMap\backups'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$target = Join-Path $BackupRoot "daily-$stamp"
New-Item -ItemType Directory -Force -Path (Join-Path $target 'minio') | Out-Null
$mysqlDir = Split-Path $settings.MySqlExecutable -Parent
$mysqldump = Join-Path $mysqlDir 'mysqldump.exe'
$mc = Join-Path $settings.PackageRoot 'runtime\minio\mc.exe'
if (-not (Test-Path $mysqldump)) { throw "缺少mysqldump.exe：$mysqldump" }
if (-not (Test-Path $mc)) { throw "缺少MinIO Client：$mc" }
$env:MYSQL_PWD = $settings.MySqlPassword
& $mysqldump --protocol=tcp --host=127.0.0.1 "--port=$($settings.MySqlPort)" "--user=$($settings.MySqlUser)" --single-transaction --no-tablespaces --routines --events $settings.MySqlDatabase | Set-Content (Join-Path $target 'mysql.sql') -Encoding UTF8
$dumpExit = $LASTEXITCODE
$env:MYSQL_PWD = $null
if ($dumpExit -ne 0) { throw 'MySQL备份失败。' }
$mcConfig = Join-Path $env:TEMP "datong-mc-$stamp"
try {
    & $mc --config-dir $mcConfig alias set local http://127.0.0.1:9011 $settings.MinioAccessKey $settings.MinioSecretKey | Out-Null
    & $mc --config-dir $mcConfig mirror local/datong-map (Join-Path $target 'minio')
    if ($LASTEXITCODE -ne 0) { throw 'MinIO备份失败。' }
} finally { Remove-Item $mcConfig -Recurse -Force -ErrorAction SilentlyContinue }
$manifest = [ordered]@{ CreatedAt=(Get-Date).ToString('o'); Database=$settings.MySqlDatabase; ServerName=$settings.ServerName; MySqlMode=$settings.MySqlMode }
Save-DatongJson (Join-Path $target 'manifest.json') $manifest
Get-ChildItem $BackupRoot -Directory -Filter 'daily-*' | Sort-Object Name -Descending | Select-Object -Skip 7 | Remove-Item -Recurse -Force
if ((Get-Date).DayOfWeek -eq [DayOfWeek]::Sunday) {
    $weekly = Join-Path $BackupRoot ("weekly-" + (Get-Date -Format 'yyyyMMdd'))
    if (-not (Test-Path $weekly)) { Copy-Item $target $weekly -Recurse }
    Get-ChildItem $BackupRoot -Directory -Filter 'weekly-*' | Sort-Object Name -Descending | Select-Object -Skip 4 | Remove-Item -Recurse -Force
}
Write-Host "备份完成：$target" -ForegroundColor Green
