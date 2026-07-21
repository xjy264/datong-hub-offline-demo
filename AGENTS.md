# AGENTS.md

## 项目

大同房建公寓段管辖示意图：Vue 3 前端 + Spring Boot 后端 + MySQL + Redis + MinIO，Docker Compose 部署。

公开仓库：`https://github.com/xjy264/datong-hub-offline-demo`
生产地址：`http://154.8.197.66:8012/`
生产服务器：`ubuntu@154.8.197.66`（已配置本机免密 SSH）

## 长期分支职责

- `main`：稳定生产版。只接收通过预发验收的 `pre` 晋级 PR；生产服务器只部署远程 `main`。
- `pre`：预发布候选版。只接收通过集成测试的 `staging` 晋级 PR，用于业务验收和发布演练。
- `staging`：开发集成测试版。接收日常任务分支 PR，允许汇总多个尚未发布的功能和缺陷修复。
- 标准晋级方向固定为 `任务分支 → staging → pre → main → 生产服务器`，禁止反向替代或跳级发布。
- `main`、`pre`、`staging` 都是受控长期分支，禁止直接推送、强推、删除或绕过 PR。

## GitHub Issue 与 PR 流程

- 所有需要纳入版本库的任务，开始实现前必须先创建或确认对应的 GitHub Issue，并在 Issue 中写明背景、目标与验收标准。纯探索、只读分析且没有版本改动时可跳过。
- 同一 PR 范围内的增量实现、Review 修复和补充修改继续使用原 Issue，不重复创建。
- 日常任务默认从最新 `staging` 创建 `codex/` 任务分支；业务代码、功能和缺陷修复优先放在独立 worktree 中完成。
- 任务完成并通过相关验证后，提交并推送任务分支，创建以 `staging` 为目标的 PR；不再把任务分支先合并到本地 `main`。
- 任务 PR 使用 `Closes #<issue-number>` 关联 Issue；PR 成功合并到 `staging` 后，由 GitHub Actions 自动关闭对应 Issue。
- `staging` 集成测试通过后，创建 `staging → pre` 晋级 PR；`pre` 业务验收通过后，创建 `pre → main` 发布 PR。
- 晋级 PR 必须列出本次发布包含的 Issue，保留从开发、预发到稳定版的追踪记录；相关 Issue 已在任务 PR 合入 `staging` 时关闭。
- PR 标题、正文和评论默认使用中文。PR 描述必须包含改动摘要、影响模块、验证方式与结果；涉及 UI 时附浏览器验证说明或截图。
- 每次 Review 以及根据 Review 完成的修改，都要在对应 PR 留言记录范围、结论、提交和验证结果。
- Agent 的交付边界止于创建或更新 PR。禁止自行合并 PR、开启自动合并、绕过 Review 或分支保护；PR 由用户或仓库维护者人工合并。

### GitHub Label 规范

- 标签按“优先级 + 类型 + 状态 + 范围”组合使用，禁止临时创建同义、拼写变体或没有说明的标签。
- 每个 Issue 必须且只能设置一个优先级标签，数字越大越紧急：
  - `:broom: p1-chore`：不改变业务行为的维护、文档或流程工作。
  - `:cake: p2-nice-to-have`：不影响核心功能的体验改进或边缘需求。
  - `:hammer: p3-minor-bug`：仅影响特定场景或存在绕过方式的一般缺陷。
  - `:exclamation: p4-important`：显著影响核心流程、性能或既定行为的重要问题。
  - `:fire: p5-urgent`：大范围阻断、数据丢失或安全事故。
- 类型标签按需设置至少一个：`:lady_beetle: bug`、`:sparkles: feature request`、`need documentation`、`dependencies`、`security`、`epic`。
- 状态标签按当前协作状态增删：`has PR`、`has workaround`、`need discussion`、`need guidance`、`need more info`、`need test`、`ready for review`、`ready to merge`、`wait changes`、`🛑 on hold`、`duplicate`、`can't reproduce`、`invalid`、`wontfix`、`breaking change`、`regression`、`good first issue`、`help wanted`。
- 范围标签使用 `scope: <module>` 格式；当前允许：`scope: frontend`、`scope: backend`、`scope: map`、`scope: station`、`scope: workshop`、`scope: auth`、`scope: storage`、`scope: cache`、`scope: infra`、`scope: windows`、`scope: deployment`、`scope: docs`。
- 新建 Issue 或 PR 时必须设置适用标签；Issue 状态变化时同步维护 `has PR`、`ready for review`、`ready to merge`、`wait changes` 等状态标签。
- 新增标签前先确认现有体系无法表达该语义；确需新增时，同步更新本节和 GitHub 仓库标签说明。

## CI 与分支保护

- `codex/**`、`staging`、`pre`、`main` 的 push，以及指向三个长期分支的 PR，都必须运行 GitHub Actions CI。
- PR 成功合并到任一长期分支后，`close-linked-issues.yml` 必须处理正文中的 `Closes #<issue-number>`，立即关闭仍处于开启状态的对应 Issue。
- `main`、`pre`、`staging` 必须启用分支保护：只允许通过 PR 更新，并要求相关 CI 检查通过。
- 晋级 PR 出现冲突时，先报告冲突文件和影响，再在来源分支处理；禁止直接在目标长期分支提交冲突修复。

## 上线流程

上线顺序固定为：任务 PR 进入 `staging`、晋级 `pre` 并验收、晋级远程 `main`、最后登录服务器发布。

### 1. 通过 PR 更新远程 main

```bash
# 集成测试通过后创建 staging -> pre PR
git fetch github staging pre main

# 预发验收通过后创建 pre -> main PR
# 等待用户或仓库维护者人工合并，并确认 github/main 已包含发布提交
git fetch github main
git log -1 --oneline github/main
```

本地发布只认 `github`：公开 GitHub 仓库，用来推送任务分支、创建 PR 和确认远程长期分支。本地若仍存在 `origin` 等旧远程，一律不用于上线或推送。禁止执行 `git push github main`、`git push github pre` 或 `git push github staging`。

### 2. 在服务器上线

```bash
ssh ubuntu@154.8.197.66

APP=/home/ubuntu/datong-hub-offline-demo
REPO=https://github.com/xjy264/datong-hub-offline-demo.git

if [ ! -d "$APP/.git" ]; then
  git clone "$REPO" "$APP"
fi

cd "$APP"
git fetch origin main
git reset --hard origin/main

cd deploy
cp -n .env.production.example .env
if grep -q '^FRONTEND_PORT=' .env; then
  sed -i 's/^FRONTEND_PORT=.*/FRONTEND_PORT=8012/' .env
else
  printf '\nFRONTEND_PORT=8012\n' >> .env
fi
sed -i '/^COMPOSE_PROFILES=/d;/^FRONTEND_LEGACY_PORT=/d' .env
docker rm -f datong-map-frontend-legacy 2>/dev/null || true
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:8012/ >/dev/null
```

最后从本机确认：

```bash
curl --noproxy '*' -I http://154.8.197.66:8012/
```

## 约束

- 不在服务器手改业务代码；所有上线改动必须依次通过 `staging`、`pre` 和 `main` 的 PR。
- 不提交 `deploy/.env`，只提交环境变量示例文件。
- 未经用户明确要求，不执行生产发布。
