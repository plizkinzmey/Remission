# Test Plan: Torrent List Feature

## Overview
The Torrent List feature is a core part of the Remission app. It manages the display, filtering, searching, and basic control of torrents for a specific server connection. It uses the Composable Architecture (TCA) and interacts with multiple repositories and services.

## Objectives
- Ensure robust handling of various network states (loading, success, error, offline).
- Validate search and filtering logic.
- Verify polling mechanism and automatic retry logic with backoff.
- Confirm correct execution of torrent commands (Start, Pause, Verify, Remove).
- Guarantee consistent UI rendering across platforms (iOS, macOS).

---

## 1. Unit Tests (TorrentListReducerTests)

### 1.1 Initialization and Lifecycle
- **Initial Task**: Verify that `.task` triggers preference loading and transitions to `.loading` if items are empty.
- **Teardown**: Ensure `.teardown` cancels all active effects (polling, fetch, preferences) and resets temporary state.
- **Reconnect**: Test `.resetForReconnect` properly cleans up state and triggers a fresh load.

### 1.2 Fetching and Polling
- **Successful Fetch**: 
    - Verify transition from `.loading` to `.loaded`.
    - Validate merging logic for new/existing/removed torrents.
    - Check that polling is scheduled after a successful fetch.
- **Failed Fetch**:
    - Verify transition to `.offline` or `.error` phase.
    - Check that `failedAttempts` increment.
    - Validate backoff strategy for polling retries.
- **Polling Tick**: Ensure `.pollingTick` triggers a fetch.
- **Cache Handling**: Verify how the state behaves when data is loaded from cache vs network.

### 1.3 Search and Filtering
- **Search Query**: Test that `searchQueryChanged` updates state and correctly filters `visibleItems`.
- **Status Filtering**: Verify `filterChanged` (All, Downloading, Seeding, Errors) correctly filters items.
- **Category Filtering**: Verify `categoryChanged` (Movies, Series, etc.) correctly filters items based on tags.
- **Combined Filtering**: Test combinations of search + status + category.

### 1.4 Torrent Commands
- **Start/Pause/Verify**:
    - Verify `inFlightCommands` are tracked correctly.
    - Test successful response triggers a refresh.
    - Test failure response shows an alert and cleans up `inFlightCommands`.
- **Removal Flow**:
    - Verify `removeTapped` shows a confirmation dialog.
    - Test `deleteTorrentOnly` and `deleteWithData` send correct repository commands.
    - Verify torrent is marked as `isRemoving` during the process.

### 1.5 Preferences Interaction
- **Auto-refresh Toggle**: Test that changing `isAutoRefreshEnabled` in preferences starts/stops polling.
- **Polling Interval**: Verify that changing the interval updates the polling schedule.

### 1.6 External Updates (Delegate & Handlers)
- **Detail Updates**: Verify `detailUpdated` correctly merges a single torrent update and syncs with the list.
- **Torrent Added**: Test that adding a new torrent creates a placeholder and triggers a refresh.
- **Torrent Removed**: Test that removal from detail view updates the list.

---

## 2. Snapshot Tests (TorrentListViewSnapshotTests)

### 2.1 States (macOS & iOS)
- **Idle/Awaiting Connection**: Skeleton view.
- **Loading**: Skeleton view (without refresh indicator).
- **Loaded (Empty)**: Empty state view.
- **Loaded (Data)**: List of torrents with various statuses.
- **Error**: Error view with retry button and message.
- **Offline**: Offline view with banner and retry button.

### 2.2 Components
- **Torrent Row**:
    - Different statuses (Downloading, Seeding, Paused, Error, Checking).
    - Locked state (during removal).
    - In-flight actions (busy indicators for start/pause/verify).
- **Banners**:
    - Error banner (dismissible, retryable).
    - Offline banner with timestamp.
- **Footer**:
    - Storage summary display.
    - Server version display.
- **Search**:
    - Search field visibility and suggestions (iOS).

---

## 3. Integration Tests (TorrentListIntegrationTests)

- **End-to-End Flow**:
    1. Start with idle state.
    2. Receive preferences.
    3. Trigger initial fetch.
    4. Verify items are displayed.
    5. Trigger a command (e.g., Pause).
    6. Verify state update and subsequent refresh.
- **Offline Recovery**:
    1. Start in offline state.
    2. Tap retry.
    3. Successfully fetch and transition to loaded state.

---

## 4. UI Tests (TorrentListUITests)

- **Basic Navigation**: Ensure the list loads and items are tappable.
- **Search Interaction**: Verify searching for a specific torrent works.
- **Pull-to-Refresh**: Validate pull-to-refresh on iOS.
- **Context Menus**: Ensure context menu actions are available and functional.
