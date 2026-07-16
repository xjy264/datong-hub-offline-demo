# Windows Native Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a staged, diagnosable Windows Server deployment package that embeds the Vue frontend in Spring Boot, reuses a compatible existing MySQL service when available, and runs without WSL2, Hyper-V, or Linux containers.

**Architecture:** A Maven profile packages `frontend/dist` into the backend JAR and explicit SPA routes serve the Vue shell while API security stays unchanged. PowerShell 5.1-compatible scripts perform a read-only preflight, persist a reviewed deployment selection, prepare either an existing or bundled MySQL instance, install MinIO/backend Windows services through WinSW, and generate HTML/ZIP diagnostics for non-specialist operators.

**Tech Stack:** Java 21, Spring Boot 3.3, Vue 3/Vite, Maven, PowerShell 5.1, MySQL 8.x, MinIO for Windows, WinSW, GitHub Actions Windows runner.

---

### Task 1: Package and serve the Vue application from Spring Boot

**Files:**
- Modify: `backend/pom.xml`
- Modify: `backend/src/main/java/cn/datong/map/config/SecurityConfig.java`
- Create: `backend/src/main/java/cn/datong/map/config/SpaController.java`
- Create: `backend/src/test/java/cn/datong/map/config/SpaControllerTest.java`

- [ ] **Step 1: Write a failing controller test**

Create a standalone MockMvc test asserting `/login`, `/maps`, `/map`, `/workshops/12`, and both station route shapes forward to `/index.html`, while `/api/missing` is not mapped by the SPA controller.

- [ ] **Step 2: Run the targeted test and confirm failure**

Run: `cd backend && mvn -Dtest=SpaControllerTest test`

Expected: compilation failure because `SpaController` does not exist.

- [ ] **Step 3: Add explicit SPA routes**

Implement a normal `@Controller` whose `@GetMapping` list contains only the known Vue paths and whose handler returns `"forward:/index.html"`. Do not add a wildcard mapping that could swallow API or missing-resource responses.

- [ ] **Step 4: Permit only the frontend shell and assets in Spring Security**

Add these request matchers before `.anyRequest().authenticated()`:

```java
.requestMatchers(
    "/", "/index.html", "/favicon.ico", "/assets/**",
    "/login", "/register", "/maps", "/map",
    "/workshops/**", "/stations/**"
).permitAll()
```

API matchers remain unchanged, so only login/register are public APIs.

- [ ] **Step 5: Add the Maven packaging profile**

Add a `windows-package` profile that keeps `src/main/resources` and adds `../frontend/dist` with `targetPath` `static`. The default Maven build must remain independent from frontend files.

- [ ] **Step 6: Run tests and prove the JAR contains the frontend**

Run:

```bash
cd frontend && npm run build
cd ../backend && mvn -Dtest=SpaControllerTest test
mvn -Pwindows-package -DskipTests package
jar tf target/datong-map-server-0.1.0.jar | grep 'BOOT-INF/classes/static/index.html'
```

Expected: targeted test passes and the final command prints the embedded `index.html` path.

- [ ] **Step 7: Commit**

```bash
git add backend/pom.xml backend/src/main/java/cn/datong/map/config/SecurityConfig.java \
  backend/src/main/java/cn/datong/map/config/SpaController.java \
  backend/src/test/java/cn/datong/map/config/SpaControllerTest.java
git commit -m "Add Windows single-port web package"
```

### Task 2: Add the Windows Spring profile

**Files:**
- Create: `backend/src/main/resources/application-windows.yml`
- Create: `backend/src/test/java/cn/datong/map/config/WindowsProfileTest.java`

- [ ] **Step 1: Write a profile configuration test**

Use `ApplicationContextRunner` with the `windows` profile and fixed test-only datasource, MinIO, JWT and SSL values. Assert `server.port=8012`, `server.ssl.enabled=true`, `app.production=true`, `app.auth.cookie-secure=true`, and `management.health.redis.enabled=false`.

- [ ] **Step 2: Run the test and confirm the profile is missing**

Run: `cd backend && mvn -Dtest=WindowsProfileTest test`

Expected: assertions fail because Windows profile properties are absent.

- [ ] **Step 3: Add `application-windows.yml`**

Use environment-backed properties for MySQL, MinIO, JWT, TLS keystore, port and log path. Set production and Secure Cookie to true, bind internal dependencies to localhost defaults, and disable only the Redis health contributor.

- [ ] **Step 4: Run the profile and production guard tests**

Run: `cd backend && mvn -Dtest=WindowsProfileTest,ProductionSecurityGuardTest test`

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/resources/application-windows.yml \
  backend/src/test/java/cn/datong/map/config/WindowsProfileTest.java
git commit -m "Add native Windows application profile"
```

### Task 3: Build the reusable PowerShell deployment module and read-only preflight

**Files:**
- Create: `deploy/windows/scripts/DatongDeploy.psm1`
- Create: `deploy/windows/scripts/01-check-environment.ps1`
- Create: `deploy/windows/tests/DatongDeploy.Tests.ps1`
- Create: `deploy/windows/开始环境检测.cmd`

- [ ] **Step 1: Add failing pure-function tests**

Tests construct synthetic MySQL candidates and assert:

```powershell
Assert-Equal 'Reuse' (Select-MySqlPlan @($mysql8) $false).Action
Assert-Equal 'Select' (Select-MySqlPlan @($mysql8a, $mysql8b) $false).Action
Assert-Equal 3311 (Select-MySqlPlan @() $true).Port
Assert-Equal 'Bundled' (Select-MySqlPlan @($mysql57) $false).Action
Assert-False ((Protect-DiagnosticText 'JWT_SECRET=secret').Contains('secret'))
```

- [ ] **Step 2: Run tests on a Windows PowerShell runner and confirm missing functions**

Run: `powershell -NoProfile -File deploy/windows/tests/DatongDeploy.Tests.ps1`

Expected: failure because `DatongDeploy.psm1` has not defined the functions.

- [ ] **Step 3: Implement the shared module**

Export functions for administrator detection, port ownership, MySQL service discovery, version compatibility, deterministic plan selection, HTML/JSON report writing, settings loading, secret redaction and clear stage output. Keep discovery functions read-only and accept injected candidate arrays in selection functions for testing.

- [ ] **Step 4: Implement the preflight script**

Collect OS/version/architecture, RAM, fixed-drive free space, PowerShell version, 8012/3306/3311/9011/9012 port owners, MySQL services, existing Datong services and package runtime files. Write `reports/environment-report.json` and `reports/environment-report.html`; return exit code 2 only for blockers such as unsupported architecture, low disk or occupied business port.

- [ ] **Step 5: Add the operator wrapper**

`开始环境检测.cmd` runs only the preflight through Windows PowerShell with `-ExecutionPolicy Bypass`, preserves the console, and opens the HTML report. It performs no installation.

- [ ] **Step 6: Parse and test every script**

Run:

```powershell
powershell -NoProfile -Command "$errors=@(); Get-ChildItem deploy/windows -Recurse -Filter *.ps1 | ForEach-Object { [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$errors) }; if($errors){$errors;exit 1}"
powershell -NoProfile -File deploy/windows/tests/DatongDeploy.Tests.ps1
```

Expected: parser has zero errors and all assertions pass.

- [ ] **Step 7: Commit**

```bash
git add deploy/windows/scripts/DatongDeploy.psm1 deploy/windows/scripts/01-check-environment.ps1 \
  deploy/windows/tests/DatongDeploy.Tests.ps1 deploy/windows/开始环境检测.cmd
git commit -m "Add read-only Windows environment preflight"
```

### Task 4: Add staged configuration and MySQL reuse

**Files:**
- Create: `deploy/windows/scripts/02-configure.ps1`
- Create: `deploy/windows/scripts/03-prepare-database.ps1`
- Create: `deploy/windows/config/application-windows.example.properties`

- [ ] **Step 1: Extend tests for MySQL selection and SQL escaping**

Assert one compatible service is recommended, multiple services require an explicit ID, old versions choose the bundled path, and generated application passwords contain only hexadecimal characters.

- [ ] **Step 2: Implement reviewed configuration**

Require a fresh environment report. Present the detected MySQL recommendation, allow selection by report ID, prompt for the server hostname and optional PFX, generate hex JWT/MinIO/database secrets, and write `state/deployment-settings.json`. Apply an ACL limited to SYSTEM and Administrators.

- [ ] **Step 3: Implement existing-MySQL preparation**

Locate `mysql.exe` from the selected service installation, prompt for an administrative account/password without persisting it, set `MYSQL_PWD` only for the child process, test `SELECT VERSION()`, then execute idempotent SQL that creates only the configured database and localhost business user with privileges scoped to that database.

- [ ] **Step 4: Implement bundled-MySQL preparation**

Require `runtime/mysql/bin/mysqld.exe`; choose 3311 when 3306 has an owner; generate `my.ini`, initialize an empty data directory, register `DatongMapMySQL`, start it, create the app database/user, and record `OwnsMySqlService=true`. Existing services remain untouched.

- [ ] **Step 5: Generate Spring properties and certificate**

Write `state/application-windows.properties` with local MySQL/MinIO URLs, production/Secure Cookie, TLS PFX and logging properties. Use a supplied PFX or `New-SelfSignedCertificate`, export `client/datong-map.cer`, and never write certificate/JWT/database secrets into reports.

- [ ] **Step 6: Run tests and parser validation**

Expected: all PowerShell assertions pass; scripts parse under Windows PowerShell 5.1.

- [ ] **Step 7: Commit**

```bash
git add deploy/windows/scripts/02-configure.ps1 deploy/windows/scripts/03-prepare-database.ps1 \
  deploy/windows/config/application-windows.example.properties deploy/windows/tests/DatongDeploy.Tests.ps1
git commit -m "Add staged MySQL-aware Windows configuration"
```

### Task 5: Install and verify Windows services

**Files:**
- Create: `deploy/windows/scripts/04-install-services.ps1`
- Create: `deploy/windows/scripts/05-verify.ps1`
- Create: `deploy/windows/service/minio.xml.template`
- Create: `deploy/windows/service/backend.xml.template`
- Create: `deploy/windows/scripts/install-client-certificate.ps1`

- [ ] **Step 1: Add template rendering tests**

Render both templates with paths containing spaces and assert the output XML parses and contains no unresolved `${...}` tokens.

- [ ] **Step 2: Install MinIO and backend explicitly**

Validate all prior stage state, copy the two WinSW executables, render XML with absolute paths, configure rolling logs, install/start `DatongMapMinIO` and `DatongMapBackend`, apply restrictive ACLs, and add only the TCP 8012 firewall rule.

- [ ] **Step 3: Implement verification report**

Check the selected MySQL service, MinIO and backend service states; confirm internal ports listen only on loopback; request the HTTPS health endpoint and frontend index; inspect Flyway startup logs; generate `reports/deployment-result.html` with exact next steps.

- [ ] **Step 4: Implement client certificate import**

Require administrator access, import only the package certificate into LocalMachine Trusted Root, print the final hostname URL, and avoid modifying DNS or hosts files.

- [ ] **Step 5: Run parser and template tests**

Expected: all scripts parse, template tests pass, and no unresolved template tokens remain.

- [ ] **Step 6: Commit**

```bash
git add deploy/windows/scripts/04-install-services.ps1 deploy/windows/scripts/05-verify.ps1 \
  deploy/windows/scripts/install-client-certificate.ps1 deploy/windows/service
git commit -m "Add staged Windows service installation"
```

### Task 6: Add operator recovery and remote diagnostics

**Files:**
- Create: `deploy/windows/scripts/start.ps1`
- Create: `deploy/windows/scripts/stop.ps1`
- Create: `deploy/windows/scripts/restart.ps1`
- Create: `deploy/windows/scripts/status.ps1`
- Create: `deploy/windows/scripts/uninstall.ps1`
- Create: `deploy/windows/scripts/backup.ps1`
- Create: `deploy/windows/scripts/restore.ps1`
- Create: `deploy/windows/scripts/collect-diagnostics.ps1`

- [ ] **Step 1: Add redaction and ownership tests**

Assert diagnostics replace every configured secret, and uninstall selection excludes the reused MySQL service when `OwnsMySqlService=false`.

- [ ] **Step 2: Add lifecycle scripts**

Start in MySQL→MinIO→backend order and stop in reverse. Status reports service state and HTTPS health. Uninstall removes only project-owned services/firewall rules and keeps data unless `-RemoveData` is explicit.

- [ ] **Step 3: Add backup and restore**

Use the selected MySQL client and business credentials for `mysqldump`; use bundled `mc.exe` for MinIO mirror; retain seven daily and four weekly directories. Restore creates a safety snapshot, stops the backend, restores both stores, restarts, and invokes stage 05 verification.

- [ ] **Step 4: Add safe diagnostics**

Collect reports, Windows version, ports, relevant service metadata and the last 500 log lines. Copy settings through the redaction function, exclude PFX/private keys, and create `DatongMap-Diagnostics-<timestamp>.zip`.

- [ ] **Step 5: Run tests and parser validation**

Expected: all scripts parse and all pure-function tests pass.

- [ ] **Step 6: Commit**

```bash
git add deploy/windows/scripts deploy/windows/tests
git commit -m "Add Windows recovery and diagnostics tools"
```

### Task 7: Build the Windows package and documentation

**Files:**
- Create: `deploy/windows/build-package.ps1`
- Create: `deploy/windows/Windows部署操作手册.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Implement package assembly**

Build frontend, test backend, package the Windows JAR, verify embedded index, copy scripts/templates/docs, optionally validate and include `runtime/java`, `runtime/mysql`, `runtime/minio` and `runtime/winsw`, then produce `datong-map-windows-slim.zip` or `datong-map-windows-offline.zip`.

- [ ] **Step 2: Add Windows CI**

Add a `windows-package` job using Java 21 and Node 24. Parse every PowerShell file with the Windows PowerShell parser, run the assertion script, build the slim ZIP, and upload it with `actions/upload-artifact@v4`.

- [ ] **Step 3: Write the operator manual**

Document the five numbered commands, screenshots-to-send/report files, MySQL reuse rules, client certificate step, rollback, backup/restore and diagnostics collection. State explicitly that stage 01 is read-only and that operators should stop and send the generated report when a red item appears.

- [ ] **Step 4: Update repository guidance**

Add a short Windows section to README and ignore generated Windows state, reports, runtime binaries and ZIP files.

- [ ] **Step 5: Verify package contents**

Run the package build and list the ZIP. Expected: JAR, numbered scripts, templates, manual and example config are present; secrets, `deploy/.env`, reports and runtime state are absent.

- [ ] **Step 6: Commit**

```bash
git add deploy/windows .github/workflows/ci.yml README.md .gitignore
git commit -m "Add native Windows deployment package"
```

### Task 8: Full regression, local-main integration and live Docker check

**Files:**
- Modify only files required by test failures.

- [ ] **Step 1: Run backend tests**

Run: `cd backend && mvn test`

Expected: all tests pass.

- [ ] **Step 2: Run frontend tests, build and audit**

Run: `cd frontend && node --test src/utils/*.test.mjs && npm run build && npm audit --audit-level=high`

Expected: tests/build pass and audit reports zero high-severity vulnerabilities.

- [ ] **Step 3: Validate Windows package and workflow syntax**

Run the package assembly available on the current host, inspect the ZIP and confirm GitHub Actions YAML parses through repository CI tooling.

- [ ] **Step 4: Merge into local main**

```bash
git switch main
git merge --no-ff codex/windows-native-deployment
```

- [ ] **Step 5: Rebuild the existing Docker stack from local main**

Run: `cd deploy && docker compose up -d --build`

Expected: MySQL, Redis, MinIO, backend and frontend become healthy.

- [ ] **Step 6: Verify the local application**

Check `http://127.0.0.1:8012/`, register/login/API behavior, map pages and Docker health. Confirm Windows changes did not alter the Linux production path.

- [ ] **Step 7: Report scope**

Report local main SHA, tests, package output and remaining requirement for a real Windows Server installation rehearsal. Do not push or deploy until explicitly requested.
