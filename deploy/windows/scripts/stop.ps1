[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
$names = @('DatongMapBackend', 'DatongMapMinIO')
if ($settings.OwnsMySqlService) { $names += $settings.MySqlServiceName }
foreach ($name in $names) {
    $service = Get-Service $name -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Stopped') { Stop-Service $name -Force }
}
Write-Host '项目服务已停止，复用的MySQL服务保持原状态。' -ForegroundColor Green
