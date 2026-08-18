# Issue 10 Workshop Collapse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users collapse the workshop card strip and place map filters and actions in one responsive toolbar row.

**Architecture:** Keep the UI state local to `MapView.vue`, while isolating local-storage parsing and failure handling in a small tested utility. Use CSS grid for the desktop toolbar and switch to a one-column, wrapping layout below the desktop breakpoint.

**Tech Stack:** Vue 3, TypeScript, Element Plus, CSS, Node test runner.

---

### Task 1: Persist workshop strip visibility

**Files:**
- Create: `frontend/src/utils/workshopVisibility.ts`
- Create: `frontend/src/utils/workshopVisibility.test.mjs`

- [ ] Write tests proving missing/invalid state defaults to visible, `true` restores collapsed state, writes persist both values, and storage failures are ignored.
- [ ] Run `docker run --rm -v "$PWD:/app" -w /app node:24-alpine node --test src/utils/workshopVisibility.test.mjs` from `frontend/` and verify it fails because the utility is missing.
- [ ] Implement `readWorkshopStripCollapsed` and `writeWorkshopStripCollapsed` with the fixed key `datong-map:workshop-strip-collapsed` and guarded browser storage access.
- [ ] Re-run the focused test and verify all cases pass.

### Task 2: Add collapse control and responsive toolbar

**Files:**
- Modify: `frontend/src/views/MapView.vue`
- Modify: `frontend/src/styles/main.css`

- [ ] Add an icon-only Element Plus button in the page title metadata that toggles `workshopStripCollapsed`, exposes a tooltip and `aria-expanded`, and persists each change through the tested utility.
- [ ] Hide the complete `.workshop-strip` with `v-show` while collapsed so cards and management actions return unchanged when expanded.
- [ ] Name the toolbar groups `.map-filter-controls` and `.map-action-controls`; render filters on the left and all four existing actions on the right without changing handlers.
- [ ] Use a two-column grid on desktop and switch to one column below `1180px`; allow controls to wrap only at narrow widths and cap input/select widths at their container.
- [ ] Run the focused utility test, the full Node 24 test suite, `npm run build`, and `git diff --check`.
- [ ] Start the feature frontend, verify the collapse state across reload, and capture desktop and mobile screenshots showing no overlap or horizontal overflow.

### Task 3: Integrate Issue 10

- [ ] Commit only the plan, utility, test, view, and stylesheet on `codex/issue-10-workshop-collapse`.
- [ ] Merge the feature branch into local `main`, rerun the full frontend tests and build from `main`, and confirm the worktree is clean.
- [ ] Push local `main` to `github/main`, verify the remote SHA, and close Issue #10 with the commit reference.
