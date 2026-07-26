# Native Torrent List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom main torrent screen shell with a native SwiftUI `List`-based structure on iOS 26 and macOS 26 while preserving TCA behavior and previews.

**Architecture:** Keep `TorrentListReducer` and command behavior unchanged. Refactor only the SwiftUI surface: one shared native list path, platform-specific toolbar/search affordances, and compact native rows with context menus instead of permanent custom action pills.

**Tech Stack:** Swift 6, SwiftUI, TCA, Xcode Native MCP, iPhone 12 simulator verification.

---

### Task 1: Lock Current Rendering Coverage

**Files:**
- Inspect: `RemissionTests/ViewCoverage/TorrentListViewCoverageTests.swift`
- Modify only if coverage is missing: `RemissionTests/ViewCoverage/TorrentListViewCoverageTests.swift`

- [x] Read existing TorrentList view coverage tests.
- [x] Ensure loaded, empty, loading/offline/error states still render through `TorrentListView`.
- [x] Run the focused coverage tests before and after refactor:

```bash
xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 12' -only-testing:RemissionTests/TorrentListViewCoverageTests
```

Expected: existing tests pass before refactor and continue to pass after refactor.

### Task 2: Replace Custom Scroll/Card Container With Native List

**Files:**
- Modify: `Remission/Views/TorrentList/TorrentListView.swift`
- Modify: `Remission/Views/TorrentList/TorrentListView+Toolbar.swift`

- [x] Replace macOS `VStack + ScrollView + LazyVStack` with a shared `List` body.
- [x] Replace iOS sticky `safeAreaInset` header and `BlurView` with `.searchable`, toolbar controls, and list sections.
- [x] Keep `ContentUnavailableView` for empty/offline/error states where available.
- [x] Keep `confirmationDialog`, alerts, refresh, optimistic verify display, and command dispatch unchanged.

### Task 3: Simplify Torrent Rows To Native List Rows

**Files:**
- Modify: `Remission/Views/TorrentList/Cells/TorrentRowView.swift`
- Modify: `Remission/Views/TorrentList/TorrentListView.swift`

- [x] Remove custom card background/overlay styling from list rows.
- [x] Replace permanent macOS action pill with native row `contextMenu` and compact trailing `Menu` where needed.
- [x] Keep torrent name, progress, peers, ratio, speed, status, and accessibility identifiers.
- [x] Preserve disabled/removing state and command busy flags.

### Task 4: Remove Dead Custom UI Components From Main Path

**Files:**
- Delete if unused after searches: `Remission/Views/TorrentList/Components/TorrentListHeaderiOSView.swift`
- Delete if unused after searches: `Remission/Views/TorrentList/Components/TorrentListHeaderView.swift`
- Delete if unused after searches: `Remission/Views/TorrentList/Cells/TorrentRowBackgroundView.swift`
- Keep only if used elsewhere: `Remission/Views/TorrentList/Components/TorrentListStorageSummaryView.swift`

- [x] Search each component name with XcodeGrep.
- [x] Delete only components with no remaining production or preview usage.
- [x] Update tests or previews that referenced removed components.

### Task 5: Verify And Review

**Files:**
- Inspect changed Swift files and tests.
- Add retrospective only if the final change remains broad: `.agents/retrospectives/2026-05-21-native-torrent-list.md`

- [x] Run `swift-format` for changed Swift files.
- [x] Run `swiftlint lint --quiet` for changed Swift files, then full pre-commit lint at commit time.
- [x] Build with Xcode native `BuildProject`.
- [x] Build/test on iPhone 12 simulator with XcodeBuildMCP.
- [x] Run code-review-reflection checklist before commit.
