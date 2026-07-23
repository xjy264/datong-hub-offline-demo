[CmdletBinding()]
param(
    [string]$CertificatePath = '',
    [string]$ServerIp = '',
    [string]$AccessHostName = 'datong-hub-offline',
    [int]$Port = 8012
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatongDeploy.psm1') -Force
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '请使用管理员PowerShell运行证书导入。' }
if ([string]::IsNullOrWhiteSpace($CertificatePath)) { $CertificatePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'client\datong-map.cer' }
if ([string]::IsNullOrWhiteSpace($ServerIp)) { $ServerIp = Read-Host '请输入服务器局域网IPv4地址' }
$parsedIp = $null
if (-not [Net.IPAddress]::TryParse($ServerIp, [ref]$parsedIp) -or $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw "服务器IP格式不正确：$ServerIp" }
if (-not (Test-Path $CertificatePath)) { throw "证书文件不存在：$CertificatePath" }
Import-Certificate -FilePath $CertificatePath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Set-DatongHostsEntry -Address $ServerIp -HostName $AccessHostName
$url = "https://$AccessHostName`:$Port"
Write-Host "证书导入完成，请访问：$url" -ForegroundColor Green
Start-Process $url
