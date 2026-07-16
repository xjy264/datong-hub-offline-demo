[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
if (-not $settings.OwnsMySqlService) {
    $existingMySql = Get-Service $settings.MySqlServiceName -ErrorAction Stop
    if ($existingMySql.Status -ne 'Running') { throw "复用的MySQL服务未运行：$($settings.MySqlServiceName)" }
}
foreach ($name in @(Get-DatongManagedServices ([bool]$settings.OwnsMySqlService) $settings.MySqlServiceName)) {
    $service = Get-Service $name -ErrorAction Stop
    if ($service.Status -ne 'Running') { Start-Service $name }
}
Write-Host '项目服务已启动。' -ForegroundColor Green
