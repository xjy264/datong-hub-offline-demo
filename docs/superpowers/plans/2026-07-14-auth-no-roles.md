# Registration Without Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every valid registration immediately usable and remove the administrator/ordinary-user permission split.

**Architecture:** Keep authentication, account status, HTTPS, CSRF, password validation, and the existing database columns for compatibility. Remove the user-administration surface, always issue one editor authority to authenticated users, and migrate every active legacy account out of approval/admin states.

**Tech Stack:** Java 21, Spring Boot 3.3, Spring Security, Flyway/MySQL, Vue 3, Pinia, Vue Router, Node test runner, Docker Compose.

---

### Task 1: Register and log in immediately

**Files:**
- Modify: `backend/src/test/java/cn/datong/map/auth/AuthServiceTest.java`
- Modify: `backend/src/main/java/cn/datong/map/auth/AuthService.java`

- [ ] **Step 1: Change the registration test to require immediate login**

Rename the first test to `registerCreatesApprovedUserWhoCanLoginImmediately`, assert `approval_status = APPROVED`, call `service.login(...)` without a database update, and require only `MAP_EDIT`.

- [ ] **Step 2: Run the backend test and verify RED**

Run:

```bash
docker build --progress=plain --target build -t datong-auth-red backend
```

Expected: `AuthServiceTest` fails because registration still stores `PENDING` and login reports `账号待管理员审核`.

- [ ] **Step 3: Implement approved registration and one session permission**

Change the insert to:

```sql
VALUES (?, ?, ?, ?, 'ENABLED', 'APPROVED', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
```

Remove the dedicated `PENDING` login branch. Keep rejection for non-`APPROVED` legacy records and disabled accounts. Make `session(...)` always return `Set.of("MAP_EDIT")` and expose `isSuperAdmin = false` until Task 2 removes that compatibility field with its remaining consumers.

- [ ] **Step 4: Run the backend image test and verify GREEN**

Run the same Docker build. Expected: the complete backend suite passes.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/cn/datong/map/auth/AuthService.java backend/src/test/java/cn/datong/map/auth/AuthServiceTest.java
git commit -m "Allow immediate login after registration"
```

### Task 2: Remove administrator authorization and account-management code

**Files:**
- Modify: `backend/src/test/java/cn/datong/map/security/JwtAuthenticationFilterTest.java`
- Modify: `backend/src/main/java/cn/datong/map/security/JwtAuthenticationFilter.java`
- Modify: `backend/src/main/java/cn/datong/map/security/CurrentUser.java`
- Modify: `backend/src/main/java/cn/datong/map/auth/AuthUser.java`
- Modify: `backend/src/main/java/cn/datong/map/config/SecurityConfig.java`
- Delete: `backend/src/main/java/cn/datong/map/auth/AdminUserController.java`
- Delete: `backend/src/main/java/cn/datong/map/auth/AdminUserService.java`
- Delete: `backend/src/test/java/cn/datong/map/auth/AdminAuthorizationTest.java`
- Delete: `backend/src/test/java/cn/datong/map/auth/AdminUserServiceTest.java`
- Modify: `backend/src/test/java/cn/datong/map/auth/AuthTransportSecurityTest.java`

- [ ] **Step 1: Change the JWT test to require a single editor authority**

Rename the test to `loadsApprovedEnabledUserWithEditorAuthority`. Insert a row whose old admin flag is `1`, then assert the current user only contains the ID and authorities contain exactly `ROLE_EDITOR`.

- [ ] **Step 2: Run the backend build and verify RED**

Expected: the current principal still exposes `superAdmin` and receives `ROLE_ADMIN`.

- [ ] **Step 3: Simplify authentication and delete user administration**

Use these role-free records:

```java
public record CurrentUser(Long userId) {}
public record AuthUser(Long id, String username, String phone, String realName) {}
```

Query only `id`, always grant `ROLE_EDITOR`, remove the `/api/admin/**` matcher, delete the controller/service and their tests, and change the transport-security test fixture to `Set.of("MAP_EDIT")` with `isSuperAdmin = false`.

- [ ] **Step 4: Run the backend image build**

Expected: every backend test passes and no source reference to `ROLE_ADMIN`, `USER_ADMIN`, or `AdminUser` remains.

- [ ] **Step 5: Commit**

```bash
git add -A backend/src
git commit -m "Remove administrator permission split"
```

### Task 3: Remove bootstrap administrator and migrate legacy accounts

**Files:**
- Create: `backend/src/main/resources/db/migration/V9__unify_user_permissions.sql`
- Delete: `backend/src/main/java/cn/datong/map/auth/AdminBootstrap.java`
- Create: `backend/src/main/java/cn/datong/map/auth/ProductionSecurityGuard.java`
- Delete: `backend/src/test/java/cn/datong/map/auth/AdminBootstrapTest.java`
- Create: `backend/src/test/java/cn/datong/map/auth/ProductionSecurityGuardTest.java`
- Modify: `backend/src/main/resources/application.yml`
- Modify: `deploy/docker-compose.yml`
- Modify: `deploy/.env.example`
- Modify: `deploy/.env.production.example`
- Modify: `README.md`

- [ ] **Step 1: Add V9 migration**

```sql
UPDATE sys_user
SET approval_status = 'APPROVED', is_super_admin = 0, updated_at = CURRENT_TIMESTAMP
WHERE deleted = 0;

UPDATE sys_user
SET status = 'DISABLED', updated_at = CURRENT_TIMESTAMP
WHERE id = 1
  AND password = '$2y$10$JLYTEoDd2O7bkkA9W176He7tuLuAMKNQ4baclBgz02t4mD8FO3joW'
  AND deleted = 0;
```

- [ ] **Step 2: Remove bootstrap-admin runtime configuration**

Replace `AdminBootstrap` with a `ProductionSecurityGuard` that retains the existing `APP_PRODUCTION=true` plus `AUTH_COOKIE_SECURE=true` startup requirement but creates or modifies no user. Remove `app.bootstrap-admin` YAML, `BOOTSTRAP_ADMIN_PHONE`, and `BOOTSTRAP_ADMIN_PASSWORD` from Compose and both environment examples. Update README to state that registration is immediately usable while production still requires explicit database, MinIO, Redis, and JWT secrets.

- [ ] **Step 3: Verify migration from an empty database**

Build the backend image, start it against a temporary empty MySQL schema, and query `flyway_schema_history`.

Expected: 9 successful versioned migrations and every non-deleted `sys_user` row has `APPROVED/0`.

- [ ] **Step 4: Commit**

```bash
git add -A backend deploy README.md
git commit -m "Migrate existing users to unified access"
```

### Task 4: Remove the administrator frontend surface

**Files:**
- Create: `frontend/src/utils/unifiedAccess.test.mjs`
- Modify: `frontend/src/stores/auth.ts`
- Modify: `frontend/src/views/LayoutView.vue`
- Modify: `frontend/src/router/index.ts`
- Modify: `frontend/src/views/RegisterView.vue`
- Delete: `frontend/src/views/AdminUsersView.vue`

- [ ] **Step 1: Add a source-level regression test**

Create `frontend/src/utils/unifiedAccess.test.mjs` that reads the router, layout, auth store, and registration view and asserts they do not contain `/admin/users`, `canManageUsers`, `USER_ADMIN`, or `等待管理员审核`, while the registration view contains `注册成功，请登录`.

- [ ] **Step 2: Run the Node test and verify RED**

```bash
node --test src/utils/unifiedAccess.test.mjs
```

Expected: failures report the existing administration route and approval text.

- [ ] **Step 3: Remove the route, getter, button, page, and approval copy**

Keep the existing register request and redirect, but change its explanatory and success text to immediate-use wording.

- [ ] **Step 4: Run frontend verification**

```bash
node --test src/**/*.test.mjs
npm run build
npm audit --audit-level=high
```

Expected: all tests pass, build succeeds, and audit reports zero vulnerabilities.

- [ ] **Step 5: Commit**

```bash
git add -A frontend/src
git commit -m "Remove user administration interface"
```

### Task 5: End-to-end verification and local-main integration

**Files:**
- Verify: all files changed above

- [ ] **Step 1: Run static and build checks**

```bash
git diff --check main...HEAD
docker compose --env-file deploy/.env -f deploy/docker-compose.yml config --quiet
docker build --progress=plain --target build -t datong-auth-final backend
cd frontend && node --test src/**/*.test.mjs && npm run build && npm audit --audit-level=high
```

- [ ] **Step 2: Merge the branch into local main**

From the primary checkout, merge `codex/auth-no-roles` into `main` without pushing.

- [ ] **Step 3: Rebuild and start the merged local stack**

```bash
cd deploy
docker compose up -d --build
docker compose ps
```

- [ ] **Step 4: Verify the real registration flow**

Register a unique phone through `/api/auth/register`, immediately log in through `/api/auth/login`, and call `/api/map`. Expected responses: `200`, `200`, `200`; session permissions are exactly `["MAP_EDIT"]`.

- [ ] **Step 5: Clean up test data and the merged worktree**

Delete only the generated local verification account, remove `.worktrees/auth-no-roles`, delete `codex/auth-no-roles`, and preserve `.worktrees/redis-performance-cache`.

- [ ] **Step 6: Report**

Report local commit, test counts, Docker health, local URL, and explicitly state that GitHub and production were not updated.
