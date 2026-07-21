# 50MB 图片上传上限 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 JPEG、PNG、WebP 单张上传上限从 20MB 调整为 50MB，并在现有 100MB 请求限制下安全拆分大图批次。

**Architecture:** 前端上传工具统一负责单张校验和按 20 张/90MB 双重拆批，Pinia 上传流程继续逐批发送。后端 `UploadPolicy` 保持独立的 50MB 信任边界校验，Spring 单次请求上限继续为 100MB。

**Tech Stack:** Vue 3、TypeScript、Node test runner、Spring Boot 3.3、JUnit 5、AssertJ、Mockito、Docker Compose

---

### Task 1: 前端 50MB 校验与安全拆批

**Files:**
- Modify: `frontend/src/utils/uploadBatches.test.mjs`
- Modify: `frontend/src/utils/uploadBatches.ts`
- Modify: `frontend/src/views/StationView.vue`

- [ ] **Step 1: 写入失败测试**

将测试改为验证 50MB 边界、超过 50MB 的错误提示，以及 45MB、45MB、10MB 被拆成 `[2, 1]`：

```js
test('accepts images up to fifty megabytes and rejects larger files', () => {
  assert.doesNotThrow(() => splitUploadBatches([{ size: 50 * 1024 * 1024 }]))
  assert.throws(() => splitUploadBatches([{ size: 50 * 1024 * 1024 + 1 }]), /单张图片不能超过50MB/)
})

test('splits batches before their total size exceeds ninety megabytes', () => {
  const mb = 1024 * 1024
  assert.deepEqual(splitUploadBatches([{ size: 45 * mb }, { size: 45 * mb }, { size: 10 * mb }]).map((batch) => batch.length), [2, 1])
})
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `cd frontend && node --test src/utils/uploadBatches.test.mjs`

Expected: FAIL，现有实现仍拒绝 50MB 文件，并且不会按 90MB 总大小拆批。

- [ ] **Step 3: 写入最小实现**

在 `uploadBatches.ts` 中使用以下边界，并在顺序遍历时遇到数量或总大小边界就提交当前批次：

```ts
const MAX_BATCH_SIZE = 20
const MAX_FILE_SIZE = 50 * 1024 * 1024
const MAX_BATCH_BYTES = 90 * 1024 * 1024
```

同时将 `StationView.vue` 的错误匹配从 `20MB` 更新为 `50MB`。

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `cd frontend && node --test src/utils/uploadBatches.test.mjs`

Expected: 4 tests pass, 0 failures。

- [ ] **Step 5: 提交前端改动**

```bash
git add frontend/src/utils/uploadBatches.ts frontend/src/utils/uploadBatches.test.mjs frontend/src/views/StationView.vue
git commit -m "feat: 支持 50MB 图片安全分批上传"
```

### Task 2: 后端 50MB 信任边界

**Files:**
- Modify: `backend/src/test/java/cn/datong/map/storage/UploadPolicyTest.java`
- Modify: `backend/src/main/java/cn/datong/map/storage/UploadPolicy.java`

- [ ] **Step 1: 写入失败测试**

使用 Mockito 构造只提供大小、类型和头部流的 `MultipartFile`，验证正好 50MB 通过、50MB+1 字节返回“单张图片不能超过50MB”。

```java
MultipartFile image = mock(MultipartFile.class);
when(image.getSize()).thenReturn(50L * 1024 * 1024);
when(image.getContentType()).thenReturn("image/jpeg");
when(image.getInputStream()).thenReturn(new ByteArrayInputStream(new byte[]{(byte) 0xff, (byte) 0xd8, (byte) 0xff}));
assertThat(policy.validateImage(image)).isEqualTo("image/jpeg");
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `cd backend && JAVA_HOME=$(/usr/libexec/java_home -v 21) PATH="$JAVA_HOME/bin:$PATH" mvn -s /tmp/codex-maven-central-settings.xml -Dtest=UploadPolicyTest test`

Expected: FAIL，现有后端上限仍为 20MB。

- [ ] **Step 3: 写入最小实现**

```java
public static final long MAX_IMAGE_BYTES = 50L * 1024 * 1024;
```

并将后端错误消息更新为“单张图片不能超过50MB”。

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `cd backend && JAVA_HOME=$(/usr/libexec/java_home -v 21) PATH="$JAVA_HOME/bin:$PATH" mvn -s /tmp/codex-maven-central-settings.xml -Dtest=UploadPolicyTest test`

Expected: 相关测试全部通过。

- [ ] **Step 5: 提交后端改动**

```bash
git add backend/src/main/java/cn/datong/map/storage/UploadPolicy.java backend/src/test/java/cn/datong/map/storage/UploadPolicyTest.java
git commit -m "feat: 将后端图片上限调整为 50MB"
```

### Task 3: 运行配置、文档和完整验证

**Files:**
- Modify: `backend/src/main/resources/application.yml`
- Modify: `deploy/docker-compose.yml`
- Modify: `README.md`

- [ ] **Step 1: 同步配置与文档**

将 Spring 默认 `MAX_FILE_SIZE`、Compose `MAX_FILE_SIZE` 和 README 单张说明统一为 `50MB`，保留 `MAX_REQUEST_SIZE: 100MB`。

- [ ] **Step 2: 检查残留值**

Run: `rg -n "20MB|20 MB|20L \\* 1024 \\* 1024" frontend backend deploy README.md`

Expected: 仅保留“每批最多 20 张”这类数量说明，没有单张 20MB 限制。

- [ ] **Step 3: 运行完整验证**

```bash
cd frontend && node --test src/utils/*.test.mjs && npm run build
cd ../backend && JAVA_HOME=$(/usr/libexec/java_home -v 21) PATH="$JAVA_HOME/bin:$PATH" mvn -s /tmp/codex-maven-central-settings.xml test
cd .. && git diff --check
```

Expected: 前端测试零失败、生产构建成功、后端 66 个以上测试零失败、`git diff --check` 无输出。

- [ ] **Step 4: 提交配置与文档**

```bash
git add backend/src/main/resources/application.yml deploy/docker-compose.yml README.md
git commit -m "docs: 同步 50MB 图片上传限制"
```

- [ ] **Step 5: 合并到本地 main**

在原始工作区保留用户已有 `AGENTS.md` 修改，使用快进合并将任务分支纳入本地 `main`，随后重新运行上传工具测试与仓库状态检查。

