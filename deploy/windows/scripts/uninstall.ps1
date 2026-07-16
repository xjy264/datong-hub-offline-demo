[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [switch]$RemoveData
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
if (-not (Test-DatongAdministrator)) { throw '请使用管理员PowerShell运行卸载。' }
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
& (Join-Path $PSScriptRoot 'stop.ps1') -DataRoot $DataRoot
$serviceDir = Join-Path $DataRoot 'services'
foreach ($name in @('DatongMapBackend','DatongMapMinIO')) {
    $exe = Join-Path $serviceDir "$name.exe"
    if (Test-Path $exe) { & $exe uninstall | Out-Null }
}
if ($settings.OwnsMySqlService) {
    & $settings.MySqlExecutable --remove $settings.MySqlServiceName | Out-Null
}
Get-NetFirewallRule -DisplayName 'DatongMap-HTTPS-8012' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
& schtasks.exe /Delete /TN 'DatongMap-DailyBackup' /F 2>$null | Out-Null
if ($RemoveData) { Remove-Item $DataRoot -Recurse -Force }
Write-Host '项目服务和防火墙规则已移除；复用的MySQL服务保持原状。' -ForegroundColor Green
