[CmdletBinding()]
param(
    [string]$CertificatePath = '',
    [string]$ServerName = '',
    [string]$ServerIp = '',
    [int]$Port = 8012
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '请使用管理员PowerShell运行证书导入。' }
if ([string]::IsNullOrWhiteSpace($CertificatePath)) { $CertificatePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'client\datong-map.cer' }
if ([string]::IsNullOrWhiteSpace($ServerName)) { $ServerName = Read-Host '请输入服务端电脑名' }
if ([string]::IsNullOrWhiteSpace($ServerIp)) { $ServerIp = Read-Host '请输入服务器局域网IP，留空时使用电脑名访问' }
if (-not (Test-Path $CertificatePath)) { throw "证书文件不存在：$CertificatePath" }
Import-Certificate -FilePath $CertificatePath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
$hostName = if ([string]::IsNullOrWhiteSpace($ServerIp)) { $ServerName } else { $ServerIp }
$url = "https://$hostName`:$Port"
Write-Host "证书导入完成，请访问：$url" -ForegroundColor Green
Start-Process $url
