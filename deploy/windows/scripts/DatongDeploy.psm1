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
    return ($result -replace '(?im)^(\s*(?:MYSQL_PASSWORD|MINIO_SECRET_KEY|JWT_SECRET|WINDOWS_TLS_KEYSTORE_PASSWORD)\s*[=:]\s*).+$', '$1[REDACTED]')
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
    $html = @"
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>$Title</title>
<style>body{font-family:Segoe UI,Microsoft YaHei,sans-serif;margin:32px;color:#1f2937;background:#f8fafc}h1{color:#075985}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}.card{background:white;border-radius:10px;padding:16px;border:1px solid #cbd5e1}.pass{border-left:8px solid #16a34a}.warn{border-left:8px solid #eab308}.stop{border-left:8px solid #dc2626}pre{white-space:pre-wrap;background:#0f172a;color:#e2e8f0;padding:18px;border-radius:8px}.hint{padding:12px;background:#ecfeff;border-left:4px solid #0891b2}</style></head>
<body><h1>$Title</h1><div class="card $resultClass"><h2>检测结论：$result</h2><p>PASS可继续；黄色项目按提示确认；STOP时请停止并发送本报告。</p></div>
<div class="grid"><section class="card warn"><h2>黄色提醒</h2><ul>$warnings</ul></section><section class="card stop"><h2>红色停止项</h2><ul>$blockers</ul></section></div>
<p class="hint"><strong>下一步：</strong>$nextAction</p><details><summary>技术详情</summary><pre>$encoded</pre></details></body></html>
"@
    $html | Set-Content -Path $HtmlPath -Encoding UTF8
}

function Set-DatongPrivateAcl([string]$Path) {
    & icacls.exe $Path /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "目录权限设置失败：$Path" }
}

function Resolve-DatongPackageRoot([string]$ScriptRoot) {
    return (Resolve-Path (Join-Path $ScriptRoot '..')).Path
}

Export-ModuleMember -Function Write-DatongStage, Test-DatongAdministrator, Get-DatongPortOwner, Test-DatongMySqlVersion, Get-DatongMySqlCandidates, Select-DatongMySqlPlan, New-DatongSecret, Get-DatongDatabaseDecision, Get-DatongManagedServices, Protect-DatongDiagnosticText, Save-DatongJson, Read-DatongJson, Write-DatongReport, Set-DatongPrivateAcl, Resolve-DatongPackageRoot
