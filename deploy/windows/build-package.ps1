[CmdletBinding()]
param(
    [ValidateSet('Slim','Offline')][string]$Mode = 'Slim',
    [string]$RuntimeCache = (Join-Path ([IO.Path]::GetTempPath()) 'datong-windows-runtime'),
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$windowsRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $windowsRoot '..\..')).Path
$outputRoot = Join-Path $windowsRoot 'output'
$stageRoot = Join-Path $outputRoot 'datong-map-windows'
$lock = Get-Content (Join-Path $windowsRoot 'runtime-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$packageVersion = '2026.07.21.1'

function Run([string]$File, [string[]]$Arguments, [string]$WorkingDirectory) {
    Push-Location $WorkingDirectory
    try {
        & $File @Arguments
        if ($LASTEXITCODE -ne 0) { throw "命令执行失败：$File $($Arguments -join ' ')" }
    } finally { Pop-Location }
}

function Download-LockedRuntime($Item) {
    New-Item -ItemType Directory -Force -Path $RuntimeCache | Out-Null
    $target = Join-Path $RuntimeCache $Item.FileName
    if (-not (Test-Path $target)) {
        Write-Host "下载 $($Item.Name) $($Item.Version)..."
        Invoke-WebRequest -UseBasicParsing -Uri $Item.Url -OutFile $target
    }
    $actual = (Get-FileHash $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Item.Sha256.ToLowerInvariant()) {
        Remove-Item $target -Force
        throw "$($Item.Name) 校验失败。expected=$($Item.Sha256) actual=$actual"
    }
    return $target
}

function Copy-ZipContent([string]$Archive, [string]$Destination) {
    $temp = Join-Path $outputRoot ('extract-' + [guid]::NewGuid().ToString('N'))
    try {
        Expand-Archive -Path $Archive -DestinationPath $temp -Force
        $children = @(Get-ChildItem $temp)
        $source = if ($children.Count -eq 1 -and $children[0].PSIsContainer) { $children[0].FullName } else { $temp }
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        Copy-Item (Join-Path $source '*') $Destination -Recurse -Force
    } finally { Remove-Tree $temp }
}

function Remove-Tree([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    if ($IsWindows) {
        Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $_.PSIsContainer) { $_.IsReadOnly = $false }
        }
    } else {
        & chmod -R u+w $Path
        if ($LASTEXITCODE -ne 0) { throw "临时目录权限清理失败：$Path" }
    }
    Remove-Item $Path -Recurse -Force
}

if (-not $SkipBuild) {
    $npm = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'npm.cmd' } else { 'npm' }
    $mvn = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'mvn.cmd' } else { 'mvn' }
    Run $npm @('ci') (Join-Path $repoRoot 'frontend')
    Run 'node' @('--test','src/utils/*.test.mjs') (Join-Path $repoRoot 'frontend')
    Run $npm @('run','build') (Join-Path $repoRoot 'frontend')
    Run $mvn @('test') (Join-Path $repoRoot 'backend')
    Run $mvn @('-Pwindows-package','-DskipTests','package') (Join-Path $repoRoot 'backend')
}

$jar = Join-Path $repoRoot 'backend/target/datong-map-server-0.1.0.jar'
if (-not (Test-Path $jar)) { throw "应用JAR不存在：$jar" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($jar)
try {
    if (-not ($archive.Entries | Where-Object { $_.FullName -eq 'BOOT-INF/classes/static/index.html' })) {
        throw '应用JAR中缺少前端index.html。'
    }
} finally { $archive.Dispose() }

Remove-Tree $stageRoot
New-Item -ItemType Directory -Force -Path (Join-Path $stageRoot 'app') | Out-Null
Copy-Item $jar (Join-Path $stageRoot 'app/datong-map-server.jar')
foreach ($folder in @('scripts','service','config')) { Copy-Item (Join-Path $windowsRoot $folder) (Join-Path $stageRoot $folder) -Recurse }
foreach ($file in @('开始部署.cmd','开始环境检测.cmd','客户端证书安装.cmd','Windows部署操作手册.md','Windows部署操作手册.html','Windows一键部署教程.md','Windows一键部署教程.html','runtime-lock.json')) {
    Copy-Item (Join-Path $windowsRoot $file) (Join-Path $stageRoot $file)
}
$utf8Bom = New-Object Text.UTF8Encoding($true)
Get-ChildItem (Join-Path $stageRoot 'scripts') -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $content = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($_.FullName, $content, $utf8Bom)
}

if ($Mode -eq 'Offline') {
    $runtimeRoot = Join-Path $stageRoot 'runtime'
    foreach ($item in $lock.Components) {
        $download = Download-LockedRuntime $item
        switch ($item.Target) {
            'java' { Copy-ZipContent $download (Join-Path $runtimeRoot 'java') }
            'mysql' { Copy-ZipContent $download (Join-Path $runtimeRoot 'mysql') }
            'minio/minio.exe' { New-Item -ItemType Directory -Force -Path (Join-Path $runtimeRoot 'minio') | Out-Null; Copy-Item $download (Join-Path $runtimeRoot 'minio/minio.exe') }
            'minio/mc.exe' { New-Item -ItemType Directory -Force -Path (Join-Path $runtimeRoot 'minio') | Out-Null; Copy-Item $download (Join-Path $runtimeRoot 'minio/mc.exe') }
            'winsw/WinSW-x64.exe' { New-Item -ItemType Directory -Force -Path (Join-Path $runtimeRoot 'winsw') | Out-Null; Copy-Item $download (Join-Path $runtimeRoot 'winsw/WinSW-x64.exe') }
            'prerequisites/vc_redist.x64.exe' { New-Item -ItemType Directory -Force -Path (Join-Path $runtimeRoot 'prerequisites') | Out-Null; Copy-Item $download (Join-Path $runtimeRoot 'prerequisites/vc_redist.x64.exe') }
        }
    }
    $lock.Components | ForEach-Object { "$($_.Sha256)  $($_.FileName)" } | Set-Content (Join-Path $stageRoot 'runtime-checksums.txt') -Encoding ASCII
}

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw '读取源码提交失败。' }
$sourceBranch = (& git -C $repoRoot branch --show-current).Trim()
$jarHash = (Get-FileHash $jar -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = [ordered]@{
    PackageVersion = $packageVersion
    Mode = $Mode
    BuiltAt = (Get-Date).ToUniversalTime().ToString('o')
    SourceCommit = $sourceCommit
    SourceBranch = $sourceBranch
    IncludesJuly21UploadCommit = 'c33b68bcc16acc8bb009fbe0b66e94cbb2f670dd'
    ApplicationJarSha256 = $jarHash
    Components = @($lock.Components | ForEach-Object { [ordered]@{ Name = $_.Name; Version = $_.Version; Target = $_.Target; Sha256 = $_.Sha256 } })
    Features = @('50MB图片安全分批上传','Windows一键离线部署','分阶段故障反馈','自动脱敏诊断包')
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $stageRoot 'package-manifest.json') -Encoding UTF8
@"
大同示意图 Windows 离线部署包
版本：$packageVersion
源码提交：$sourceCommit
构建时间：$($manifest.BuiltAt)
包含：7月21日50MB图片上传、一键部署、故障报告、自动诊断包
部署入口：开始部署.cmd
"@ | Set-Content (Join-Path $stageRoot '版本信息.txt') -Encoding UTF8

$zipName = if ($Mode -eq 'Offline') { 'datong-map-windows-offline.zip' } else { 'datong-map-windows-slim.zip' }
$zipPath = Join-Path $outputRoot $zipName
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
$zipHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$shaPath = $zipPath + '.sha256'
"$zipHash  $zipName" | Set-Content $shaPath -Encoding ASCII
Write-Host "Windows部署包已生成：$zipPath" -ForegroundColor Green
Write-Host "SHA-256：$shaPath" -ForegroundColor Green
