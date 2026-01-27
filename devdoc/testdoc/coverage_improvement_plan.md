# Code Coverage Improvement Plan

Based on the coverage analysis performed on January 28, 2026, the following areas require additional testing to improve overall project quality.

## Current Status
- **TransmissionClient.swift**: Improved to **77.0%** (critical network core covered).
- **Overall**: Critical infrastructure is well-tested. Remaining gaps are in specific feature logic and UI views.

## Priority 1: Business Logic & Reducers
These components contain significant logic that is currently under-tested.

### 1. ServerDetailReducer+AddTorrent.swift (30.6%)
- **Focus**: File import failures, handling of `.torrent` files vs others, error mapping.
- **Action**: Add comprehensive tests for `importReducer` and helper methods in `ServerDetailFeatureTests` or a new test file.

### 2. ServerConnectionProbe.swift (45.2%)
- **Focus**: `checkConnection` error paths, specific `URLError` handling in the probe logic, backoff calculator edge cases.
- **Action**: Enhance `ServerConnectionProbeTests`.

### 3. Feature Helpers
- **TorrentListFeature+Helpers.swift (51.1%)**: Logic for calculating stats, filtering, and sorting.
- **TorrentDetailFeature+Helpers.swift (49.3%)**: Formatting and state calculation helpers.
- **Action**: Add specific unit tests for these helper extensions.

## Priority 2: Infrastructure & Client
Boilerplate or less critical paths, but easy to cover.

### 1. TransmissionClient+Session.swift (33.3%)
- **Focus**: `sessionSet` and `sessionStats` are likely unused in current tests.
- **Action**: Add simple tests in `TransmissionClientSystemSessionTests` to ensure arguments are passed correctly.

### 2. UserPreferencesRepository+Live.swift (58.9%)
- **Focus**: `UserDefaults` persistence logic, edge cases in saving/loading.
- **Action**: Expand `PersistentUserPreferencesRepositoryTests`.

## Priority 3: UI Views (Deferred)
Low coverage (~10-50%) in SwiftUI views is expected as unit tests are not the best tool.
- **Components**: `TorrentFilesView`, `TorrentTrackersView`, `ServerConfigurationView`, `AppView`.
- **Action**: Use Snapshot Testing or UI Automation (XCUITest) in a separate track. **No immediate action for Unit Tests.**

---

## Execution Log

- [ ] **Step 1**: Cover `ServerDetailReducer+AddTorrent.swift`.
- [ ] **Step 2**: Cover `ServerConnectionProbe.swift`.
- [ ] **Step 3**: Cover `TransmissionClient+Session.swift`.
