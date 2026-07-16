[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
Get-Service $settings.MySqlServiceName, 'DatongMapMinIO', 'DatongMapBackend' -ErrorAction SilentlyContinue | Format-Table Name, Status, StartType -AutoSize
$oldCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
try {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $health = Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:$($settings.ServerPort)/actuator/health" -TimeoutSec 5
    Write-Host "健康检查：HTTP $($health.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "健康检查异常：$($_.Exception.Message)" -ForegroundColor Red
    exit 2
} finally {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = $oldCallback
}
