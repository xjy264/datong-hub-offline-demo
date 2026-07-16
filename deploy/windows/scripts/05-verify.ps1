[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
Write-DatongStage '阶段05：部署验收'
$settings = Read-DatongJson (Join-Path $DataRoot 'config\deployment-settings.json')
$services = @(@($settings.MySqlServiceName, 'DatongMapMinIO', 'DatongMapBackend') | ForEach-Object {
    $service = Get-Service $_ -ErrorAction SilentlyContinue
    [pscustomobject]@{ Name = $_; State = if ($service) { $service.Status.ToString() } else { 'Missing' } }
})
$deadline = (Get-Date).AddMinutes(2)
$health = $null
$oldCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
try {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    do {
        try { $health = Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:$($settings.ServerPort)/actuator/health" -TimeoutSec 5 }
        catch { Start-Sleep -Seconds 3 }
    } while (-not $health -and (Get-Date) -lt $deadline)
    $home = if ($health) { Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:$($settings.ServerPort)/" -TimeoutSec 10 } else { $null }
} finally {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = $oldCallback
}
$ports = @(@(8012, 9011, 9012, [int]$settings.MySqlPort) | ForEach-Object {
    $owner = Get-DatongPortOwner $_
    if ($owner) { $owner } else { [pscustomobject]@{ Port = $_; Address = ''; ProcessId = 0; ProcessName = '未监听' } }
})
$problems = @()
if (@($services | Where-Object { $_.State -ne 'Running' }).Count -gt 0) { $problems += '存在未运行的项目服务。' }
if (-not $health -or $health.StatusCode -ne 200) { $problems += '健康检查未通过。' }
if (-not $home -or $home.Content -notmatch '<div id="app">') { $problems += '前端首页未正确返回。' }
if (@($ports | Where-Object { $_.Port -in @(9011,9012) -and $_.Address -notin @('127.0.0.1','::1') }).Count -gt 0) {
    $problems += '内部端口存在非本机监听，请交给远程技术人员检查。'
}
$warnings = @()
if (-not $settings.OwnsMySqlService) {
    $externalMySql = @($ports | Where-Object { $_.Port -eq [int]$settings.MySqlPort -and $_.Address -notin @('127.0.0.1','::1') })
    if ($externalMySql.Count -gt 0) { $warnings += '复用的MySQL监听范围由甲方原配置决定，本项目未修改。' }
}
$report = [ordered]@{
    GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Url = "https://$($settings.ServerName):$($settings.ServerPort)"
    Services = $services
    Ports = $ports
    HealthStatus = if ($health) { $health.StatusCode } else { 0 }
    FrontendStatus = if ($home) { $home.StatusCode } else { 0 }
    Problems = $problems
    Warnings = $warnings
    Result = if ($problems.Count -eq 0) { 'PASS' } else { 'STOP' }
    NextAction = if ($problems.Count -eq 0) { '把client目录和客户端证书安装.cmd复制到局域网客户端。' } else { '运行collect-diagnostics.ps1并把诊断ZIP发送给远程技术人员。' }
}
$reports = Join-Path $settings.PackageRoot 'reports'
Write-DatongReport (Join-Path $reports 'deployment-result.json') (Join-Path $reports 'deployment-result.html') '大同示意图 Windows 部署验收报告' $report
Write-Host "验收结果：$($report.Result)" -ForegroundColor $(if ($report.Result -eq 'PASS') { 'Green' } else { 'Red' })
if ($problems.Count -gt 0) { exit 2 }
