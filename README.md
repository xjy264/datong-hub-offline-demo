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

首次生产启动必须在 `.env` 中设置 `BOOTSTRAP_ADMIN_PHONE` 和 `BOOTSTRAP_ADMIN_PASSWORD`，系统会自动替换历史默认管理员密码。新注册账号需由超级管理员在“用户管理”页面审核。

## 本地开发

```bash
cd frontend && npm install && npm run dev
# 后端建议使用 deploy/docker-compose.yml 启 MySQL/Redis/MinIO 后再启动 Spring Boot
```

## 存储约定

- MySQL 只保存站点、目录、图片元数据。
- 图片文件保存到 MinIO bucket，默认 `datong-map`。
- 顶部“导入旧数据”支持原离线版导出的 JSON，会把 `dataUrl` 图片转存到 MinIO。
- 图片仅支持 JPEG、PNG、WebP；单张不超过 20MB，每批最多 20 张。

## 生产要求

- 登录入口必须位于 HTTPS 反向代理之后，并设置 `APP_PRODUCTION=true`、`AUTH_COOKIE_SECURE=true`。
- 使用 `deploy/backup.sh` 每日备份，`deploy/restore.sh <备份目录>` 恢复，`deploy/check-storage-consistency.sh` 检查数据库与 MinIO 引用。
- `deploy/install-backup-cron.sh` 安装每日备份任务；配置 `BACKUP_RCLONE_REMOTE` 后可同步到异机对象存储。
