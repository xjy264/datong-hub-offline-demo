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
    } finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }
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

Remove-Item $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $stageRoot 'app') | Out-Null
Copy-Item $jar (Join-Path $stageRoot 'app/datong-map-server.jar')
foreach ($folder in @('scripts','service','config')) { Copy-Item (Join-Path $windowsRoot $folder) (Join-Path $stageRoot $folder) -Recurse }
foreach ($file in @('开始部署.cmd','开始环境检测.cmd','客户端证书安装.cmd','Windows部署操作手册.md','Windows部署操作手册.html','runtime-lock.json')) {
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

$zipName = if ($Mode -eq 'Offline') { 'datong-map-windows-offline.zip' } else { 'datong-map-windows-slim.zip' }
$zipPath = Join-Path $outputRoot $zipName
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path $stageRoot -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Windows部署包已生成：$zipPath" -ForegroundColor Green
