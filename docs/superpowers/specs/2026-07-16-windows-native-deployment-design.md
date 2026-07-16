# Windows 原生部署设计

## 目标与边界

项目新增 Windows Server 2019/2022 x64 原生部署方式，供局域网内多台电脑通过浏览器访问。目标服务器不启用 WSL2、Hyper-V 或 Linux 容器。

现有 Linux Docker Compose 部署继续保留，Windows 支持作为并行部署目标；本轮只完成本地实现、自动化测试和 Windows 部署包构建验证，不修改当前生产服务器，不推送远程仓库。Redis 缓存分支继续独立开发，本轮不修改其缓存逻辑。

## 运行架构

Windows 服务器只开放一个业务入口：`https://SERVER_NAME:8012`。

- Vue 前端在构建阶段写入 Spring Boot JAR 的 `static` 资源目录。
- Spring Boot 在 8012 端口通过HTTPS同时提供前端页面、`/api` 和健康检查。
- 环境中已有兼容的MySQL 8.x服务时优先复用；未检测到兼容服务时，再使用部署包中的官方Windows noinstall x64版本创建独立服务。项目只创建自己的数据库和低权限账号，不修改已有数据库、用户、端口或服务启动方式。
- MinIO 使用官方 Windows x64 可执行程序，通过 WinSW 注册为 Windows 服务，只监听本机地址。
- Spring Boot JAR 通过 WinSW 注册为 Windows 服务，在 MinIO 和 MySQL 就绪后启动。
- 当前 `main` 中 Redis 尚未被业务代码调用；Windows profile 关闭 Redis 健康检查，不要求安装 Redis。以后合并 Redis 缓存分支时，通过独立的可选缓存配置接入 Windows 兼容的 Redis 协议服务。

## 前后端一体化

新增 Maven `windows-package` profile，把已生成的 `frontend/dist` 作为 `classpath:/static` 打入可执行 JAR。正常后端测试和现有 Docker 构建不启用该 profile，因此不改变 Linux 镜像构建流程。

后端安全配置公开登录页所需的静态资源和前端路由，但继续保护业务API。SPA路由回退把不属于 `/api`、`/actuator` 或静态文件的GET请求统一返回 `index.html`，从而支持Vue Router history路由刷新。API、图片、地图资源及不存在的接口仍按现有规则返回，不被前端回退逻辑吞掉。

Windows构建流程固定为：

1. `npm ci`、前端测试和 `npm run build`；
2. `mvn test`；
3. `mvn -Pwindows-package package`；
4. 组装 Windows ZIP，并验证 JAR 内存在 `static/index.html`。

## Windows 配置

部署根目录默认为 `C:\DatongMap`，可在安装时通过参数修改。运行数据使用 `C:\ProgramData\DatongMap`，包含配置、MinIO数据、日志和备份。

仓库只提交示例配置。配置阶段生成实际配置，并要求输入或自动生成：

- MySQL数据库账号和密码；
- MinIO访问账号和密码；
- JWT随机密钥；
- 监听端口，默认8012；
- 服务器PFX证书及密码，或由配置阶段生成局域网自签名证书；
- 备份目录和保留周期。

实际配置文件设置NTFS权限，仅Administrators和SYSTEM可读写。日志由WinSW按大小轮转。Windows防火墙只新增8012入站规则，MySQL、MinIO API和MinIO控制台保持本机访问。

生产配置继续启用项目已有的Secure Cookie和密钥强度检查。优先使用甲方内部CA签发的PFX证书；未提供证书时，配置阶段生成服务器证书并导出客户端信任证书及导入脚本。Spring Boot直接终止HTTPS，本轮不安装IIS。

## 分阶段部署与环境检测

部署流程不采用静默一键安装，而是拆分为可重复执行的阶段。每个阶段完成后生成中文结果，出现异常时停在当前阶段，不继续修改后续环境。

- `01-check-environment.ps1`：只读检查Windows版本、CPU架构、内存、磁盘、管理员权限、PowerShell版本、端口占用、服务列表、MySQL版本与位置、MinIO及Java环境，生成 `environment-report.html` 和 `environment-report.json`；
- `02-configure.ps1`：根据检测报告逐项确认部署路径、服务器名称、证书、MySQL选择和业务账号，不执行服务安装；
- `03-prepare-database.ps1`：连接已选MySQL服务并验证版本、端口和凭据，只创建 `datong_map` 数据库及 `datong` 业务账号；检测不到兼容服务时，明确提示使用包内MySQL并等待操作人员确认后创建独立 `DatongMapMySQL` 服务；
- `04-install-services.ps1`：安装MinIO和Spring Boot服务、设置目录ACL并创建8012防火墙规则；
- `05-verify.ps1`：检查Flyway迁移、首页、健康接口、端口绑定、注册登录及Windows服务状态，生成 `deployment-result.html`；
- `start.ps1`、`stop.ps1`、`restart.ps1`：按依赖顺序管理MinIO和后端服务；
- `status.ps1`：显示Windows服务状态并访问健康检查；
- `uninstall.ps1`：移除服务和防火墙规则，默认保留数据和备份；
- `backup.ps1`：通过 `mysqldump` 备份MySQL，通过MinIO Client镜像对象数据，同时保存脱敏配置清单；
- `restore.ps1`：停止业务服务、恢复MySQL与MinIO数据、重新启动并执行健康检查；
- `install-client-certificate.ps1`：在局域网客户端导入配置阶段生成的受信任证书；
- `collect-diagnostics.ps1`：收集脱敏配置、环境报告、端口、服务状态和最近日志，生成可交给远程开发人员分析的ZIP诊断包。

部署人员按《Windows部署操作手册》的编号逐步执行。每一步只要求复制一条命令、阅读绿色通过或红色停止结果，并把生成的HTML报告或诊断ZIP交给远程人员，无需现场修改代码、注册表或配置文件。

### 复用已有MySQL

检测脚本通过Windows服务、进程路径和监听端口发现MySQL实例，并列出服务名、状态、版本、可执行文件、配置文件和端口。检测结果按以下规则处理：

- 单个运行中的MySQL 8.x：默认推荐复用，但仍需提供有建库权限的账号完成连接测试；
- 多个MySQL实例：配置阶段要求按检测报告中的编号明确选择；
- MySQL 5.x、MariaDB或无法连接的实例：保留原服务并标记为不兼容，推荐安装包内独立MySQL；
- 3306被其他程序占用：包内MySQL自动选择3311并写入应用配置；
- 复用实例时不重启、不改 `my.ini`，卸载项目时也不移除该MySQL服务，仅删除项目服务和防火墙规则。

WinSW、MySQL、MinIO、MinIO Client和Temurin JRE等第三方二进制文件不直接提交仓库。构建脚本从明确版本下载并校验SHA-256，或通过参数使用甲方提供的离线文件，并把便携运行时组装进完整部署包。Windows服务器只接收构建完成的ZIP，不安装Node.js、Maven或系统级Java。

## CI与部署包

新增GitHub Actions Windows构建任务，在 `windows-latest` 上执行前端测试、后端测试、一体化JAR构建、PowerShell语法检查和ZIP组装，并上传精简部署包。手动触发任务可额外生成包含便携JRE、MySQL、MinIO、MinIO Client和WinSW的完整离线包。Linux现有CI继续运行，防止Windows支持破坏Docker部署。

部署包不包含真实密码、`deploy/.env`、生产数据库或图片数据。说明文档明确列出管理员PowerShell、服务器名称解析和客户端证书导入要求，并提供有网、离线两种安装路径。

## 错误处理与可恢复性

- 每个阶段采用失败即停止，并在输出及HTML报告中写明阶段、检查项、结论和下一条操作。
- 重复执行各阶段保持幂等：已有目录、业务数据库、服务和防火墙规则执行验证、更新或跳过。
- 数据库初始化失败时不启动后端。
- 已有MySQL检测和连接测试全程只读；进入数据库准备阶段后才创建项目数据库和业务账号。
- MinIO或后端健康检查失败时输出对应Windows服务日志位置。
- 卸载流程默认保留数据，彻底删除数据需要显式参数。
- 恢复前自动创建当前数据快照，恢复完成后验证Flyway、首页和健康接口。

## 测试与验收

- 后端全量测试、前端全量测试和生产构建通过。
- Windows profile配置加载测试通过，Redis服务缺席时健康检查不受影响。
- 一体化JAR包含前端资源，并能正确返回首页、前端history路由和API 404。
- PowerShell脚本通过解析检查，安装与卸载逻辑具有可重复执行测试。
- 在已有MySQL 8.x、多个MySQL实例、旧版MySQL、3306端口冲突和无MySQL五种环境报告样例上验证选择逻辑。
- 环境检测阶段不产生服务、数据库、防火墙或注册表变更。
- 诊断包不包含明文MySQL、MinIO、JWT或证书密码。
- GitHub Actions Windows任务成功生成ZIP。
- 在干净Windows Server测试机完成安装、重启、备份、删除测试数据、恢复和卸载演练。
- 同一局域网中的另一台电脑导入信任证书后，通过 `https://SERVER_NAME:8012` 完成注册、登录、地图查看、站点编辑和图片上传。

## 发布范围

实现阶段在 `codex/windows-native-deployment` 分支完成，验证后合并回本地 `main` 再启动本地Docker环境做回归测试。除非用户明确要求，暂不推送 `github/main`，也不部署现有Linux生产服务器。
