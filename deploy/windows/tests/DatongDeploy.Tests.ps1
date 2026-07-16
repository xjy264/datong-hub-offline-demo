$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\scripts\DatongDeploy.psm1') -Force

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) { throw "$Message expected=[$Expected] actual=[$Actual]" }
}

function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw $Message }
}

function Assert-False([bool]$Value, [string]$Message) {
    if ($Value) { throw $Message }
}

$mysql8 = [pscustomobject]@{ Id = 1; Name = 'MySQL80'; Version = '8.0.42'; Compatible = $true; Port = 3306 }
$mysql8b = [pscustomobject]@{ Id = 2; Name = 'MySQL82'; Version = '8.2.0'; Compatible = $true; Port = 3307 }
$mysql57 = [pscustomobject]@{ Id = 3; Name = 'MySQL57'; Version = '5.7.44'; Compatible = $false; Port = 3306 }
$maria = [pscustomobject]@{ Id = 4; Name = 'MariaDB'; Version = '10.11.8'; Compatible = $false; Port = 3306 }

Assert-Equal 'Reuse' (Select-DatongMySqlPlan @($mysql8) $false).Action 'single MySQL 8 service should be reused'
Assert-Equal 'Select' (Select-DatongMySqlPlan @($mysql8, $mysql8b) $false).Action 'multiple compatible services require selection'
Assert-Equal 'Bundled' (Select-DatongMySqlPlan @($mysql57) $false).Action 'old MySQL service should be preserved'
Assert-Equal 'Bundled' (Select-DatongMySqlPlan @($maria) $false).Action 'MariaDB service should be preserved'
Assert-Equal 3311 (Select-DatongMySqlPlan @() $true).Port 'bundled MySQL should avoid occupied port 3306'
Assert-True (Test-DatongMySqlVersion '8.0.42') 'MySQL 8 should be supported'
Assert-False (Test-DatongMySqlVersion '5.7.44') 'MySQL 5 should be reported as incompatible'

$secret = New-DatongSecret 24
Assert-True ($secret -match '^[0-9a-f]{48}$') 'generated secret should be hexadecimal'
$redacted = Protect-DatongDiagnosticText "JWT_SECRET=topsecret`npath=C:\Datong" @('topsecret')
Assert-False ($redacted.Contains('topsecret')) 'diagnostics should redact supplied secrets'
Assert-True ($redacted.Contains('[REDACTED]')) 'diagnostics should show a redaction marker'

Assert-Equal 'Initialize' (Get-DatongDatabaseDecision $false @()).Action 'missing database should be initialized'
Assert-Equal 'Initialize' (Get-DatongDatabaseDecision $true @()).Action 'empty database should be initialized'
Assert-Equal 'Upgrade' (Get-DatongDatabaseDecision $true @('flyway_schema_history','app_user')).Action 'known project database should be upgraded'
Assert-Equal 'Stop' (Get-DatongDatabaseDecision $true @('unrelated_table')).Action 'unknown existing database should stop deployment'
Assert-Equal 2 @(Get-DatongManagedServices $false).Count 'reused MySQL should stay outside lifecycle management'
Assert-Equal 3 @(Get-DatongManagedServices $true).Count 'bundled MySQL should be project managed'

$reportRoot = Join-Path ([IO.Path]::GetTempPath()) ('datong-report-test-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
    $report = [ordered]@{ Result = 'PASS'; Warnings = @('sample warning'); Blockers = @() }
    Write-DatongReport (Join-Path $reportRoot 'report.json') (Join-Path $reportRoot 'report.html') 'test report' $report
    $reportHtml = Get-Content (Join-Path $reportRoot 'report.html') -Raw
    Assert-True ($reportHtml.Contains('检测结论：PASS')) 'HTML report should show the result'
    Assert-True ($reportHtml.Contains('sample warning')) 'HTML report should show warnings'
} finally { Remove-Item $reportRoot -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'DatongDeploy tests passed.' -ForegroundColor Green
