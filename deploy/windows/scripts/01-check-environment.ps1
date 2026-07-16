[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$packageRoot = Resolve-DatongPackageRoot $PSScriptRoot
$reports = Join-Path $packageRoot 'reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null

Write-DatongStage '阶段01：只读环境检测'
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$ports = @(8012, 3306, 3311, 9011, 9012 | ForEach-Object {
    $owner = Get-DatongPortOwner $_
    if ($owner) { $owner } else { [pscustomobject]@{ Port = $_; Address = ''; ProcessId = 0; ProcessName = '空闲' } }
})
$mysql = @(Get-DatongMySqlCandidates)
$port3306 = @($ports | Where-Object { $_.Port -eq 3306 -and $_.ProcessId -ne 0 }).Count -gt 0
$mysqlPlan = Select-DatongMySqlPlan $mysql $port3306
$blockers = @()
$warnings = @()

if (-not [Environment]::Is64BitOperatingSystem) { $blockers += '操作系统需要x64架构。' }
if (($computer.TotalPhysicalMemory / 1GB) -lt 4) { $blockers += '物理内存低于4GB。' }
elseif (($computer.TotalPhysicalMemory / 1GB) -lt 8) { $warnings += '物理内存低于推荐的8GB。' }
if (($drive.FreeSpace / 1GB) -lt 20) { $blockers += '系统盘剩余空间低于20GB。' }
$businessPort = $ports | Where-Object { $_.Port -eq 8012 -and $_.ProcessId -ne 0 }
if ($businessPort -and $businessPort.ProcessName -notmatch 'java|Datong') {
    $blockers += "8012端口已被进程 $($businessPort.ProcessName) 占用。"
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
foreach ($requiredRuntime in @('Java','MySql','Minio','MinioClient','WinSW','VisualCppRuntimeInstaller')) {
    if (-not $runtime[$requiredRuntime]) { $blockers += "完整离线包缺少运行组件：$requiredRuntime。" }
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
if ($blockers.Count -gt 0) { exit 2 }
