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

function Assert-Contains([string]$Expected, [string]$Actual, [string]$Message) {
    if (-not $Actual.Contains($Expected)) { throw "$Message expected to contain=[$Expected]" }
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
Assert-Equal 3306 (Get-DatongBundledMySqlPort $false 0) 'new bundled MySQL should use free port 3306'
Assert-Equal 3311 (Get-DatongBundledMySqlPort $true 0) 'new bundled MySQL should avoid occupied port 3306'
Assert-Equal 3312 (Get-DatongBundledMySqlPort $true 3312) 'existing project MySQL should retain its configured port'
$existingSettings = [pscustomobject]@{ OwnsMySqlService = $true; PackageRoot = 'C:\OldPackage'; MySqlPort = 3312; MySqlPassword = 'keep-me' }
$reusedSettings = Get-DatongReusableProjectSettings $existingSettings 'C:\DatongMap'
Assert-Equal 'C:\DatongMap' $reusedSettings.PackageRoot 'upgrade should point services at the new package root'
Assert-Equal 3312 $reusedSettings.MySqlPort 'upgrade should preserve the project-owned MySQL port'
Assert-Equal 'keep-me' $reusedSettings.MySqlPassword 'upgrade should preserve project credentials'
Assert-True ($null -eq (Get-DatongReusableProjectSettings ([pscustomobject]@{ OwnsMySqlService = $false }) 'C:\DatongMap')) 'unrelated MySQL settings should not be reused'
Assert-True (Test-DatongMySqlVersion '8.0.42') 'MySQL 8 should be supported'
Assert-False (Test-DatongMySqlVersion '5.7.44') 'MySQL 5 should be reported as incompatible'

$secret = New-DatongSecret 24
Assert-True ($secret -match '^[0-9a-f]{48}$') 'generated secret should be hexadecimal'
$redacted = Protect-DatongDiagnosticText "JWT_SECRET=topsecret`npath=C:\Datong" @('topsecret')
Assert-False ($redacted.Contains('topsecret')) 'diagnostics should redact supplied secrets'
Assert-True ($redacted.Contains('[REDACTED]')) 'diagnostics should show a redaction marker'
$jsonRedacted = Protect-DatongDiagnosticText '{"MySqlPassword":"db-secret","JwtSecret":"jwt-secret","safe":"visible"}'
Assert-False ($jsonRedacted.Contains('db-secret')) 'diagnostics should redact JSON MySQL passwords without settings'
Assert-False ($jsonRedacted.Contains('jwt-secret')) 'diagnostics should redact JSON JWT secrets without settings'
Assert-True ($jsonRedacted.Contains('visible')) 'diagnostics should retain non-secret JSON values'

$running = New-DatongDeploymentState -Stage 3 -StageName '安装项目独立MySQL' -Component 'MYSQL-SERVICE' -Status 'RUNNING' -StartedAt '2026-07-21 10:00:00'
Assert-Equal 'WIN-03-MYSQL-SERVICE' $running.ErrorCode 'deployment state should expose a stable component code'
Assert-Equal 'RUNNING' $running.Result 'running deployment state should expose its result'
$failed = New-DatongDeploymentState -Stage 4 -StageName '安装Windows服务' -Component 'MINIO' -Status 'STOP' -StartedAt '2026-07-21 10:00:00' -Message 'MinIO启动超时' -NextAction '发送诊断包' -DiagnosticPath 'C:\DatongMap\DatongMap-Diagnostics.zip'
Assert-Equal 'WIN-04-MINIO' $failed.ErrorCode 'failure state should identify its stage and component'
Assert-Equal 'MinIO启动超时' $failed.Message 'failure state should keep the user-facing reason'
$unknown = New-DatongDeploymentState -Stage 1 -StageName '环境检测' -Component 'UNKNOWN' -Status 'STOP'
Assert-Equal 'WIN-99-UNKNOWN' $unknown.ErrorCode 'unclassified failures should use the documented fallback code'

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

    $failureReport = New-DatongDeploymentState -Stage 3 -StageName '安装项目独立MySQL' -Component 'DATABASE' -Status 'STOP' -StartedAt '2026-07-21 10:00:00' -Message '业务数据库创建失败' -NextAction '把诊断包发送给技术人员' -DiagnosticPath 'C:\DatongMap\DatongMap-Diagnostics.zip'
    Write-DatongReport (Join-Path $reportRoot 'failure.json') (Join-Path $reportRoot 'failure.html') '一键部署结果' $failureReport
    $failureHtml = Get-Content (Join-Path $reportRoot 'failure.html') -Raw
    Assert-Contains '失败阶段：第 3 阶段 安装项目独立MySQL' $failureHtml 'failure report should show the failed stage'
    Assert-Contains '失败组件：DATABASE' $failureHtml 'failure report should show the failed component'
    Assert-Contains 'WIN-03-DATABASE' $failureHtml 'failure report should show the stable error code'
    Assert-Contains '业务数据库创建失败' $failureHtml 'failure report should show the plain-language reason'
    Assert-Contains 'DatongMap-Diagnostics.zip' $failureHtml 'failure report should show the diagnostics path'
    Assert-Contains '复制反馈信息' $failureHtml 'failure report should provide a copy action'

    $progressRoot = Join-Path $reportRoot 'progress'
    $progress = New-DatongDeploymentState -Stage 2 -StageName '生成配置' -Component 'CERTIFICATE' -Status 'RUNNING' -StartedAt '2026-07-21 10:00:00'
    Write-DatongDeploymentProgress -PackageRoot $progressRoot -State $progress
    Assert-True (Test-Path (Join-Path $progressRoot 'reports/deployment-status.json')) 'progress writer should persist machine-readable status'
    Assert-True (Test-Path (Join-Path $progressRoot 'reports/deployment-status.html')) 'progress writer should persist a field-friendly HTML page'
    $progressHtml = Get-Content (Join-Path $progressRoot 'reports/deployment-status.html') -Raw
    Assert-Contains 'WIN-02-CERTIFICATE' $progressHtml 'progress report should identify the active component'

    $diagnosticRoot = Join-Path $reportRoot 'diagnostic-package'
    New-Item -ItemType Directory -Force -Path (Join-Path $diagnosticRoot 'reports') | Out-Null
    Copy-Item (Join-Path $progressRoot 'reports/deployment-status.json') (Join-Path $diagnosticRoot 'reports/deployment-status.json')
    & (Join-Path $PSScriptRoot '..\scripts\collect-diagnostics.ps1') -DataRoot (Join-Path $diagnosticRoot 'data') -PackageRoot $diagnosticRoot
    $diagnosticZip = @(Get-ChildItem $diagnosticRoot -Filter 'DatongMap-Diagnostics-*.zip')
    Assert-Equal 1 $diagnosticZip.Count 'diagnostics should be generated before deployment settings exist'
} finally { Remove-Item $reportRoot -Recurse -Force -ErrorAction SilentlyContinue }

$entryContent = Get-Content (Join-Path $PSScriptRoot '..\开始部署.cmd') -Raw -Encoding UTF8
Assert-Contains 'scripts\install.ps1' $entryContent 'one-click entry should invoke the unified installer'
Assert-False ($entryContent -match '(?im)^\s*choice\s') 'one-click entry should not pause between stages'
$installerContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\install.ps1') -Raw -Encoding UTF8
foreach ($stageScript in @('01-check-environment.ps1','02-configure.ps1','03-prepare-database.ps1','04-install-services.ps1','05-verify.ps1')) {
    Assert-Contains $stageScript $installerContent "unified installer should run $stageScript"
}
Assert-Contains 'UseBundledMySql = $true' $installerContent 'unified installer should always install project-owned MySQL'
Assert-Contains 'NonInteractive = $true' $installerContent 'unified installer should use field-friendly defaults'

$buildContent = Get-Content (Join-Path $PSScriptRoot '..\build-package.ps1') -Raw -Encoding UTF8
foreach ($packageFile in @('Windows一键部署教程.md','Windows一键部署教程.html','package-manifest.json','版本信息.txt')) {
    Assert-Contains $packageFile $buildContent "offline package should include $packageFile"
}
Assert-Contains "zipPath + '.sha256'" $buildContent 'package builder should emit a ZIP SHA-256 sidecar'
Assert-Contains "Compress-Archive -Path (Join-Path `$stageRoot '*')" $buildContent 'ZIP should extract directly into C:\DatongMap without a nested folder'
Assert-True (Test-Path (Join-Path $PSScriptRoot '..\Windows一键部署教程.md')) 'field tutorial Markdown should be tracked'
Assert-True (Test-Path (Join-Path $PSScriptRoot '..\Windows一键部署教程.html')) 'field tutorial HTML should be tracked'

Write-Host 'DatongDeploy tests passed.' -ForegroundColor Green
