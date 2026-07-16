[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [string]$ServerName = $env:COMPUTERNAME,
    [int]$MySqlCandidateId = 0,
    [string]$PfxPath = '',
    [string]$BackupRoot = '',
    [switch]$UseBundledMySql,
    [switch]$AcceptRecommended,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$packageRoot = Resolve-DatongPackageRoot $PSScriptRoot
$reportPath = Join-Path $packageRoot 'reports\environment-report.json'

Write-DatongStage '阶段02：确认部署配置'
if (-not (Test-DatongAdministrator)) { throw '请使用管理员PowerShell运行本阶段。' }
$report = Read-DatongJson $reportPath
if ($report.Result -ne 'PASS') { throw '环境报告存在红色停止项，请先把报告交给远程技术人员。' }

$compatible = @($report.MySqlCandidates | Where-Object { $_.Compatible })
$mode = 'Bundled'
$selected = $null
if ($UseBundledMySql) {
    $mode = 'Bundled'
} elseif ($MySqlCandidateId -gt 0) {
    $selected = $compatible | Where-Object { $_.Id -eq $MySqlCandidateId } | Select-Object -First 1
    if (-not $selected) { throw "MySQL编号 $MySqlCandidateId 不在兼容列表中。" }
    $mode = 'Reuse'
} elseif ($compatible.Count -eq 1) {
    $selected = $compatible[0]
    $mode = 'Reuse'
    Write-Host "推荐复用MySQL服务：$($selected.Name)，版本 $($selected.Version)，端口 $($selected.Port)" -ForegroundColor Green
    $answer = if ($AcceptRecommended -or $NonInteractive) { '' } else { Read-Host '按Enter接受；输入B使用项目独立MySQL' }
    if ($answer.ToUpperInvariant() -eq 'B') { $mode = 'Bundled'; $selected = $null }
} elseif ($compatible.Count -gt 1) {
    if ($NonInteractive) { throw '检测到多个兼容MySQL实例，自动化模式需要指定-MySqlCandidateId。' }
    $compatible | Format-Table Id, Name, State, Version, Port -AutoSize
    $choice = [int](Read-Host '请输入要复用的MySQL编号；输入0使用项目独立MySQL')
    if ($choice -gt 0) {
        $selected = $compatible | Where-Object { $_.Id -eq $choice } | Select-Object -First 1
        if (-not $selected) { throw '输入的MySQL编号不在兼容列表中。' }
        $mode = 'Reuse'
    }
}

$mysqlPort = if ($mode -eq 'Reuse') { [int]$selected.Port } else {
    if (Get-DatongPortOwner 3306) { 3311 } else { 3306 }
}
$fixedDrives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID -ne $env:SystemDrive } | Sort-Object FreeSpace -Descending)
$defaultBackupRoot = if ($fixedDrives.Count -gt 0) { "$($fixedDrives[0].DeviceID)\DatongMapBackups" } else { Join-Path $DataRoot 'backups' }
$backupInput = if ($BackupRoot) { $BackupRoot } elseif ($NonInteractive) { $defaultBackupRoot } else { Read-Host "请输入备份目录，按Enter使用 $defaultBackupRoot" }
$backupRoot = if ([string]::IsNullOrWhiteSpace($backupInput)) { $defaultBackupRoot } else { $backupInput }
$configDir = Join-Path $DataRoot 'config'
$logsDir = Join-Path $DataRoot 'logs'
$certDir = Join-Path $DataRoot 'certificate'
New-Item -ItemType Directory -Force -Path $configDir, $logsDir, $certDir | Out-Null

$certPassword = New-DatongSecret 24
$serverPfx = Join-Path $certDir 'datong-map.pfx'
$clientCer = Join-Path $certDir 'datong-map.cer'
if ($PfxPath) {
    if (-not (Test-Path $PfxPath)) { throw "证书文件不存在：$PfxPath" }
    Copy-Item $PfxPath $serverPfx -Force
    $securePfxPassword = Read-Host '请输入PFX证书密码' -AsSecureString
    $certPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePfxPassword))
} else {
    Write-Host "正在为 $ServerName 生成局域网证书。"
    $ipv4 = @(Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^127\.' } | Select-Object -ExpandProperty IPAddress -Unique)
    $san = @("dns=$ServerName") + @($ipv4 | ForEach-Object { "ipaddress=$_" })
    $sanExtension = '2.5.29.17={text}' + ($san -join '&')
    $certificate = New-SelfSignedCertificate -Subject "CN=$ServerName" -TextExtension @($sanExtension) -CertStoreLocation 'Cert:\LocalMachine\My' -KeyExportPolicy Exportable -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(5)
    $securePfxPassword = ConvertTo-SecureString $certPassword -AsPlainText -Force
    Export-PfxCertificate -Cert $certificate -FilePath $serverPfx -Password $securePfxPassword | Out-Null
    Export-Certificate -Cert $certificate -FilePath $clientCer | Out-Null
}

$settings = [ordered]@{
    PackageRoot = $packageRoot
    DataRoot = $DataRoot
    ServerName = $ServerName
    ServerPort = 8012
    MySqlMode = $mode
    MySqlServiceName = if ($selected) { $selected.Name } else { 'DatongMapMySQL' }
    MySqlExecutable = if ($selected) { $selected.Executable } else { Join-Path $packageRoot 'runtime\mysql\bin\mysqld.exe' }
    MySqlPort = $mysqlPort
    MySqlDatabase = 'datong_map'
    MySqlUser = 'datong_map_' + (New-DatongSecret 4)
    MySqlPassword = New-DatongSecret 24
    OwnsMySqlService = ($mode -eq 'Bundled')
    MinioAccessKey = 'datong-' + (New-DatongSecret 6)
    MinioSecretKey = New-DatongSecret 24
    JwtSecret = New-DatongSecret 48
    CertificatePath = $serverPfx
    CertificatePassword = $certPassword
    ClientCertificatePath = $clientCer
    BackupRoot = $backupRoot
    CreatedAt = (Get-Date).ToString('o')
}
$settingsPath = Join-Path $configDir 'deployment-settings.json'
Save-DatongJson $settingsPath $settings
Set-DatongPrivateAcl $configDir
Set-Content (Join-Path $configDir 'stage-02.complete') (Get-Date).ToString('o') -Encoding ASCII
Write-Host "配置已保存：$settingsPath" -ForegroundColor Green
Write-Host '下一步：运行 scripts\03-prepare-database.ps1'
