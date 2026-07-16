[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$CertificatePath,
    [string]$ServerName = $env:COMPUTERNAME,
    [int]$Port = 8012
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '请使用管理员PowerShell运行证书导入。' }
if (-not (Test-Path $CertificatePath)) { throw "证书文件不存在：$CertificatePath" }
Import-Certificate -FilePath $CertificatePath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Write-Host "证书导入完成，请访问：https://$ServerName`:$Port" -ForegroundColor Green
