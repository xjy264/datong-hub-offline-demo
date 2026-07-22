[CmdletBinding()]
param(
    [string]$DataRoot = 'C:\ProgramData\DatongMap',
    [string]$PackageRoot = ''
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settingsPath = Join-Path $DataRoot 'config\deployment-settings.json'
$settings = if (Test-Path $settingsPath) { Read-DatongJson $settingsPath } else { $null }
if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $PackageRoot = if ($settings) { $settings.PackageRoot } else { Resolve-DatongPackageRoot $PSScriptRoot }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$work = Join-Path ([IO.Path]::GetTempPath()) "DatongMap-Diagnostics-$stamp-$([guid]::NewGuid().ToString('N'))"
$zip = Join-Path $PackageRoot "DatongMap-Diagnostics-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$secrets = if ($settings) { @($settings.MySqlPassword, $settings.MinioAccessKey, $settings.MinioSecretKey, $settings.JwtSecret, $settings.CertificatePassword) } else { @() }

function Write-SafeText([string]$Target, [string]$Text) {
    $directory = Split-Path $Target -Parent
    if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    Protect-DatongDiagnosticText $Text $secrets | Set-Content $Target -Encoding UTF8
}

try {
    if ($settings) {
        Write-SafeText (Join-Path $work 'deployment-settings-redacted.json') (Get-Content $settingsPath -Raw -Encoding UTF8)
    } else {
        Write-SafeText (Join-Path $work 'deployment-settings-redacted.json') '{"status":"配置阶段尚未完成"}'
    }

    if (Get-Command Get-ComputerInfo -ErrorAction SilentlyContinue) {
        Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture, CsTotalPhysicalMemory | Format-List | Out-File (Join-Path $work 'computer.txt') -Encoding UTF8
    } elseif (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        $os = Get-CimInstance Win32_OperatingSystem
        $computer = Get-CimInstance Win32_ComputerSystem
        $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
        [pscustomobject]@{ Caption = $os.Caption; Version = $os.Version; Architecture = $os.OSArchitecture; TotalPhysicalMemory = $computer.TotalPhysicalMemory; SystemDriveFreeSpace = $drive.FreeSpace; PowerShellVersion = $PSVersionTable.PSVersion.ToString() } | Format-List | Out-File (Join-Path $work 'computer.txt') -Encoding UTF8
    } else {
        Write-SafeText (Join-Path $work 'computer.txt') ([Environment]::OSVersion.VersionString)
    }

    $mysqlService = if ($settings) { [string]$settings.MySqlServiceName } else { 'DatongMapMySQL' }
    if (Get-Command Get-Service -ErrorAction SilentlyContinue) {
        Get-Service $mysqlService, 'DatongMapMinIO', 'DatongMapBackend' -ErrorAction SilentlyContinue | Format-List * | Out-File (Join-Path $work 'services.txt') -Encoding UTF8
    } else {
        Write-SafeText (Join-Path $work 'services.txt') '当前系统不支持Windows服务查询。'
    }

    $mysqlPort = if ($settings) { [int]$settings.MySqlPort } else { 0 }
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        $ports = @(8012, 9011, 9012, 3306, 3311)
        if ($mysqlPort -gt 0) { $ports += $mysqlPort }
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in $ports } | Format-Table -AutoSize | Out-File (Join-Path $work 'ports.txt') -Encoding UTF8
    } else {
        Write-SafeText (Join-Path $work 'ports.txt') '当前系统不支持Windows端口查询。'
    }

    if ($env:OS -eq 'Windows_NT') {
        & schtasks.exe /Query /TN 'DatongMap-DailyBackup' /V /FO LIST 2>&1 | Out-File (Join-Path $work 'scheduled-task.txt') -Encoding UTF8
    }
    if (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue) {
        Get-NetFirewallRule -DisplayName 'DatongMap-HTTPS-8012' -ErrorAction SilentlyContinue | Format-List * | Out-File (Join-Path $work 'firewall.txt') -Encoding UTF8
    }
    $certificateThumbprint = if ($settings -and $settings.PSObject.Properties['CertificateThumbprint']) { [string]$settings.CertificateThumbprint } else { '' }
    Write-SafeText (Join-Path $work 'certificate.txt') ("CertificateThumbprint=" + $certificateThumbprint)

    $reports = Join-Path $PackageRoot 'reports'
    if (Test-Path $reports) {
        Get-ChildItem $reports -File | ForEach-Object {
            Write-SafeText (Join-Path (Join-Path $work 'reports') $_.Name) (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue)
        }
    }

    $logs = Join-Path $DataRoot 'logs'
    if (Test-Path $logs) {
        Get-ChildItem $logs -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($logs.Length).TrimStart('\')
            $target = Join-Path (Join-Path $work 'logs') $relative
            Write-SafeText $target ((Get-Content $_.FullName -Tail 500 -ErrorAction SilentlyContinue) -join "`r`n")
        }
    }

    New-DatongZip -SourceDirectory $work -DestinationPath $zip
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "诊断包已生成：$zip" -ForegroundColor Green
