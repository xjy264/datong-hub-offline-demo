# 大同示意图 Windows 一键部署教程

> 适用对象：第一次接触服务器部署的现场人员。部署过程中只需要解压、双击和确认一次管理员权限。
>
> 包版本：2026.07.23.3；兼容状态：Windows 11 实机验证中、Server 2012 R2 兼容候选。

## 一、部署前准备

1. 准备 Windows Server 2012 R2（系统版本 6.3）或更高版本的 x64 服务器，PowerShell 至少为 4.0。
2. 确认系统盘至少有 20GB 可用空间，内存至少 4GB、建议 8GB。
3. 把 `datong-map-windows-offline.zip` 复制到服务器。
4. 在 `C:` 盘新建文件夹 `C:\DatongMap`。
5. 右键 ZIP，选择“全部解压缩”，目标文件夹填写 `C:\DatongMap`。

解压完成后，应直接看到：

```text
C:\DatongMap\开始部署.cmd
C:\DatongMap\完整重装.cmd
C:\DatongMap\app
C:\DatongMap\runtime
C:\DatongMap\scripts
```

如果看到 `C:\DatongMap\datong-map-windows\开始部署.cmd`，把 `datong-map-windows` 里面的全部内容移动到 `C:\DatongMap`。

## 二、开始一键部署

1. 双击 `C:\DatongMap\开始部署.cmd`。
2. 出现“是否允许此应用对设备进行更改”时，点击“是”。
3. 保持黑色部署窗口打开，不要关机或重启。
4. 系统将自动执行五个阶段，无需输入 MySQL 账号或密码：
   - `[1/5]` 检查服务器和离线组件；
   - `[2/5]` 生成目录、配置和 HTTPS 证书；
   - `[3/5]` 安装项目独立 MySQL；
   - `[4/5]` 安装 MinIO、后端服务、防火墙和备份任务；
   - `[5/5]` 检查服务、健康接口和首页。

服务器上已有的 MySQL 会保持原状。项目 MySQL 优先使用 `3306`；端口已被占用时自动使用 `3311`。

## 三、已有项目需要完整重装

只有明确要清空旧项目时才执行下面步骤：

1. 把最新版 ZIP 重新解压到 `C:\DatongMap`，出现同名文件时选择全部替换。
2. 双击 `C:\DatongMap\完整重装.cmd`。
3. 管理员权限选择“是”，等待清理和五阶段安装自动完成。
4. 浏览器自动打开结果页；看到绿色 `PASS` 才结束。

完整重装会先删除本项目的三个服务、MySQL/MinIO 数据、配置、证书、hosts 标记块、备份计划任务、防火墙规则、旧客户端证书、旧报告以及项目自动生成的历史备份，再按全新环境安装。服务器原有 MySQL、Docker、Java 和其他业务服务保持原状。

**完整重装后，旧地图、图片、账号、项目数据库和项目自动备份均不再保留。需要留存时，先手工复制到名称不是 `DatongMapBackups` 的其他目录。**

## 四、怎么看部署结果

### 绿色 PASS

部署成功后浏览器自动打开结果页，页面显示 `PASS`。确认以下项目：

- `DatongMapMySQL`、`DatongMapMinIO`、`DatongMapBackend` 均为 Running；
- 健康检查为 HTTP 200；
- 前端首页为 HTTP 200；
- 页面给出固定访问地址 `https://datong-hub-offline:8012`，服务端本机会自动信任证书。

### 红色 STOP

看到 `STOP` 时停止操作，不要反复删除目录或重装。结果页会明确显示：

- 第几个阶段失败；
- 哪个组件失败；
- `WIN-xx-xxx` 错误编号；
- 通俗原因和下一步；
- 诊断 ZIP 的完整路径。

点击“复制反馈信息”，把文字和页面列出的 `DatongMap-Diagnostics-时间.zip` 一起发送给技术人员。

## 五、客户端电脑访问

1. 从服务器复制 `C:\DatongMap\client` 文件夹和 `客户端证书安装.cmd` 到客户端电脑。
2. 在客户端双击 `客户端证书安装.cmd`，管理员权限选择“是”。
3. 按提示输入服务器局域网 IPv4 地址，脚本会自动安装项目证书和配置固定名称。
4. 浏览器打开 `https://datong-hub-offline:8012` 后即可注册、登录和使用。

每台客户端只需安装一次证书。

## 六、日常反馈材料

- 部署状态：`C:\DatongMap\reports\deployment-status.html`
- 部署日志：`C:\DatongMap\reports\deployment.log`
- 环境报告：`C:\DatongMap\reports\environment-report.html`
- 诊断包：`C:\DatongMap\DatongMap-Diagnostics-时间.zip`

以上材料会过滤数据库密码、JWT、MinIO 密钥和证书密码。
