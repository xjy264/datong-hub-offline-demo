# User Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every existing message visible and add deterministic feedback for session expiry, drag auto-save, folder edits, blank prompts, and handled API failures.

**Architecture:** Keep API error text centralized in `http.ts`, add small pure utilities for testable state decisions, and leave page components responsible only for operation-specific success messages and rollback. Import only the missing Element Plus message stylesheet rather than the full theme bundle.

**Tech Stack:** Vue 3, TypeScript, Element Plus, Axios, Pinia, Node test runner

---

### Task 1: Add feedback regression tests

**Files:**
- Create: `frontend/src/utils/feedbackAssets.test.mjs`
- Create: `frontend/src/utils/actionFeedback.test.mjs`
- Create: `frontend/src/utils/actionFeedback.ts`
- Modify: `frontend/src/utils/unauthorizedAction.test.mjs`
- Modify: `frontend/src/utils/unauthorizedAction.ts`

- [ ] Write failing tests asserting the message stylesheet is imported, protected-page 401s redirect with `reason=expired`, login-page 401s remain silent, blank names normalize to `null`, positions restore after failure, and only marked API errors are classified as handled.
- [ ] Run `node --experimental-strip-types --test src/utils/*.test.mjs` and confirm the new assertions fail for the missing behavior.
- [ ] Add the minimum pure utility implementations and rerun until the utility tests pass.

### Task 2: Restore global feedback and session-expiry notice

**Files:**
- Modify: `frontend/src/main.ts`
- Modify: `frontend/src/api/http.ts`
- Modify: `frontend/src/views/LoginView.vue`

- [ ] Import `element-plus/theme-chalk/el-message.css` from `main.ts`.
- [ ] Mark rejected API errors after the interceptor has shown their message or handled their 401 redirect.
- [ ] Redirect protected-page 401s to `/login?reason=expired`, show the mapped warning once in `LoginView.vue`, then remove the query parameter.
- [ ] Configure Vue's error handler to ignore marked API errors and log all other errors.

### Task 3: Add mutation feedback and rollback

**Files:**
- Modify: `frontend/src/views/MapView.vue`
- Modify: `frontend/src/views/StationView.vue`
- Modify: `frontend/src/views/MapSelectView.vue`

- [ ] Store original marker and interval positions at drag start, show success after persistence, and restore positions after rejection.
- [ ] Show success for root/child folder creation and rename; capture the pre-edit folder name and restore it after rejection.
- [ ] Treat prompt cancellation as silent, but warn for confirmed blank map or workshop names.

### Task 4: Verify and integrate

**Files:**
- Test: `frontend/src/utils/*.test.mjs`
- Test: `backend/src/test/**`

- [ ] Run the frontend Node test suite and `npm run build`; assert the generated CSS contains `.el-message--error`.
- [ ] Run the backend Maven test suite with the Maven Central settings file.
- [ ] Commit the implementation, merge `codex/user-feedback` into local `main`, and verify the resulting worktree is clean.
- [ ] Start the merged local app and use the browser to verify a wrong password produces a styled, visible alert without an AxiosError console entry.
