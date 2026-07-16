[CmdletBinding()]
param([string]$DataRoot = 'C:\ProgramData\DatongMap')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'stop.ps1') -DataRoot $DataRoot
& (Join-Path $PSScriptRoot 'start.ps1') -DataRoot $DataRoot
