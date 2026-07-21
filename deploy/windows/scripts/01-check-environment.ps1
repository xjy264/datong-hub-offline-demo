[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$packageRoot = Resolve-DatongPackageRoot $PSScriptRoot
$reports = Join-Path $packageRoot 'reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null
$startedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

Write-DatongStage '阶段01：只读环境检测'
Write-DatongDeploymentProgress -PackageRoot $packageRoot -State (New-DatongDeploymentState -Stage 1 -StageName '环境与离线包检测' -Component 'OS' -Status 'RUNNING' -StartedAt $startedAt)
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
Write-DatongDeploymentProgress -PackageRoot $packageRoot -State (New-DatongDeploymentState -Stage 1 -StageName '环境与离线包检测' -Component 'PORT' -Status 'RUNNING' -StartedAt $startedAt)
$ports = @(8012, 3306, 3311, 9011, 9012 | ForEach-Object {
    $owner = Get-DatongPortOwner $_
    if ($owner) { $owner } else { [pscustomobject]@{ Port = $_; Address = ''; ProcessId = 0; ProcessName = '空闲' } }
})
$mysql = @(Get-DatongMySqlCandidates)
$port3306 = @($ports | Where-Object { $_.Port -eq 3306 -and $_.ProcessId -ne 0 }).Count -gt 0
$existingProjectPort = 0
$existingSettingsPath = 'C:\ProgramData\DatongMap\config\deployment-settings.json'
if (Test-Path $existingSettingsPath) {
    try {
        $existingSettings = Read-DatongJson $existingSettingsPath
        if ($existingSettings.OwnsMySqlService) { $existingProjectPort = [int]$existingSettings.MySqlPort }
    } catch { $existingProjectPort = 0 }
}
$mysqlPlan = [pscustomobject]@{
    Action = $(if ($existingProjectPort -gt 0) { 'UpgradeProjectMySql' } else { 'InstallProjectMySql' })
    Port = Get-DatongBundledMySqlPort $port3306 $existingProjectPort
    Note = '服务器原有MySQL保持原状；一键部署仅管理DatongMapMySQL。'
}
$blockers = @()
$warnings = @()
$stopComponent = ''

if (-not [Environment]::Is64BitOperatingSystem) { $blockers += '操作系统需要x64架构。'; if (-not $stopComponent) { $stopComponent = 'OS' } }
if (($computer.TotalPhysicalMemory / 1GB) -lt 4) { $blockers += '物理内存低于4GB。'; if (-not $stopComponent) { $stopComponent = 'MEMORY' } }
elseif (($computer.TotalPhysicalMemory / 1GB) -lt 8) { $warnings += '物理内存低于推荐的8GB。' }
if (($drive.FreeSpace / 1GB) -lt 20) { $blockers += '系统盘剩余空间低于20GB。'; if (-not $stopComponent) { $stopComponent = 'DISK' } }
$businessPort = $ports | Where-Object { $_.Port -eq 8012 -and $_.ProcessId -ne 0 }
if ($businessPort -and $businessPort.ProcessName -notmatch 'java|Datong') {
    $blockers += "8012端口已被进程 $($businessPort.ProcessName) 占用。"
    if (-not $stopComponent) { $stopComponent = 'PORT' }
}
if (-not (Test-DatongAdministrator)) { $warnings += '当前窗口不是管理员PowerShell，后续配置阶段需要管理员权限。' }

$runtime = [ordered]@{
    Java = Test-Path (Join-Path $packageRoot 'runtime\java\bin\java.exe')
    MySql = Test-Path (Join-Path $packageRoot 'runtime\mysql\bin\mysqld.exe')
    Minio = Test-Path (Join-Path $packageRoot 'runtime\minio\minio.exe')
    MinioClient = Test-Path (Join-Path $packageRoot 'runtime\minio\mc.exe')
    WinSW = Test-Path (Join-Path $packageRoot 'runtime\winsw\WinSW-x64.exe')
    VisualCppRuntimeInstaller = Test-Path (Join-Path $packageRoot 'runtime\prerequisites\vc_redist.x64.exe')
}
Write-DatongDeploymentProgress -PackageRoot $packageRoot -State (New-DatongDeploymentState -Stage 1 -StageName '环境与离线包检测' -Component 'RUNTIME' -Status 'RUNNING' -StartedAt $startedAt)
foreach ($requiredRuntime in @('Java','MySql','Minio','MinioClient','WinSW','VisualCppRuntimeInstaller')) {
    if (-not $runtime[$requiredRuntime]) { $blockers += "完整离线包缺少运行组件：$requiredRuntime。"; if (-not $stopComponent) { $stopComponent = 'RUNTIME' } }
}

$report = [ordered]@{
    GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    ReadOnlyCheck = $true
    ComputerName = $env:COMPUTERNAME
    OperatingSystem = $os.Caption
    Version = $os.Version
    Architecture = $os.OSArchitecture
    MemoryGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    SystemDriveFreeGB = [math]::Round($drive.FreeSpace / 1GB, 1)
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    Administrator = Test-DatongAdministrator
    Ports = $ports
    MySqlCandidates = $mysql
    MySqlRecommendation = $mysqlPlan
    PackageRuntime = $runtime
    Warnings = $warnings
    Blockers = $blockers
    Result = $(if ($blockers.Count -eq 0) { 'PASS' } else { 'STOP' })
    NextAction = $(if ($blockers.Count -eq 0) { '返回部署向导，确认后进入阶段02。' } else { '停止部署，把reports目录发送给远程技术人员。' })
}

$jsonPath = Join-Path $reports 'environment-report.json'
$htmlPath = Join-Path $reports 'environment-report.html'
Write-DatongReport $jsonPath $htmlPath '大同示意图 Windows 环境检测报告' $report
Write-Host "检测结果：$($report.Result)" -ForegroundColor $(if ($blockers.Count -eq 0) { 'Green' } else { 'Red' })
Write-Host "报告：$htmlPath"
if ($blockers.Count -gt 0) {
    Write-DatongDeploymentProgress -PackageRoot $packageRoot -State (New-DatongDeploymentState -Stage 1 -StageName '环境与离线包检测' -Component $stopComponent -Status 'RUNNING' -StartedAt $startedAt)
    throw ($blockers -join '；')
}
