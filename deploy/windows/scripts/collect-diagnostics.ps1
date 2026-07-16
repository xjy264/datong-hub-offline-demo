[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$settingsPath = Join-Path $DataRoot 'config\deployment-settings.json'
$settings = Read-DatongJson $settingsPath
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$work = Join-Path $env:TEMP "DatongMap-Diagnostics-$stamp"
$zip = Join-Path $settings.PackageRoot "DatongMap-Diagnostics-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$secrets = @($settings.MySqlPassword, $settings.MinioAccessKey, $settings.MinioSecretKey, $settings.JwtSecret, $settings.CertificatePassword)
$safeSettings = Protect-DatongDiagnosticText (Get-Content $settingsPath -Raw) $secrets
$safeSettings | Set-Content (Join-Path $work 'deployment-settings-redacted.json') -Encoding UTF8
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture, CsTotalPhysicalMemory | Format-List | Out-File (Join-Path $work 'computer.txt') -Encoding UTF8
Get-Service $settings.MySqlServiceName, 'DatongMapMinIO', 'DatongMapBackend' -ErrorAction SilentlyContinue | Format-List * | Out-File (Join-Path $work 'services.txt') -Encoding UTF8
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in @(8012,9011,9012,[int]$settings.MySqlPort) } | Format-Table -AutoSize | Out-File (Join-Path $work 'ports.txt') -Encoding UTF8
$reports = Join-Path $settings.PackageRoot 'reports'
if (Test-Path $reports) { Copy-Item $reports (Join-Path $work 'reports') -Recurse }
$logs = Join-Path $DataRoot 'logs'
if (Test-Path $logs) {
    Get-ChildItem $logs -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($logs.Length).TrimStart('\')
        $target = Join-Path (Join-Path $work 'logs') $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        $safeLog = Protect-DatongDiagnosticText ((Get-Content $_.FullName -Tail 500 -ErrorAction SilentlyContinue) -join "`r`n") $secrets
        $safeLog | Set-Content $target -Encoding UTF8
    }
}
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
Remove-Item $work -Recurse -Force
Write-Host "诊断包已生成：$zip" -ForegroundColor Green
