# 大同房建公寓段管辖示意图

服务端化版本：Vue 3 前端 + Spring Boot 后端 + MySQL 元数据 + MinIO 图片存储。

## 启动

```bash
cd deploy
cp .env.example .env
# 为空的密码和密钥必须填写，可用 openssl rand -base64 36 生成
docker compose up -d --build
```

访问：`http://127.0.0.1:8012`

注册成功后无需审核，可直接登录使用；所有登录用户拥有相同的地图编辑权限。V9 会禁用仍使用公开默认密码的历史内置账号，请直接注册新账号。

## 本地开发

```bash
cd frontend && npm install && npm run dev
# 后端建议使用 deploy/docker-compose.yml 启 MySQL/Redis/MinIO 后再启动 Spring Boot
```

## Windows Server 原生部署

目标环境排除WSL2、Hyper-V和Linux容器时，使用完整Windows离线包。包内包含前后端一体化JAR、便携Java、备用MySQL、MinIO、Windows服务包装器、分阶段向导和中文手册。

部署人员解压到 `C:\DatongMap` 后双击 `开始部署.cmd`。向导先只读检测环境，兼容的已有MySQL 8.x优先复用，异常时生成HTML报告和脱敏诊断包。详细步骤见 `deploy/windows/Windows部署操作手册.md`。

## 存储约定

- MySQL 只保存站点、目录、图片元数据。
- 图片文件保存到 MinIO bucket，默认 `datong-map`。
- 顶部“导入旧数据”支持原离线版导出的 JSON，会把 `dataUrl` 图片转存到 MinIO。
- 图片仅支持 JPEG、PNG、WebP；单张不超过 50MB，每批最多 20 张。

## 生产要求

- 登录入口必须位于 HTTPS 反向代理之后，并设置 `APP_PRODUCTION=true`、`AUTH_COOKIE_SECURE=true`。
- 数据库、Redis、MinIO 和 JWT 密钥必须在生产 `.env` 中显式设置，不允许留空。
- 使用 `deploy/backup.sh` 每日备份，`deploy/restore.sh <备份目录>` 恢复，`deploy/check-storage-consistency.sh` 检查数据库与 MinIO 引用。
- `deploy/install-backup-cron.sh` 安装每日备份任务；配置 `BACKUP_RCLONE_REMOTE` 后可同步到异机对象存储。
