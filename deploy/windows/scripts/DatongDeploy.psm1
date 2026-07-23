Set-StrictMode -Version Latest

function Write-DatongStage([string]$Text) {
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Test-DatongAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DatongPortOwner([int]$Port) {
    try {
        $connection = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop | Select-Object -First 1
        if ($null -eq $connection) { return $null }
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Port = $Port
            Address = $connection.LocalAddress
            ProcessId = $connection.OwningProcess
            ProcessName = if ($process) { $process.ProcessName } else { 'unknown' }
        }
    } catch {
        return $null
    }
}

function Test-DatongMySqlVersion([string]$Version) {
    if ($Version -notmatch '^(\d+)\.') { return $false }
    return [int]$Matches[1] -eq 8
}

function Test-DatongWindowsCompatibility([version]$Version) {
    return $Version -ge [version]'6.3'
}

function Test-DatongPowerShellCompatibility([version]$Version) {
    return $Version -ge [version]'4.0'
}

function Get-DatongDiskAssessment {
    param(
        [double]$FreeGB,
        [double]$MinimumGB = 5,
        [double]$RecommendedGB = 20
    )
    return [pscustomobject]@{
        FreeGB = [math]::Round($FreeGB, 1)
        Passed = $FreeGB -ge $MinimumGB
        Warning = $FreeGB -ge $MinimumGB -and $FreeGB -lt $RecommendedGB
        MinimumGB = $MinimumGB
        RecommendedGB = $RecommendedGB
    }
}

function Enable-DatongTls12 {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

function Invoke-DatongHttpsRequest {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [int]$TimeoutSec = 10
    )
    Enable-DatongTls12
    if (-not ('DatongTrustAllCertificatePolicy' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public sealed class DatongTrustAllCertificatePolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint servicePoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
        return true;
    }
}
'@
    }
    $oldCertificatePolicy = [Net.ServicePointManager]::CertificatePolicy
    $oldCertificateCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
    try {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        [Net.ServicePointManager]::CertificatePolicy = New-Object DatongTrustAllCertificatePolicy
        return Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec $TimeoutSec
    } finally {
        [Net.ServicePointManager]::CertificatePolicy = $oldCertificatePolicy
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $oldCertificateCallback
    }
}

function Test-DatongExecutableProbe {
    param(
        [string]$Path,
        [string[]]$Arguments = @(),
        [string]$ExpectedPattern = '.'
    )
    if (-not (Test-Path $Path -PathType Leaf)) {
        return [pscustomobject]@{ Path = $Path; Exists = $false; Passed = $false; Output = ''; ExitCode = -1 }
    }
    $output = ''
    $exitCode = -1
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Java and several vendor tools intentionally print version information
        # to stderr. PowerShell 4/5 converts that stream into error records, so
        # probe it with Continue and judge the native process by LASTEXITCODE.
        $ErrorActionPreference = 'Continue'
        $output = (& $Path @Arguments 2>&1 | Out-String).Trim()
        $exitCode = $LASTEXITCODE
    } catch {
        $output = $_.Exception.Message
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return [pscustomobject]@{
        Path = $Path
        Exists = $true
        Passed = ($exitCode -eq 0 -and $output -match $ExpectedPattern)
        Output = $output
        ExitCode = $exitCode
    }
}

function New-DatongZip {
    param(
        [Parameter(Mandatory=$true)][string]$SourceDirectory,
        [Parameter(Mandatory=$true)][string]$DestinationPath
    )
    if (-not (Test-Path $SourceDirectory -PathType Container)) { throw "ZIP源目录不存在：$SourceDirectory" }
    $parent = Split-Path $DestinationPath -Parent
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($SourceDirectory, $DestinationPath, [IO.Compression.CompressionLevel]::Optimal, $false)
}

function Get-DatongExecutablePath([string]$PathName) {
    if ([string]::IsNullOrWhiteSpace($PathName)) { return $null }
    if ($PathName -match '^"([^"]+)"') { return $Matches[1] }
    if ($PathName -match '^(\S+)') { return $Matches[1] }
    return $null
}

function Get-DatongDefaultsFile([string]$PathName) {
    if ($PathName -match '--defaults-file(?:=|\s+)(?:"([^"]+)"|(\S+))') {
        return $(if ($Matches[1]) { $Matches[1] } else { $Matches[2] })
    }
    return $null
}

function Get-DatongMySqlPort([string]$DefaultsFile) {
    if ($DefaultsFile -and (Test-Path $DefaultsFile)) {
        $line = Get-Content $DefaultsFile | Where-Object { $_ -match '^\s*port\s*=\s*(\d+)\s*$' } | Select-Object -First 1
        if ($line -match '(\d+)') { return [int]$Matches[1] }
    }
    return 3306
}

function Get-DatongMySqlCandidates {
    $services = @(Get-CimInstance Win32_Service | Where-Object {
        $_.Name -match 'mysql|mariadb' -or $_.PathName -match 'mysqld|mariadbd'
    })
    $result = @()
    $id = 0
    foreach ($service in $services) {
        $id++
        $exe = Get-DatongExecutablePath $service.PathName
        $versionText = ''
        if ($exe -and (Test-Path $exe)) {
            try { $versionText = (& $exe --version 2>$null | Out-String).Trim() } catch { $versionText = '' }
        }
        $version = if ($versionText -match '(\d+\.\d+\.\d+)') { $Matches[1] } else { 'unknown' }
        $defaultsFile = Get-DatongDefaultsFile $service.PathName
        $isMaria = $service.Name -match 'maria' -or $versionText -match 'MariaDB'
        $result += [pscustomobject]@{
            Id = $id
            Name = $service.Name
            DisplayName = $service.DisplayName
            State = $service.State
            StartMode = $service.StartMode
            Version = $version
            Executable = $exe
            ConfigFile = $defaultsFile
            Port = Get-DatongMySqlPort $defaultsFile
            Compatible = (-not $isMaria) -and (Test-DatongMySqlVersion $version) -and $service.State -eq 'Running'
        }
    }
    return @($result)
}

function Select-DatongMySqlPlan($Candidates, [bool]$Port3306InUse) {
    $compatible = @($Candidates | Where-Object { $_.Compatible })
    if ($compatible.Count -eq 1) {
        return [pscustomobject]@{ Action = 'Reuse'; Port = $compatible[0].Port; Candidate = $compatible[0] }
    }
    if ($compatible.Count -gt 1) {
        return [pscustomobject]@{ Action = 'Select'; Port = $null; Candidate = $null }
    }
    return [pscustomobject]@{ Action = 'Bundled'; Port = $(if ($Port3306InUse) { 3311 } else { 3306 }); Candidate = $null }
}

function Get-DatongBundledMySqlPort([bool]$Port3306InUse, [int]$ExistingProjectPort = 0) {
    if ($ExistingProjectPort -gt 0) { return $ExistingProjectPort }
    return $(if ($Port3306InUse) { 3311 } else { 3306 })
}

function Get-DatongReusableProjectSettings($ExistingSettings, [string]$PackageRoot) {
    if ($null -eq $ExistingSettings) { return $null }
    $ownedProperty = $ExistingSettings.PSObject.Properties['OwnsMySqlService']
    if ($null -eq $ownedProperty -or -not [bool]$ownedProperty.Value) { return $null }
    $copy = $ExistingSettings.PSObject.Copy()
    if ($copy.PSObject.Properties['PackageRoot']) { $copy.PackageRoot = $PackageRoot }
    else { $copy | Add-Member -NotePropertyName PackageRoot -NotePropertyValue $PackageRoot }
    $mysqlExecutable = $PackageRoot.TrimEnd('\') + '\runtime\mysql\bin\mysqld.exe'
    if ($copy.PSObject.Properties['MySqlExecutable']) { $copy.MySqlExecutable = $mysqlExecutable }
    else { $copy | Add-Member -NotePropertyName MySqlExecutable -NotePropertyValue $mysqlExecutable }
    if ($copy.PSObject.Properties['UpdatedAt']) { $copy.UpdatedAt = (Get-Date).ToString('o') }
    else { $copy | Add-Member -NotePropertyName UpdatedAt -NotePropertyValue (Get-Date).ToString('o') }
    return $copy
}

function New-DatongSecret([int]$Bytes = 32) {
    $buffer = New-Object byte[] $Bytes
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
    return -join ($buffer | ForEach-Object { $_.ToString('x2') })
}

function Get-DatongDatabaseDecision([bool]$Exists, [string[]]$Tables) {
    if (-not $Exists -or $Tables.Count -eq 0) {
        return [pscustomobject]@{ Action = 'Initialize'; Reason = '数据库尚未初始化。' }
    }
    if ($Tables -contains 'flyway_schema_history') {
        return [pscustomobject]@{ Action = 'Upgrade'; Reason = '检测到本项目Flyway记录，升级前先备份。' }
    }
    return [pscustomobject]@{ Action = 'Stop'; Reason = '同名数据库中存在来源不明的数据表。' }
}

function Get-DatongManagedServices([bool]$OwnsMySqlService, [string]$MySqlServiceName = 'DatongMapMySQL') {
    $services = @('DatongMapMinIO', 'DatongMapBackend')
    if ($OwnsMySqlService) { $services = @($MySqlServiceName) + $services }
    return @($services)
}

function Protect-DatongDiagnosticText([string]$Text, [string[]]$Secrets = @()) {
    $result = $Text
    foreach ($secret in $Secrets) {
        if (-not [string]::IsNullOrWhiteSpace($secret)) {
            $result = $result -replace [regex]::Escape($secret), '[REDACTED]'
        }
    }
    $result = $result -replace '(?im)^(\s*(?:MYSQL_PASSWORD|MINIO_SECRET_KEY|JWT_SECRET|WINDOWS_TLS_KEYSTORE_PASSWORD)\s*[=:]\s*).+$', '$1[REDACTED]'
    return ($result -replace '(?i)("(?:MySqlPassword|MinioAccessKey|MinioSecretKey|JwtSecret|CertificatePassword)"\s*:\s*")[^"]*(")', '$1[REDACTED]$2')
}

function New-DatongDeploymentState {
    param(
        [int]$Stage,
        [string]$StageName,
        [string]$Component,
        [ValidateSet('RUNNING','PASS','STOP')][string]$Status,
        [string]$StartedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'),
        [string]$Message = '',
        [string]$NextAction = '',
        [string]$DiagnosticPath = '',
        [object[]]$Stages = @()
    )
    $componentCode = (($Component.ToUpperInvariant() -replace '[^A-Z0-9]+','-').Trim('-'))
    if ([string]::IsNullOrWhiteSpace($componentCode)) { $componentCode = 'UNKNOWN' }
    $errorCode = if ($componentCode -eq 'UNKNOWN') { 'WIN-99-UNKNOWN' } else { 'WIN-{0:D2}-{1}' -f $Stage, $componentCode }
    return [pscustomobject][ordered]@{
        Result = $Status
        Stage = $Stage
        StageName = $StageName
        Component = $Component
        ErrorCode = $errorCode
        Message = $Message
        StartedAt = $StartedAt
        UpdatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        NextAction = $NextAction
        DiagnosticPath = $DiagnosticPath
        Stages = @($Stages)
        Warnings = @()
        Blockers = $(if ($Status -eq 'STOP' -and $Message) { @($Message) } else { @() })
    }
}

function Save-DatongJson([string]$Path, $Value) {
    $directory = Split-Path $Path -Parent
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $Value | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding UTF8
}

function Read-DatongJson([string]$Path) {
    if (-not (Test-Path $Path)) { throw "缺少文件：$Path" }
    return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-DatongReport([string]$JsonPath, [string]$HtmlPath, [string]$Title, $Value) {
    Save-DatongJson $JsonPath $Value
    $json = $Value | ConvertTo-Json -Depth 12
    $encoded = [Net.WebUtility]::HtmlEncode($json)
    $result = if ($Value.Result) { [string]$Value.Result } else { 'INFO' }
    $nextAction = if ($Value.PSObject.Properties.Name -contains 'NextAction') { [Net.WebUtility]::HtmlEncode([string]$Value.NextAction) } else { '按报告结论继续向导，或将报告发送给远程技术人员。' }
    $resultClass = switch ($result) { 'PASS' { 'pass' } 'STOP' { 'stop' } default { 'warn' } }
    $warningValues = if ($Value.PSObject.Properties.Name -contains 'Warnings') { @($Value.Warnings) } else { @() }
    $blockerValues = if ($Value.PSObject.Properties.Name -contains 'Blockers') { @($Value.Blockers) } elseif ($Value.PSObject.Properties.Name -contains 'Problems') { @($Value.Problems) } else { @() }
    $warnings = @($warningValues | ForEach-Object { '<li>' + [Net.WebUtility]::HtmlEncode([string]$_) + '</li>' }) -join ''
    $blockers = @($blockerValues | ForEach-Object { '<li>' + [Net.WebUtility]::HtmlEncode([string]$_) + '</li>' }) -join ''
    if (-not $warnings) { $warnings = '<li>无黄色提醒</li>' }
    if (-not $blockers) { $blockers = '<li>无红色停止项</li>' }
    $failureDetails = ''
    if ($result -eq 'STOP' -and $Value.PSObject.Properties.Name -contains 'Stage') {
        $stage = [Net.WebUtility]::HtmlEncode([string]$Value.Stage)
        $stageName = [Net.WebUtility]::HtmlEncode([string]$Value.StageName)
        $component = [Net.WebUtility]::HtmlEncode([string]$Value.Component)
        $errorCode = [Net.WebUtility]::HtmlEncode([string]$Value.ErrorCode)
        $message = [Net.WebUtility]::HtmlEncode([string]$Value.Message)
        $diagnosticPath = [Net.WebUtility]::HtmlEncode([string]$Value.DiagnosticPath)
        $feedbackText = [Net.WebUtility]::HtmlEncode("错误编号：$($Value.ErrorCode)`n失败阶段：第 $($Value.Stage) 阶段 $($Value.StageName)`n失败组件：$($Value.Component)`n原因：$($Value.Message)`n诊断包：$($Value.DiagnosticPath)")
        $failureDetails = @"
<section class="card stop"><h2>部署失败位置</h2>
<p><strong>失败阶段：第 $stage 阶段 $stageName</strong></p>
<p><strong>失败组件：$component</strong></p>
<p><strong>错误编号：$errorCode</strong></p>
<p><strong>原因：</strong>$message</p>
<p><strong>诊断包：</strong><code>$diagnosticPath</code></p>
<textarea id="feedback" readonly>$feedbackText</textarea><button type="button" onclick="copyFeedback()">复制反馈信息</button><span id="copy-result"></span>
</section>
"@
    }
    $html = @"
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>$Title</title>
<style>body{font-family:Segoe UI,Microsoft YaHei,sans-serif;margin:32px;color:#1f2937;background:#f8fafc}h1{color:#075985}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}.card{background:white;border-radius:10px;padding:16px;border:1px solid #cbd5e1;margin:16px 0}.pass{border-left:8px solid #16a34a}.warn{border-left:8px solid #eab308}.stop{border-left:8px solid #dc2626}pre{white-space:pre-wrap;background:#0f172a;color:#e2e8f0;padding:18px;border-radius:8px}.hint{padding:12px;background:#ecfeff;border-left:4px solid #0891b2}textarea{box-sizing:border-box;width:100%;min-height:130px;padding:12px}button{margin-top:10px;padding:10px 20px;border:0;border-radius:6px;background:#075985;color:white;font-size:16px;cursor:pointer}code{word-break:break-all}</style></head>
<body><h1>$Title</h1><div class="card $resultClass"><h2>检测结论：$result</h2><p>PASS可继续；黄色项目按提示确认；STOP时请停止并发送本报告。</p></div>
$failureDetails
<div class="grid"><section class="card warn"><h2>黄色提醒</h2><ul>$warnings</ul></section><section class="card stop"><h2>红色停止项</h2><ul>$blockers</ul></section></div>
<p class="hint"><strong>下一步：</strong>$nextAction</p><details><summary>技术详情</summary><pre>$encoded</pre></details>
<script>function copyFeedback(){var e=document.getElementById('feedback');e.focus();e.select();try{document.execCommand('copy');document.getElementById('copy-result').textContent=' 已复制';}catch(x){document.getElementById('copy-result').textContent=' 请手动复制上方内容';}}</script></body></html>
"@
    $html | Set-Content -Path $HtmlPath -Encoding UTF8
}

function Write-DatongDeploymentProgress {
    param([string]$PackageRoot, $State)
    $reports = Join-Path $PackageRoot 'reports'
    New-Item -ItemType Directory -Force -Path $reports | Out-Null
    Write-DatongReport (Join-Path $reports 'deployment-status.json') (Join-Path $reports 'deployment-status.html') '大同示意图 Windows 一键部署状态' $State
    $color = switch ($State.Result) { 'PASS' { 'Green' } 'STOP' { 'Red' } default { 'Cyan' } }
    Write-Host ("[{0}/5] {1} / {2} - {3}" -f $State.Stage, $State.StageName, $State.Component, $State.Result) -ForegroundColor $color
}

function Set-DatongPrivateAcl([string]$Path) {
    & icacls.exe $Path /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "目录权限设置失败：$Path" }
}

function Resolve-DatongPackageRoot([string]$ScriptRoot) {
    return (Resolve-Path (Join-Path $ScriptRoot '..')).Path
}

function Remove-DatongHostsEntry {
    param([string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts")
    if (-not (Test-Path $HostsPath)) { return }
    $content = [IO.File]::ReadAllText($HostsPath)
    $content = [regex]::Replace($content, '(?ms)^# DatongMap BEGIN\r?\n.*?^# DatongMap END\r?\n?', '')
    [IO.File]::WriteAllText($HostsPath, $content.TrimEnd("`r", "`n") + "`r`n", [Text.Encoding]::ASCII)
}

function Set-DatongHostsEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Address,
        [Parameter(Mandatory = $true)][string]$HostName,
        [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    )
    Remove-DatongHostsEntry -HostsPath $HostsPath
    $content = if (Test-Path $HostsPath) { [IO.File]::ReadAllText($HostsPath).TrimEnd("`r", "`n") } else { '' }
    $block = "# DatongMap BEGIN`r`n$Address $HostName`r`n# DatongMap END"
    $updated = if ($content) { $content + "`r`n" + $block + "`r`n" } else { $block + "`r`n" }
    [IO.File]::WriteAllText($HostsPath, $updated, [Text.Encoding]::ASCII)
}

Export-ModuleMember -Function Write-DatongStage, Test-DatongAdministrator, Get-DatongPortOwner, Test-DatongMySqlVersion, Test-DatongWindowsCompatibility, Test-DatongPowerShellCompatibility, Get-DatongDiskAssessment, Enable-DatongTls12, Invoke-DatongHttpsRequest, Test-DatongExecutableProbe, New-DatongZip, Get-DatongMySqlCandidates, Select-DatongMySqlPlan, Get-DatongBundledMySqlPort, Get-DatongReusableProjectSettings, New-DatongSecret, Get-DatongDatabaseDecision, Get-DatongManagedServices, Protect-DatongDiagnosticText, New-DatongDeploymentState, Save-DatongJson, Read-DatongJson, Write-DatongReport, Write-DatongDeploymentProgress, Set-DatongPrivateAcl, Resolve-DatongPackageRoot, Set-DatongHostsEntry, Remove-DatongHostsEntry
