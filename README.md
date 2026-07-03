# 大同房建公寓段管辖示意图

服务端化版本：Vue 3 前端 + Spring Boot 后端 + MySQL 元数据 + MinIO 图片存储。

## 启动

```bash
cd deploy
cp .env.example .env
docker compose up -d --build
```

访问：`http://127.0.0.1:8012`

默认管理员：
- 手机号：`00000000000`
- 密码：`Admin12345@@`

## 本地开发

```bash
cd frontend && npm install && npm run dev
# 后端建议使用 deploy/docker-compose.yml 启 MySQL/Redis/MinIO 后再启动 Spring Boot
```

## 存储约定

- MySQL 只保存站点、目录、图片元数据。
- 图片文件保存到 MinIO bucket，默认 `datong-map`。
- 顶部“导入旧数据”支持原离线版导出的 JSON，会把 `dataUrl` 图片转存到 MinIO。
