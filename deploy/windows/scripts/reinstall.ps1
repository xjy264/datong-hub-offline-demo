[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [string]$PackageRoot = ''
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
if ([string]::IsNullOrWhiteSpace($PackageRoot)) { $PackageRoot = Resolve-DatongPackageRoot $PSScriptRoot }
if (-not (Test-DatongAdministrator)) { throw '请在Windows管理员权限窗口中运行完整重装。' }

$reports = Join-Path $PackageRoot 'reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null
Get-ChildItem $reports -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$clientDir = Join-Path $PackageRoot 'client'
if (Test-Path $clientDir) { Remove-Item $clientDir -Recurse -Force }
Get-ChildItem $PackageRoot -Filter 'DatongMap-Diagnostics-*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$logPath = Join-Path $reports 'reinstall.log'
$startedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$state = New-DatongDeploymentState -Stage 1 -StageName '完整重装清理' -Component 'CLEANUP' -Status 'RUNNING' -StartedAt $startedAt -Message '正在删除本项目服务、数据、配置、证书、hosts、计划任务和防火墙规则。'
Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $state

Start-Transcript -Path $logPath -Force | Out-Null
try {
    $thumbprintPath = Join-Path $DataRoot 'certificate\certificate-thumbprint.txt'
    $thumbprint = if (Test-Path $thumbprintPath) { [string](Get-Content $thumbprintPath -Raw -Encoding ASCII) } else { '' }
    $thumbprint = $thumbprint.Replace(' ', '').Trim().ToUpperInvariant()
    $settingsPath = Join-Path $DataRoot 'config\deployment-settings.json'
    $settings = $null
    if (Test-Path $settingsPath) {
        try { $settings = Read-DatongJson $settingsPath }
        catch { Write-Warning '部署配置不完整，将继续清理固定名称的项目资源。' }
    }
    $backupRoot = if ($settings -and $settings.PSObject.Properties['BackupRoot']) { [string]$settings.BackupRoot } else { '' }
    & (Join-Path $PSScriptRoot 'uninstall.ps1') -DataRoot $DataRoot -RemoveData -RemoveCertificates -RemoveBackups

    $serviceNames = @('DatongMapMySQL','DatongMapMinIO','DatongMapBackend')
    $deadline = (Get-Date).AddSeconds(30)
    do {
        $remainingServices = @($serviceNames | Where-Object { Get-Service $_ -ErrorAction SilentlyContinue })
        if ($remainingServices.Count -eq 0) { break }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    if ($remainingServices.Count -gt 0) { throw ('项目服务未清理完成：' + ($remainingServices -join '、')) }
    if (Test-Path $DataRoot) { throw "项目数据目录未清理完成：$DataRoot" }
    if ($backupRoot -and (Test-Path $backupRoot)) { throw "项目历史备份未清理完成：$backupRoot" }
    if (Get-NetFirewallRule -DisplayName 'DatongMap-HTTPS-8012' -ErrorAction SilentlyContinue) { throw '项目防火墙规则未清理完成。' }
    & cmd.exe /D /C 'schtasks.exe /Query /TN "DatongMap-DailyBackup" >nul 2>&1' | Out-Null
    if ($LASTEXITCODE -eq 0) { throw '项目备份计划任务未清理完成。' }
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    if ((Test-Path $hostsPath) -and ([IO.File]::ReadAllText($hostsPath).Contains('# DatongMap BEGIN'))) { throw '项目hosts配置未清理完成。' }
    if ($thumbprint) {
        foreach ($store in @('Cert:\LocalMachine\My','Cert:\LocalMachine\Root')) {
            if (Get-ChildItem $store -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }) { throw "项目证书未清理完成：$store" }
        }
    }

    Write-Host '旧安装已全部清理，开始全新安装。' -ForegroundColor Green
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1') -DataRoot $DataRoot -PackageRoot $PackageRoot
    exit $LASTEXITCODE
} catch {
    $failed = New-DatongDeploymentState -Stage 1 -StageName '完整重装清理' -Component 'CLEANUP' -Status 'STOP' -StartedAt $startedAt -Message $_.Exception.Message -NextAction '保持现场原状，把诊断ZIP和reports目录发送给技术人员。' -DiagnosticPath '正在生成诊断包...'
    try {
        & (Join-Path $PSScriptRoot 'collect-diagnostics.ps1') -DataRoot $DataRoot -PackageRoot $PackageRoot
        $diagnostic = Get-ChildItem $PackageRoot -Filter 'DatongMap-Diagnostics-*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($diagnostic) { $failed.DiagnosticPath = $diagnostic.FullName }
    } catch {
        $failed.DiagnosticPath = '诊断包生成也出现异常，请发送reports目录。'
    }
    $failed.UpdatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $failed
    exit 3
} finally {
    try { Stop-Transcript | Out-Null } catch { }
}
