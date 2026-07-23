# Windows 固定访问名与证书信任 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让离线包全自动配置并可信访问 `https://datong-hub-offline:8012`，随后在目标 Windows 11 上完成彻底卸载和干净重装闭环。

**Architecture:** 复用现有 PowerShell 模块和五阶段安装流程，在共享模块中加入一个仅维护 DatongMap 标记块的 hosts 写入函数。配置阶段生成包含固定别名的证书、导入本机受信任根并保存所有权信息；客户端安装和卸载复用同一边界规则。继续使用 Windows/.NET 内置能力，不新增依赖。

**Tech Stack:** PowerShell 4、Windows certreq/证书库、hosts、Pester-free 断言测试、Spring Boot HTTPS、Edge、ZIP/SHA-256。

---

## 文件结构

- `deploy/windows/tests/DatongDeploy.Tests.ps1`：固定别名、hosts 幂等、证书、卸载、报告和文档回归测试。
- `deploy/windows/scripts/DatongDeploy.psm1`：DatongMap hosts 标记块的写入和删除函数。
- `deploy/windows/scripts/02-configure.ps1`：固定名称、SAN、证书信任和服务端 hosts 配置。
- `deploy/windows/scripts/install-client-certificate.ps1`：客户端信任证书、服务器 IP 校验和别名解析。
- `deploy/windows/scripts/uninstall.ps1`：按 Thumbprint 和项目 hosts 标记彻底清理。
- `deploy/windows/scripts/05-verify.ps1`、`deploy/windows/scripts/install.ps1`：固定地址验收和成功提示。
- `deploy/windows/Windows一键部署教程.*`、`deploy/windows/Windows部署操作手册.*`：新手操作说明。
- `deploy/windows/build-package.ps1`：版本、清单和功能信息。

### Task 1: 写固定别名和 hosts 的失败测试

**Files:**
- Modify: `deploy/windows/tests/DatongDeploy.Tests.ps1`

- [ ] **Step 1: 添加纯临时文件 hosts 行为测试**

```powershell
$hostsPath = Join-Path $reportRoot 'hosts'
Set-Content $hostsPath "127.0.0.1 localhost`r`n10.0.0.8 other-system" -Encoding ASCII
Set-DatongHostsEntry -HostsPath $hostsPath -Address '127.0.0.1' -HostName 'datong-hub-offline'
Set-DatongHostsEntry -HostsPath $hostsPath -Address '10.0.0.20' -HostName 'datong-hub-offline'
$hostsContent = Get-Content $hostsPath -Raw
Assert-Equal 1 @([regex]::Matches($hostsContent, '# DatongMap BEGIN')).Count 'hosts marker should be unique'
Assert-Contains '10.0.0.20 datong-hub-offline' $hostsContent 'hosts entry should be replaced'
Assert-Contains '10.0.0.8 other-system' $hostsContent 'unrelated hosts entries should remain'
Remove-DatongHostsEntry -HostsPath $hostsPath
Assert-False ((Get-Content $hostsPath -Raw).Contains('datong-hub-offline')) 'uninstall should remove the project hosts block'
```

- [ ] **Step 2: 添加脚本静态契约测试**

断言配置脚本包含 `AccessHostName = 'datong-hub-offline'`、DNS SAN `datong-hub-offline`/`localhost`、IP SAN `127.0.0.1`、`Cert:\LocalMachine\Root` 和 `Set-DatongHostsEntry`；客户端脚本固定打开新 URL；卸载脚本调用 `Remove-DatongHostsEntry`；教程和报告不再包含 `https://服务器IP:8012`。

- [ ] **Step 3: 运行测试并确认 RED**

Run:

```bash
pwsh -NoProfile -File deploy/windows/tests/DatongDeploy.Tests.ps1
```

Expected: FAIL，首个失败原因是 `Set-DatongHostsEntry` 尚未定义或固定别名契约缺失。

- [ ] **Step 4: 提交测试**

```bash
git add deploy/windows/tests/DatongDeploy.Tests.ps1
git commit -m "test: 覆盖 Windows 固定访问名与证书信任"
```

### Task 2: 实现最小 hosts 与证书配置

**Files:**
- Modify: `deploy/windows/scripts/DatongDeploy.psm1`
- Modify: `deploy/windows/scripts/02-configure.ps1`

- [ ] **Step 1: 在共享模块实现项目标记块写入和删除**

```powershell
function Remove-DatongHostsEntry {
    param([string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts")
    if (-not (Test-Path $HostsPath)) { return }
    $content = [IO.File]::ReadAllText($HostsPath)
    $content = [regex]::Replace($content, '(?ms)^# DatongMap BEGIN\r?\n.*?^# DatongMap END\r?\n?', '')
    [IO.File]::WriteAllText($HostsPath, $content.TrimEnd() + "`r`n", [Text.Encoding]::ASCII)
}

function Set-DatongHostsEntry {
    param([string]$Address, [string]$HostName, [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts")
    Remove-DatongHostsEntry -HostsPath $HostsPath
    $content = if (Test-Path $HostsPath) { [IO.File]::ReadAllText($HostsPath).TrimEnd() } else { '' }
    $block = "# DatongMap BEGIN`r`n$Address $HostName`r`n# DatongMap END"
    [IO.File]::WriteAllText($HostsPath, (($content + "`r`n" + $block).TrimStart()) + "`r`n", [Text.Encoding]::ASCII)
}
```

导出两个函数。实现不得修改项目标记块之外的行。

- [ ] **Step 2: 固定配置名称并生成匹配证书**

在配置阶段使用 `$accessHostName = 'datong-hub-offline'`。证书主题设为该名称，SAN 依次写入别名、`localhost`、当前电脑名、`127.0.0.1` 和探测到的局域网 IPv4。生成后将同一证书导入 `LocalMachine\Root`，保存 `AccessHostName`，并调用：

```powershell
Set-DatongHostsEntry -Address '127.0.0.1' -HostName $accessHostName
```

旧配置仅在证书 DNS 名包含固定别名时复用，否则继续生成新证书。

- [ ] **Step 3: 运行测试并确认 GREEN**

```bash
pwsh -NoProfile -File deploy/windows/tests/DatongDeploy.Tests.ps1
```

Expected: 所有断言通过。

- [ ] **Step 4: 提交实现**

```bash
git add deploy/windows/scripts/DatongDeploy.psm1 deploy/windows/scripts/02-configure.ps1
git commit -m "feat: 配置 Windows 固定访问名和受信任证书"
```

### Task 3: 完成客户端、卸载、报告和教程闭环

**Files:**
- Modify: `deploy/windows/scripts/install-client-certificate.ps1`
- Modify: `deploy/windows/scripts/uninstall.ps1`
- Modify: `deploy/windows/scripts/05-verify.ps1`
- Modify: `deploy/windows/scripts/install.ps1`
- Modify: `deploy/windows/Windows一键部署教程.md`
- Modify: `deploy/windows/Windows一键部署教程.html`
- Modify: `deploy/windows/Windows部署操作手册.md`
- Modify: `deploy/windows/Windows部署操作手册.html`

- [ ] **Step 1: 实现客户端固定访问名**

客户端脚本默认 `$AccessHostName = 'datong-hub-offline'`，要求服务器 IPv4，通过 `[Net.IPAddress]::TryParse()` 校验，导入 `LocalMachine\Root`，调用 `Set-DatongHostsEntry -Address $ServerIp -HostName $AccessHostName`，最后打开固定 URL。

- [ ] **Step 2: 扩展卸载清理**

`-RemoveCertificates` 继续按保存的 Thumbprint 清理 `LocalMachine\My` 与 `LocalMachine\Root`；无论数据目录是否完整，都调用 `Remove-DatongHostsEntry`。其他 hosts 行保持原状。

- [ ] **Step 3: 更新验收与成功提示**

验收报告 URL 改为：

```powershell
Url = "https://$($settings.AccessHostName):$($settings.ServerPort)"
```

阶段五增加固定 URL 请求，失败组件为 `HOSTNAME` 或 `CERTIFICATE`，让报告明确指出名称解析或信任失败。

- [ ] **Step 4: 更新四份教程**

统一写明服务端安装自动完成本机信任；其他局域网电脑复制 `client` 和安装入口，输入服务器 IP；最终只访问 `https://datong-hub-offline:8012`。移除 `https://服务器IP:8012` 和服务端电脑名访问说明。

- [ ] **Step 5: 运行测试并提交**

```bash
pwsh -NoProfile -File deploy/windows/tests/DatongDeploy.Tests.ps1
git add deploy/windows
git commit -m "feat: 完成固定地址客户端和卸载闭环"
```

Expected: PowerShell 测试通过，提交只包含脚本、测试和教程，不包含 output ZIP。

### Task 4: 更新版本并构建离线包

**Files:**
- Modify: `deploy/windows/build-package.ps1`
- Generated: `deploy/windows/output/datong-map-windows-offline.zip`
- Generated: `deploy/windows/output/datong-map-windows-offline.zip.sha256`

- [ ] **Step 1: 更新构建元数据**

默认版本设为 `2026.07.23.1`，兼容状态保持“Windows 11 实机验证中、Server 2012 R2 兼容候选”，功能列表增加“固定可信访问名”。

- [ ] **Step 2: 运行全套本地验证**

```bash
pwsh -NoProfile -File deploy/windows/tests/DatongDeploy.Tests.ps1
cd frontend && node --test src/utils/*.test.mjs && npm run build
cd ../backend && mvn test && mvn -Pwindows-package -DskipTests package
```

Expected: PowerShell、前端 58 项、后端 68 项通过，JAR 构建成功。

- [ ] **Step 3: 使用现有兼容运行时种子构建 ZIP**

从上一版离线 ZIP 提取 runtime 和 lock 作为种子，执行：

```powershell
./deploy/windows/build-package.ps1 -Mode Offline -SkipBuild -PackageVersion 2026.07.23.1 -RuntimeSeedPackage <seed.zip>
```

Expected: 生成 ZIP 和 SHA，包内 JAR 含 `static/index.html`，全部运行组件哈希与 lock 一致。

- [ ] **Step 4: 校验并提交源文件**

校验 ZIP 可读、包内版本/清单/入口编码、JAR 哈希和 SHA 文件。提交构建脚本与教程版本文本；output 产物留在工作区交付。

### Task 5: 目标 Windows 11 彻底卸载和干净重装

**Files:**
- Evidence: `/tmp/datong-windows-validation/round-7-*`

- [ ] **Step 1: 记录清理前基线并取回现有报告**

记录 Windows、磁盘、DatongMap 和非 DatongMap 服务、8012/9011/9012/3306/3311 端口、项目证书、计划任务、防火墙和 hosts。

- [ ] **Step 2: 使用新版卸载脚本彻底清理项目**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\DatongMap\scripts\uninstall.ps1 -RemoveData -RemoveCertificates
```

确认三个 DatongMap 服务、任务、规则、证书、hosts 项和项目数据目录已清理；其他基线资源未变化。随后删除旧解压目录。

- [ ] **Step 3: 传输并校验新版包**

传输 ZIP/SHA，执行 `Get-FileHash -Algorithm SHA256`，解压到 `C:\DatongMap`。

- [ ] **Step 4: 一键安装并收集证据**

双击 `开始部署.cmd`，等待五阶段 PASS。若 STOP，先取回报告和诊断 ZIP，再清理本轮影响、修复包并重试。

- [ ] **Step 5: 验证固定地址和安全状态**

确认三项服务 Running、预期端口、健康接口和首页 200；检查证书主题/SAN/两个证书库/hosts；Edge 直接打开 `https://datong-hub-offline:8012`，确认页面正常且无证书告警。

- [ ] **Step 6: 更新兼容状态并最终构建**

实机通过后把清单状态更新为“Windows 11 实机通过、Server 2012 R2 兼容候选”，重新生成最终 ZIP/SHA 并复核哈希。

### Task 6: 合并本地 main 和最终复验

- [ ] **Step 1: 确认任务分支干净、测试通过**
- [ ] **Step 2: 在主工作区保留现有 `AGENTS.md` 修改并快进本地 `main`**
- [ ] **Step 3: 从本地 `main` 重新运行关键 PowerShell 与包清单检查**
- [ ] **Step 4: 报告最终 ZIP 绝对路径、SHA-256、实机证据路径和未执行的远程动作**

本轮不推送任务分支、不创建 PR、不部署生产服务器。
