# Windows 离线包固定访问名与证书信任设计

## 背景

Windows 11 实机已完成三项服务、端口、健康接口和首页验收，但浏览器使用
`https://xjy:8012` 时出现 `NET::ERR_CERT_AUTHORITY_INVALID`。当前证书以目标机电脑名生成，
没有固定项目访问名；服务端也没有为固定名称建立本机解析和浏览器信任。

本次继续复用 Issue #3 和分支 `codex/issue-3-windows-one-click`，只修改 Windows 离线安装包。
不修改生产服务器，不推送远程分支，不创建 PR。

## 目标

- 所有安装统一使用 `https://datong-hub-offline:8012`。
- 服务端本机和完成客户端证书安装的局域网电脑直接打开该地址，不显示证书警告。
- 安装、重复安装和卸载都只维护本项目创建的证书及 hosts 记录。
- 目标电脑先彻底清理现有 DatongMap 安装，再使用新版离线包全新安装并完成实机验收。
- 目标电脑原有 MySQL、Docker、Java、证书和其他业务服务保持安装前状态。

## 方案

### 固定名称和名称解析

安装配置新增固定 `AccessHostName=datong-hub-offline`，成功报告、教程和客户端脚本只展示
`https://datong-hub-offline:8012`，不再把 Windows 电脑名或服务器 IP 作为最终访问地址。

服务端安装时在 hosts 文件中写入带项目边界标记的记录：

```text
# DatongMap BEGIN
127.0.0.1 datong-hub-offline
# DatongMap END
```

客户端证书安装脚本要求输入服务器局域网 IPv4，并用同一组边界标记写入
`<服务器IP> datong-hub-offline`。重复执行时替换项目块，不追加重复记录，也不触碰其他 hosts 内容。

### 证书

新生成证书的主题固定为 `CN=datong-hub-offline`。SAN 包含：

- `datong-hub-offline`
- `localhost`
- 当前 Windows 电脑名
- `127.0.0.1`
- 安装时检测到的全部有效局域网 IPv4

服务端将证书同时用于后端 HTTPS，并导入 `LocalMachine\Root` 作为本机受信任证书。
客户端脚本把随包导出的 `.cer` 导入 `LocalMachine\Root`。证书 Thumbprint 写入部署配置和独立所有权文件，
卸载时只按该 Thumbprint 从 `LocalMachine\My` 与 `LocalMachine\Root` 删除。

已有 DatongMap 配置如果证书不包含固定访问名，则不能复用旧证书；安装包重新生成证书并更新配置。

### 清理和重装闭环

目标机执行新版卸载入口的彻底清理模式：

- 停止并删除 `DatongMapBackend`、`DatongMapMinIO`、`DatongMapMySQL`；
- 删除 `DatongMap-DailyBackup`、`DatongMap-HTTPS-8012`；
- 删除本项目两个证书库中的证书和 DatongMap hosts 块；
- 删除 `C:\ProgramData\DatongMap` 和本轮解压目录；
- 清理前后对比服务、端口、证书、计划任务、防火墙和 hosts 基线。

清理仅处理项目独立 MySQL 服务。目标机的其他 MySQL 服务及其数据目录不进入本项目生命周期。

清理完成后传输新版 ZIP 和 SHA 文件，校验哈希，解压到 `C:\DatongMap`，双击 `开始部署.cmd`。
若安装失败，先取回报告和诊断 ZIP，再修复安装包、清理本轮影响、重新传包，直到完整验收通过。

### 验收

- 三个 DatongMap 服务均为 `Running`；
- MySQL、MinIO 只监听预期回环地址，8012 对外监听；
- `/actuator/health` 与首页均返回 200；
- Edge 直接访问 `https://datong-hub-offline:8012`，页面正常且没有证书告警；
- 证书主题、SAN、信任库和 hosts 项符合本设计；
- 部署报告、教程和客户端脚本不再把 `xjy`、电脑名或服务器 IP显示为最终访问地址；
- 原有 MySQL、Docker、Java 和其他业务服务与清理前基线一致；
- 最终 ZIP、SHA-256、清单、JAR 和 PowerShell 测试全部通过。

## 测试策略

先在 `DatongDeploy.Tests.ps1` 添加失败测试，覆盖默认固定名称、证书 SAN、服务端和客户端 hosts 幂等更新、
双证书库清理、报告及教程地址。确认测试因功能缺失而失败后，再实现最小修改。

随后运行 PowerShell 全套测试、前端测试和生产构建、后端测试与 JAR 构建、ZIP 完整性和哈希检查，
最后执行目标 Windows 11 的“彻底卸载—干净安装—浏览器无警告”实机闭环。

## 版本与交付

- 建议版本：`2026.07.23.1`
- 输出：`deploy/windows/output/datong-map-windows-offline.zip`
- 校验：`deploy/windows/output/datong-map-windows-offline.zip.sha256`
- 兼容状态：Windows 11 实机通过，Windows Server 2012 R2 兼容候选
