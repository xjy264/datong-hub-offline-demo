# 大同示意图 Windows 部署操作手册

## 一、部署前准备

使用文件 `datong-map-windows-offline.zip`。服务器要求Windows Server 2019/2022 x64、至少4GB内存、建议8GB以上、系统盘至少20GB可用空间。准备已有MySQL的管理员账号和密码；该账号需要建库及创建账号权限。

将ZIP复制到服务器后校验随包SHA-256清单，再解压到：

```text
C:\DatongMap
```

部署过程排除Docker、WSL2、Hyper-V、Node.js和Maven。

## 二、开始部署

1. 打开 `C:\DatongMap`。
2. 双击 `开始部署.cmd`。
3. Windows弹出权限确认时选择“是”。
4. 向导依次执行五个阶段，每阶段成功后输入 `Y` 继续。

### 阶段01：只读环境检测

本阶段只读取系统、磁盘、端口和服务信息，生成 `C:\DatongMap\reports\environment-report.html`。

- 绿色PASS：继续。
- 黄色提醒：看清提示后继续。
- 红色STOP：停止操作，把整个 `reports` 目录发送给远程技术人员。

### 阶段02：确认配置

- 检测到一个运行中的MySQL 8.x时，按Enter复用。
- 检测到多个MySQL 8.x时，根据表格编号选择。
- 检测到旧MySQL、MariaDB或无兼容服务时，输入 `0` 使用项目独立MySQL。
- 备份目录优先选择非系统盘；直接按Enter采用向导推荐目录。
- 向导自动生成包含服务器名称和局域网IP的HTTPS证书。

### 阶段03：准备数据库

复用已有MySQL时，输入管理员账号密码。密码输入期间屏幕不显示字符，这是正常现象。凭据仅用于本次连接，项目保存的是自动生成的低权限业务账号。

如果同名数据库存在：空库继续初始化；检测到项目Flyway记录时先备份再升级；出现其他数据表时向导停止并保护原数据库。

### 阶段04：安装服务

向导安装：

- `DatongMapMinIO`
- `DatongMapBackend`
- 使用独立MySQL时额外安装 `DatongMapMySQL`
- 每日02:00备份计划任务
- Windows防火墙TCP 8012规则

### 阶段05：部署验收

成功后生成 `C:\DatongMap\reports\deployment-result.html`。报告应显示PASS，三个项目服务应为Running，首页和健康检查应为HTTP 200。

## 三、客户端电脑操作

1. 把服务端 `C:\DatongMap\client` 目录和 `客户端证书安装.cmd` 复制到客户端。
2. 双击 `客户端证书安装.cmd` 并允许管理员权限。
3. 输入服务端电脑名和局域网IP。
4. 浏览器自动打开 `https://服务器IP:8012`。

每台客户端只需执行一次证书安装。

## 四、日常维护

在管理员PowerShell中进入 `C:\DatongMap\scripts`：

```powershell
.\status.ps1
.\start.ps1
.\stop.ps1
.\restart.ps1
.\backup.ps1
```

自动备份保留7个日备份和4个周备份。恢复前执行：

```powershell
.\restore.ps1 -BackupPath "备份目录完整路径"
```

恢复脚本会先创建当前数据安全快照，再恢复MySQL和MinIO并重新验收。

## 五、异常处理

现场人员停在出现红色信息的阶段，然后运行：

```powershell
C:\DatongMap\scripts\collect-diagnostics.ps1
```

将生成的 `DatongMap-Diagnostics-时间.zip` 发送给远程技术人员。诊断包包含系统、端口、服务和最近日志，密码、JWT及证书私钥会被过滤。

## 六、卸载与回滚

默认卸载保留数据：

```powershell
C:\DatongMap\scripts\uninstall.ps1
```

复用的甲方MySQL服务保持原状。彻底清理项目数据需要明确执行：

```powershell
C:\DatongMap\scripts\uninstall.ps1 -RemoveData
```

执行彻底清理前先确认备份已复制到其他磁盘。

## 七、成功标志

- 环境报告为PASS。
- 部署验收报告为PASS。
- Windows重启后项目服务自动运行。
- 局域网客户端可以注册、登录、查看地图、编辑站点和上传图片。
- 手动备份生成MySQL SQL文件、MinIO目录和manifest文件。
