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
Assert-Equal 'C:\DatongMap\runtime\mysql\bin\mysqld.exe' $reusedSettings.MySqlExecutable 'upgrade should point the managed MySQL executable at the new package root'
Assert-Equal 3312 $reusedSettings.MySqlPort 'upgrade should preserve the project-owned MySQL port'
Assert-Equal 'keep-me' $reusedSettings.MySqlPassword 'upgrade should preserve project credentials'
Assert-True ($null -eq (Get-DatongReusableProjectSettings ([pscustomobject]@{ OwnsMySqlService = $false }) 'C:\DatongMap')) 'unrelated MySQL settings should not be reused'
Assert-True (Test-DatongMySqlVersion '8.0.42') 'MySQL 8 should be supported'
Assert-False (Test-DatongMySqlVersion '5.7.44') 'MySQL 5 should be reported as incompatible'

Assert-True (Test-DatongWindowsCompatibility ([version]'6.3')) 'Windows 6.3 should be the supported lower boundary'
Assert-True (Test-DatongWindowsCompatibility ([version]'10.0')) 'newer Windows versions should remain supported'
Assert-False (Test-DatongWindowsCompatibility ([version]'6.2')) 'Windows Server 2012 should be rejected'
Assert-True (Test-DatongPowerShellCompatibility ([version]'4.0')) 'PowerShell 4 should be the supported lower boundary'
Assert-False (Test-DatongPowerShellCompatibility ([version]'3.0')) 'PowerShell 3 should be rejected'

$originalSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
    Enable-DatongTls12
    Assert-True (([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) -eq [Net.SecurityProtocolType]::Tls12) 'health checks should explicitly enable TLS 1.2'
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
}

$probeExecutable = (Get-Process -Id $PID).Path
$probe = Test-DatongExecutableProbe -Path $probeExecutable -Arguments @('-NoProfile','-Command',"'Temurin 17.0.8.1'") -ExpectedPattern '17\.0\.8\.1'
Assert-True $probe.Exists 'runtime probe should confirm that the executable exists'
Assert-True $probe.Passed 'runtime probe should execute the component and validate its output'
$badProbe = Test-DatongExecutableProbe -Path $probeExecutable -Arguments @('-NoProfile','-Command',"'unexpected-version'") -ExpectedPattern '17\.0\.8\.1'
Assert-False $badProbe.Passed 'runtime probe should reject an unexpected component version'
$stderrProbe = Test-DatongExecutableProbe -Path $probeExecutable -Arguments @('-NoProfile','-Command',"[Console]::Error.WriteLine('Temurin 17.0.8.1'); exit 0") -ExpectedPattern '17\.0\.8\.1'
Assert-True $stderrProbe.Passed 'runtime probe should accept a successful executable that reports its version on stderr'

$criticalDisk = Get-DatongDiskAssessment 4.9
Assert-False $criticalDisk.Passed 'less than 5GB on the system drive should stop deployment'
$lowDisk = Get-DatongDiskAssessment 16.7
Assert-True $lowDisk.Passed 'a system drive with enough installation space should continue deployment'
Assert-True $lowDisk.Warning 'less than the recommended 20GB should be reported as a warning'
$healthyDisk = Get-DatongDiskAssessment 25
Assert-True $healthyDisk.Passed 'a system drive above the recommendation should pass'
Assert-False $healthyDisk.Warning 'a healthy system drive should not emit a low-space warning'

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

    $partialDiagnosticRoot = Join-Path $reportRoot 'partial-diagnostic-package'
    $partialDataRoot = Join-Path $partialDiagnosticRoot 'data'
    New-Item -ItemType Directory -Force -Path (Join-Path $partialDataRoot 'config') | Out-Null
    Set-Content (Join-Path $partialDataRoot 'config/deployment-settings.json') '{}' -Encoding UTF8
    & (Join-Path $PSScriptRoot '..\scripts\collect-diagnostics.ps1') -DataRoot $partialDataRoot -PackageRoot $partialDiagnosticRoot
    Assert-Equal 1 @(Get-ChildItem $partialDiagnosticRoot -Filter 'DatongMap-Diagnostics-*.zip').Count 'diagnostics should tolerate partially written settings'

    $zipSource = Join-Path $reportRoot 'zip-source'
    New-Item -ItemType Directory -Force -Path $zipSource | Out-Null
    Set-Content (Join-Path $zipSource 'probe.txt') 'zip-ok' -Encoding ASCII
    $zipTarget = Join-Path $reportRoot 'probe.zip'
    New-DatongZip -SourceDirectory $zipSource -DestinationPath $zipTarget
    Assert-True (Test-Path $zipTarget) '.NET ZipFile helper should create a ZIP on PowerShell 4'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipArchive = [IO.Compression.ZipFile]::OpenRead($zipTarget)
    try { Assert-True ($null -ne ($zipArchive.Entries | Where-Object { $_.FullName -eq 'probe.txt' } | Select-Object -First 1)) 'ZIP helper should place source contents at the archive root' }
    finally { $zipArchive.Dispose() }

    $hostsPath = Join-Path $reportRoot 'hosts'
    Set-Content $hostsPath "127.0.0.1 localhost`r`n10.0.0.8 other-system" -Encoding ASCII
    Set-DatongHostsEntry -HostsPath $hostsPath -Address '127.0.0.1' -HostName 'datong-hub-offline'
    Set-DatongHostsEntry -HostsPath $hostsPath -Address '10.0.0.20' -HostName 'datong-hub-offline'
    $hostsContent = Get-Content $hostsPath -Raw
    Assert-Equal 1 @([regex]::Matches($hostsContent, '# DatongMap BEGIN')).Count 'hosts marker should be unique'
    Assert-Contains '10.0.0.20 datong-hub-offline' $hostsContent 'hosts entry should be replaced'
    Assert-Contains '10.0.0.8 other-system' $hostsContent 'unrelated hosts entries should remain'
    Remove-DatongHostsEntry -HostsPath $hostsPath
    $hostsContent = Get-Content $hostsPath -Raw
    Assert-False ($hostsContent.Contains('datong-hub-offline')) 'uninstall should remove the project hosts block'
    Assert-Contains '10.0.0.8 other-system' $hostsContent 'hosts cleanup should retain unrelated entries'
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

foreach ($cmd in @(Get-ChildItem (Join-Path $PSScriptRoot '..') -Filter '*.cmd')) {
    $bytes = [IO.File]::ReadAllBytes($cmd.FullName)
    Assert-False (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) "$($cmd.Name) should contain ASCII bytes only"
    Assert-False (@($bytes | Where-Object { ($_ -lt 32 -and $_ -notin @(9,10,13)) -or $_ -eq 127 }).Count -gt 0) "$($cmd.Name) should not contain hidden control bytes"
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    Assert-False ($ascii -match '(?<!`r)`n') "$($cmd.Name) should use CRLF line endings only"
    Assert-False ($ascii.Contains('chcp 65001')) "$($cmd.Name) should not depend on the legacy console UTF-8 code page"
}

$checkContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\01-check-environment.ps1') -Raw -Encoding UTF8
Assert-Contains 'Test-DatongWindowsCompatibility' $checkContent 'environment check should enforce the Windows 6.3 boundary'
Assert-Contains 'Test-DatongPowerShellCompatibility' $checkContent 'environment check should enforce the PowerShell 4 boundary'
Assert-Contains 'Test-DatongExecutableProbe' $checkContent 'environment check should execute runtime probes'
Assert-Contains 'DatongWinSWProbe.xml' $checkContent 'WinSW probe should supply the configuration file required by WinSW 2.x'
$databaseContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\03-prepare-database.ps1') -Raw -Encoding UTF8
Assert-Contains 'Test-DatongExecutableProbe' $databaseContent 'database stage should repeat the MySQL probe after installing the VC runtime'
Assert-Contains "ExpectedPattern '8\.0\.28'" $databaseContent 'database stage should enforce the locked MySQL compatibility version'
Assert-Contains '& $mysqld --install $settings.MySqlServiceName "--defaults-file=$mysqlConfig"' $databaseContent 'MySQL service mode must precede defaults-file so mysqld registers instead of starting in console mode'
Assert-Contains 'mirror local/datong-map' $databaseContent 'pre-upgrade backup should include MinIO objects as well as MySQL'
$backendServiceTemplate = Get-Content (Join-Path $PSScriptRoot '..\service\backend.xml.template') -Raw -Encoding UTF8
foreach ($requiredEnvironment in @('WINDOWS_TLS_KEYSTORE','WINDOWS_TLS_KEYSTORE_PASSWORD','MYSQL_URL','MYSQL_USER','MYSQL_PASSWORD','JWT_SECRET','MINIO_ENDPOINT','MINIO_ACCESS_KEY','MINIO_SECRET_KEY')) {
    Assert-Contains ('<env name="' + $requiredEnvironment + '"') $backendServiceTemplate "backend service should pass $requiredEnvironment to the active windows profile"
}
$serviceInstallContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\04-install-services.ps1') -Raw -Encoding UTF8
Assert-Contains 'WINDOWS_TLS_KEYSTORE = Xml $settings.CertificatePath' $serviceInstallContent 'service installation should render the generated TLS keystore path'
Assert-Contains 'WINDOWS_TLS_KEYSTORE_PASSWORD = Xml $settings.CertificatePassword' $serviceInstallContent 'service installation should render the generated TLS keystore password'
$verifyContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\05-verify.ps1') -Raw -Encoding UTF8
Assert-Contains 'Enable-DatongTls12' $verifyContent 'deployment verification should explicitly enable TLS 1.2'
Assert-Contains 'Invoke-DatongHttpsRequest' $verifyContent 'deployment verification should use the runspace-safe HTTPS helper'
Assert-False ($verifyContent.Contains('ServerCertificateValidationCallback = { $true }')) 'deployment verification should not use a PowerShell script block as the TLS callback'
Assert-Contains '$homeResponse' $verifyContent 'deployment verification should avoid the read-only HOME automatic variable'
Assert-False ([regex]::IsMatch($verifyContent, '(?im)\$home\b')) 'deployment verification should not assign to the read-only HOME automatic variable'
$statusContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\status.ps1') -Raw -Encoding UTF8
Assert-Contains 'Enable-DatongTls12' $statusContent 'status health check should explicitly enable TLS 1.2'
Assert-Contains 'Invoke-DatongHttpsRequest' $statusContent 'status health check should use the runspace-safe HTTPS helper'
Assert-False ($statusContent.Contains('ServerCertificateValidationCallback = { $true }')) 'status health check should not use a PowerShell script block as the TLS callback'
$moduleContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\DatongDeploy.psm1') -Raw -Encoding UTF8
Assert-Contains 'ICertificatePolicy' $moduleContent 'HTTPS helper should use a CLR certificate policy that does not require a PowerShell runspace'
Assert-Contains '[Net.ServicePointManager]::CertificatePolicy = $oldCertificatePolicy' $moduleContent 'HTTPS helper should restore the previous certificate policy'
Assert-Contains '[Net.ServicePointManager]::ServerCertificateValidationCallback = $oldCertificateCallback' $moduleContent 'HTTPS helper should restore the previous certificate callback'
Assert-Contains 'function Set-DatongHostsEntry' $moduleContent 'shared module should own the marked hosts entry writer'
Assert-Contains 'function Remove-DatongHostsEntry' $moduleContent 'shared module should own the marked hosts entry cleanup'

$uninstallContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\uninstall.ps1') -Raw -Encoding UTF8
Assert-Contains '[switch]$RemoveCertificates' $uninstallContent 'uninstaller should expose certificate cleanup explicitly'
Assert-Contains 'if (Test-Path $settingsPath)' $uninstallContent 'uninstaller should tolerate configuration not having been generated'
Assert-Contains 'CertificateThumbprint' $uninstallContent 'uninstaller should scope certificate cleanup by recorded thumbprint'
Assert-Contains 'certificate-thumbprint.txt' $uninstallContent 'uninstaller should clean a certificate from a half-finished configuration stage'
Assert-Contains "PSObject.Properties['OwnsMySqlService']" $uninstallContent 'uninstaller should tolerate a partially written settings object'
Assert-Contains 'cmd.exe /D /C' $uninstallContent 'uninstaller should isolate task deletion from PowerShell native stderr handling'
Assert-Contains 'schtasks.exe /Delete /TN "DatongMap-DailyBackup" /F >nul 2>&1' $uninstallContent 'uninstaller should ignore a missing backup task without raising NativeCommandError'
Assert-Contains 'Remove-DatongHostsEntry' $uninstallContent 'uninstaller should remove only the project hosts block'
$configureContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\02-configure.ps1') -Raw -Encoding UTF8
Assert-Contains 'CertificateThumbprint' $configureContent 'configuration should record the generated certificate thumbprint'
Assert-Contains 'certificate-thumbprint.txt' $configureContent 'configuration should persist certificate ownership before later steps can fail'
Assert-Contains 'certreq.exe' $configureContent 'certificate generation should use the Windows 2012 R2 built-in certreq tool'
Assert-False ($configureContent.Contains('New-SelfSignedCertificate')) 'certificate generation should not depend on the newer PKI cmdlet parameter surface'
Assert-Contains '$accessHostName = ''datong-hub-offline''' $configureContent 'configuration should use the fixed project hostname'
Assert-Contains "dns=localhost" $configureContent 'certificate SAN should include localhost'
Assert-Contains "ipaddress=127.0.0.1" $configureContent 'certificate SAN should include loopback IPv4'
Assert-Contains "Cert:\LocalMachine\Root" $configureContent 'server installation should trust the generated project certificate'
Assert-Contains 'Set-DatongHostsEntry' $configureContent 'server installation should resolve the fixed project hostname locally'
Assert-Contains 'Import-Certificate -FilePath $existingSettings.ClientCertificatePath' $configureContent 'idempotent upgrades should restore local certificate trust'
Assert-Contains "Set-DatongHostsEntry -Address '127.0.0.1' -HostName `$accessHostName" $configureContent 'idempotent upgrades should restore local hostname resolution'
$clientCertificateContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\install-client-certificate.ps1') -Raw -Encoding UTF8
Assert-Contains "AccessHostName = 'datong-hub-offline'" $clientCertificateContent 'client installer should use the fixed project hostname'
Assert-Contains '[Net.IPAddress]::TryParse' $clientCertificateContent 'client installer should validate the server IP'
Assert-Contains 'Set-DatongHostsEntry' $clientCertificateContent 'client installer should map the fixed hostname to the server IP'
Assert-Contains 'https://$AccessHostName' $clientCertificateContent 'client installer should open the fixed project URL'
Assert-Contains 'AccessHostName' $verifyContent 'deployment report should show the fixed project URL'
$tutorialContent = @(
    Get-Content (Join-Path $PSScriptRoot '..\Windows一键部署教程.md') -Raw -Encoding UTF8
    Get-Content (Join-Path $PSScriptRoot '..\Windows一键部署教程.html') -Raw -Encoding UTF8
    Get-Content (Join-Path $PSScriptRoot '..\Windows部署操作手册.md') -Raw -Encoding UTF8
    Get-Content (Join-Path $PSScriptRoot '..\Windows部署操作手册.html') -Raw -Encoding UTF8
) -join "`n"
Assert-Contains 'https://datong-hub-offline:8012' $tutorialContent 'field documentation should publish the fixed project URL'
Assert-False ($tutorialContent.Contains('https://服务器IP:8012')) 'field documentation should not publish the server IP as the final URL'
$diagnosticsContent = Get-Content (Join-Path $PSScriptRoot '..\scripts\collect-diagnostics.ps1') -Raw -Encoding UTF8
Assert-Contains 'schtasks.exe /Query' $diagnosticsContent 'diagnostics should capture the project backup task'
Assert-Contains '计划任务尚未创建' $diagnosticsContent 'diagnostics should tolerate the backup task not existing yet'
Assert-Contains 'Get-NetFirewallRule' $diagnosticsContent 'diagnostics should capture the project firewall rule'
Assert-Contains 'CertificateThumbprint' $diagnosticsContent 'diagnostics should report the project certificate thumbprint without exporting secrets'
Assert-Contains "'mysql\data'" $diagnosticsContent 'diagnostics should capture the bundled MySQL error log after an early service failure'
Assert-Contains "'*.err'" $diagnosticsContent 'diagnostics should include MySQL error files'

$buildContent = Get-Content (Join-Path $PSScriptRoot '..\build-package.ps1') -Raw -Encoding UTF8
Assert-Contains '[string]$PackageVersion' $buildContent 'package builder should accept an explicit patch version'
Assert-Contains '[string]$CompatibilityStatus' $buildContent 'package builder should record validation status only after the matching real-machine run'
Assert-Contains "[string]`$PackageVersion = '2026.07.23.1'" $buildContent 'package builder should default to the fixed-hostname package version'
Assert-Contains '固定可信访问名' $buildContent 'package manifest should advertise the fixed trusted URL'
foreach ($packageFile in @('Windows一键部署教程.md','Windows一键部署教程.html','package-manifest.json','版本信息.txt')) {
    Assert-Contains $packageFile $buildContent "offline package should include $packageFile"
}
Assert-Contains "zipPath + '.sha256'" $buildContent 'package builder should emit a ZIP SHA-256 sidecar'
Assert-Contains 'New-DatongZip -SourceDirectory $stageRoot' $buildContent 'ZIP should be created with .NET and extract directly into C:\DatongMap without a nested folder'
Assert-Contains 'RuntimeSeedPackage' $buildContent 'offline rebuild should support a previously verified runtime seed package'
Assert-True (Test-Path (Join-Path $PSScriptRoot '..\Windows一键部署教程.md')) 'field tutorial Markdown should be tracked'
Assert-True (Test-Path (Join-Path $PSScriptRoot '..\Windows一键部署教程.html')) 'field tutorial HTML should be tracked'

$pomContent = Get-Content (Join-Path $PSScriptRoot '..\..\..\backend\pom.xml') -Raw -Encoding UTF8
Assert-Contains '<java.version>17</java.version>' $pomContent 'backend bytecode target should be Java 17'
$java21Calls = @(Get-ChildItem (Join-Path $PSScriptRoot '..\..\..\backend\src') -Recurse -Filter '*.java' | Select-String -Pattern '\.getFirst\(')
Assert-Equal 0 $java21Calls.Count 'backend source and tests should not use the Java 21 List.getFirst API'

$runtimeLock = Get-Content (Join-Path $PSScriptRoot '..\runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$runtimeVersions = @{}
foreach ($component in $runtimeLock.Components) { $runtimeVersions[$component.Name] = $component.Version }
Assert-Equal '17.0.8.1+1' $runtimeVersions['Eclipse Temurin JRE'] 'runtime lock should use the Server 2012 R2 Java candidate'
Assert-Equal '8.0.28' $runtimeVersions['MySQL Community Server'] 'runtime lock should use the Server 2012 R2 MySQL candidate'
Assert-Equal 'RELEASE.2023-07-21T21-12-44Z' $runtimeVersions['MinIO Server'] 'runtime lock should use the compatibility-period MinIO server'
Assert-Equal 'RELEASE.2023-07-21T20-44-27Z' $runtimeVersions['MinIO Client'] 'runtime lock should use the compatibility-period MinIO client'
Assert-Equal '2.12.0-net4' $runtimeVersions['WinSW'] 'runtime lock should use the WinSW .NET 4 build'

foreach ($scriptFile in @(Get-ChildItem (Join-Path $PSScriptRoot '..\scripts') -Recurse -Include '*.ps1','*.psm1')) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-Equal 0 @($parseErrors).Count "$($scriptFile.Name) should parse cleanly"
}
$runtimeScriptText = @(Get-ChildItem (Join-Path $PSScriptRoot '..\scripts') -Recurse -Include '*.ps1','*.psm1' | ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 }) -join "`n"
Assert-False ($runtimeScriptText.Contains('Compress-Archive')) 'runtime scripts should use .NET ZipFile instead of the PowerShell 5 Compress-Archive cmdlet'

Write-Host 'DatongDeploy tests passed.' -ForegroundColor Green
