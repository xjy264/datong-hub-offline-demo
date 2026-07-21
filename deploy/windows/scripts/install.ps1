[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [string]$PackageRoot = ''
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
if ([string]::IsNullOrWhiteSpace($PackageRoot)) { $PackageRoot = Resolve-DatongPackageRoot $PSScriptRoot }
$reports = Join-Path $PackageRoot 'reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null
$logPath = Join-Path $reports 'deployment.log'
$startedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$completedStages = @()
$currentStage = 1
$currentStageName = '环境与离线包检测'

function Invoke-DeploymentStage {
    param([int]$Number, [string]$Name, [string]$ScriptName, [hashtable]$Arguments = @{})
    $script:currentStage = $Number
    $script:currentStageName = $Name
    $state = New-DatongDeploymentState -Stage $Number -StageName $Name -Component 'START' -Status 'RUNNING' -StartedAt $startedAt -Stages $completedStages
    Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $state
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & (Join-Path $PSScriptRoot $ScriptName) @Arguments
    $watch.Stop()
    $script:completedStages += [pscustomobject]@{ Stage = $Number; Name = $Name; Result = 'PASS'; DurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 1) }
    $state = New-DatongDeploymentState -Stage $Number -StageName $Name -Component 'COMPLETE' -Status 'PASS' -StartedAt $startedAt -Message ("本阶段完成，用时 {0:N1} 秒" -f $watch.Elapsed.TotalSeconds) -Stages $completedStages
    Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $state
}

if (Test-Path $logPath) { Remove-Item $logPath -Force }
Start-Transcript -Path $logPath -Force | Out-Null
try {
    if (-not (Test-DatongAdministrator)) { throw '请在Windows管理员权限窗口中运行一键部署。' }
    Invoke-DeploymentStage 1 '环境与离线包检测' '01-check-environment.ps1'
    Invoke-DeploymentStage 2 '自动生成配置与证书' '02-configure.ps1' @{ DataRoot = $DataRoot; UseBundledMySql = $true; NonInteractive = $true }
    Invoke-DeploymentStage 3 '安装项目独立MySQL' '03-prepare-database.ps1' @{ DataRoot = $DataRoot }
    Invoke-DeploymentStage 4 '安装MinIO与后端服务' '04-install-services.ps1' @{ DataRoot = $DataRoot }
    Invoke-DeploymentStage 5 '服务与页面验收' '05-verify.ps1' @{ DataRoot = $DataRoot }
    $success = New-DatongDeploymentState -Stage 5 -StageName '服务与页面验收' -Component 'COMPLETE' -Status 'PASS' -StartedAt $startedAt -Message '全部五个阶段已完成。' -NextAction '给客户端复制client目录并运行客户端证书安装.cmd。' -Stages $completedStages
    Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $success
    exit 0
} catch {
    $current = $null
    $statusPath = Join-Path $reports 'deployment-status.json'
    if (Test-Path $statusPath) { $current = Read-DatongJson $statusPath }
    $component = if ($current -and [int]$current.Stage -eq $currentStage) { [string]$current.Component } else { 'UNKNOWN' }
    if ($component -in @('START','COMPLETE','')) { $component = 'UNKNOWN' }
    $message = $_.Exception.Message
    $failed = New-DatongDeploymentState -Stage $currentStage -StageName $currentStageName -Component $component -Status 'STOP' -StartedAt $startedAt -Message $message -NextAction '保持现场原状，把自动生成的诊断ZIP发送给技术人员。' -DiagnosticPath '正在生成诊断包...' -Stages $completedStages
    Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $failed
    try {
        & (Join-Path $PSScriptRoot 'collect-diagnostics.ps1') -DataRoot $DataRoot -PackageRoot $PackageRoot
        $diagnostic = Get-ChildItem $PackageRoot -Filter 'DatongMap-Diagnostics-*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($diagnostic) { $failed.DiagnosticPath = $diagnostic.FullName }
    } catch {
        $failed.DiagnosticPath = '诊断包生成也出现异常，请发送reports目录。'
    }
    $failed.UpdatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-DatongDeploymentProgress -PackageRoot $PackageRoot -State $failed
    exit 2
} finally {
    try { Stop-Transcript | Out-Null } catch { }
}
