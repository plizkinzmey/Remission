# Startup Connection Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a native, non-modal startup connection flow for iOS and macOS 26, using `NavigationStack` and `ContentUnavailableView`.

**Architecture:** 
- Remove automatic `serverForm` presentation from `ServerListReducer`.
- Update `AppView` to conditionally show an onboarding root or the main server list.
- Use `NavigationLink` for adding the first server on iOS (push transition).
- Use inline form display for macOS when no servers are configured.

**Tech Stack:** SwiftUI (iOS/macOS 26), TCA (The Composable Architecture).

---

### Task 1: Reducer Clean-up (TDD)

**Files:**
- Modify: `Remission/Remission/Features/ServerList/ServerListReducer+Connection.swift`
- Test: `Remission/RemissionTests/ServerListFeatureTests.swift`

- [ ] **Step 1: Update existing tests to reflect removal of auto-presentation**
Modify `testTaskInitialLoadEmptyDoesNotAutoPresentServerForm` (if it exists and tests for modal) to ensure `serverForm` is always `nil` on startup regardless of onboarding status.

- [ ] **Step 2: Remove auto-presentation logic from Reducer**
Remove the block that sets `state.serverForm` in `serverRepositoryResponse` handler.

- [ ] **Step 3: Run tests to verify**
Run: `swift test --filter ServerListFeatureTests`

- [ ] **Step 4: Commit**
```bash
git add Remission/Remission/Features/ServerList/ServerListReducer+Connection.swift Remission/RemissionTests/ServerListFeatureTests.swift
git commit -m "refactor(server-list): remove auto-modal presentation on startup"
```

### Task 2: iOS Onboarding Root Implementation

**Files:**
- Modify: `Remission/Remission/Views/App/AppView.swift`
- Modify: `Remission/Remission/Views/ServerList/ServerListView+Content.swift`

- [ ] **Step 1: Update ServerListView empty state**
Ensure `addButtonTapped` action is still wired to the button in `emptyState`.

- [ ] **Step 2: Update AppView root logic**
Modify `rootContent` to show `ServerListView` as the primary root. The `ServerListView` already has an `emptyState` using `ContentUnavailableView`.

- [ ] **Step 3: Implement Navigation Push for Add Server (iOS)**
In `AppView.swift`, update the `NavigationStack` destination or root to handle `ServerFormView` via push if it's the first setup. (Note: Current `AppView` uses `ServerDetailView` in destination. We might need to add `ServerForm` to the path or handle it as a root transition).

### Task 3: macOS Inline Setup Implementation

**Files:**
- Modify: `Remission/Remission/Views/ServerList/ServerListView.swift`
- Modify: `Remission/Remission/Views/ServerList/ServerListView+Content.swift`

- [ ] **Step 1: Update ServerListView for macOS inline display**
If `servers.isEmpty` and not loading, instead of just `emptyState`, show a more prominent "Setup" view that can optionally contain the form or a clear call to action that doesn't use a sheet.

- [ ] **Step 2: Adjust Layout for macOS 26**
Ensure the центрирование (centering) of `ContentUnavailableView` looks native on macOS.

### Task 4: Final Polishing & Verification

- [ ] **Step 1: Run all tests**
Run: `RunSomeTests`

- [ ] **Step 2: Verify Previews**
Check `#Preview` in `AppView` and `ServerListView` for both platforms.

- [ ] **Step 3: Commit final changes**
```bash
git commit -m "feat(startup): native onboarding flow for iOS and macOS"
```
