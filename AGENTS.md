# AGENTS.md

## 项目

大同房建公寓段管辖示意图：Vue 3 前端 + Spring Boot 后端 + MySQL + Redis + MinIO，Docker Compose 部署。

公开仓库：`https://github.com/xjy264/datong-hub-offline-demo`
生产地址：`http://82.156.194.174/`
生产服务器：`ubuntu@82.156.194.174`（已配置本机免密 SSH）

## 上线流程

上线分两步，顺序不能反：先更新远程 `main`，再登录服务器发布。

### 1. 更新远程 main 分支

```bash
git switch main
git status --short
git add <本次要上线的文件>
git commit -m "Describe deploy change"   # 没有改动就跳过
git push github main
```

本地保留两个远程：
- `github`：公开 GitHub 仓库，用来更新远程 `main`。
- `origin`：服务器上的旧 bare 仓库，别误当公开仓库用。

### 2. 在服务器上线

```bash
ssh ubuntu@82.156.194.174

APP=/home/ubuntu/datong-hub-offline-demo
REPO=https://github.com/xjy264/datong-hub-offline-demo.git

if [ ! -d "$APP/.git" ]; then
  git clone "$REPO" "$APP"
fi

cd "$APP"
git fetch origin main
git reset --hard origin/main

cd deploy
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:8012/ >/dev/null
```

最后从本机确认：

```bash
curl --noproxy '*' -I http://82.156.194.174/
```

## 约束

- 本地功能分支或独立 worktree 做完后，必须先合并回本地 `main`，再启动/验证给用户测试。
- 不在服务器手改业务代码；所有改动先进 GitHub `main`。
- 不提交 `deploy/.env`，只提交 `deploy/.env.example`。
