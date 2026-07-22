[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [switch]$RemoveData,
    [switch]$RemoveCertificates
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
if (-not (Test-DatongAdministrator)) { throw '请使用管理员PowerShell运行卸载。' }
$settingsPath = Join-Path $DataRoot 'config\deployment-settings.json'
$settings = $null
if (Test-Path $settingsPath) {
    try { $settings = Read-DatongJson $settingsPath }
    catch { Write-Warning '部署配置不完整，将按项目固定资源名称继续清理。' }
}
$serviceDir = Join-Path $DataRoot 'services'
foreach ($name in @('DatongMapBackend','DatongMapMinIO')) {
    $exe = Join-Path $serviceDir "$name.exe"
    Stop-Service $name -Force -ErrorAction SilentlyContinue
    if (Test-Path $exe) { & $exe uninstall | Out-Null }
    elseif (Get-Service $name -ErrorAction SilentlyContinue) { & sc.exe delete $name | Out-Null }
}
$ownsMySql = $settings -and $settings.PSObject.Properties['OwnsMySqlService'] -and [bool]$settings.OwnsMySqlService
$hasMySqlDetails = $settings -and $settings.PSObject.Properties['MySqlExecutable'] -and $settings.PSObject.Properties['MySqlServiceName']
if ($ownsMySql -and $hasMySqlDetails -and (Test-Path $settings.MySqlExecutable)) {
    Stop-Service $settings.MySqlServiceName -Force -ErrorAction SilentlyContinue
    & $settings.MySqlExecutable --remove $settings.MySqlServiceName | Out-Null
} elseif (Get-Service 'DatongMapMySQL' -ErrorAction SilentlyContinue) {
    Stop-Service 'DatongMapMySQL' -Force -ErrorAction SilentlyContinue
    & sc.exe delete 'DatongMapMySQL' | Out-Null
}
Get-NetFirewallRule -DisplayName 'DatongMap-HTTPS-8012' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
& schtasks.exe /Delete /TN 'DatongMap-DailyBackup' /F 2>$null | Out-Null
if ($RemoveCertificates) {
    $thumbprintPath = Join-Path $DataRoot 'certificate\certificate-thumbprint.txt'
    $thumbprint = if ($settings -and $settings.PSObject.Properties['CertificateThumbprint']) { [string]$settings.CertificateThumbprint } elseif (Test-Path $thumbprintPath) { [string](Get-Content $thumbprintPath -Raw -Encoding ASCII) } else { '' }
    $thumbprint = $thumbprint.Replace(' ', '').Trim().ToUpperInvariant()
    if ($thumbprint) {
        foreach ($store in @('Cert:\LocalMachine\My','Cert:\LocalMachine\Root')) {
            Get-ChildItem $store -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}
if ($RemoveData -and (Test-Path $DataRoot)) { Remove-Item $DataRoot -Recurse -Force }
Write-Host '项目服务和防火墙规则已移除；复用的MySQL服务保持原状。' -ForegroundColor Green
