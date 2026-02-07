# Remission: Project Knowledge Capsule (Start Here)

Remission is a cross-platform (iOS + macOS) SwiftUI client for managing Transmission via its RPC API.
The codebase is organized around Point-Free's The Composable Architecture (TCA) and swift-dependencies.

This document exists so you can start productive work immediately (without re-studying the repo).

## Quick Start

- Open in Xcode:
  - `open /Users/plizkinzmey/SRC/Remission/Remission.xcodeproj`
- Format + lint:
  - `swift-format format --in-place --configuration /Users/plizkinzmey/SRC/Remission/.swift-format --recursive /Users/plizkinzmey/SRC/Remission/Remission /Users/plizkinzmey/SRC/Remission/RemissionTests /Users/plizkinzmey/SRC/Remission/RemissionUITests`
  - `swiftlint lint --fix`
- Localizations sanity check:
  - `/Users/plizkinzmey/SRC/Remission/Scripts/check-localizations.sh`
- Run tests (examples):
  - iOS simulator: `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e'`
  - macOS smoke: `xcodebuild test -scheme Remission -sdk macosx`

## What Runs Where (Entry Points)

- App entry point: `/Users/plizkinzmey/SRC/Remission/Remission/App/RemissionApp.swift`
  - Builds a `StoreOf<AppReducer>` and selects dependencies:
    - UI-tests/fixtures: `AppDependencies.makeUITest(...)` (see `/Users/plizkinzmey/SRC/Remission/Remission/App/AppDependencies+UITesting.swift`)
    - Normal app: `AppDependencies.makeLive()`
  - Handles `.torrent` opening:
    - iOS: `.onOpenURL` in `AppView` and background fetch via `UIApplicationDelegate`
    - macOS: `NSApplicationDelegate` forwards open-file events between instances via `DistributedNotificationCenter`
- Root reducer: `/Users/plizkinzmey/SRC/Remission/Remission/App/AppFeature.swift` (`AppReducer`)
- Root view: `/Users/plizkinzmey/SRC/Remission/Remission/Views/App/AppView.swift`

## Tech Stack (SPM)

Resolved via SwiftPM in the Xcode project workspace:
`/Users/plizkinzmey/SRC/Remission/Remission.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

Key libraries:
- `swift-composable-architecture` (TCA)
- `swift-dependencies`
- `swift-navigation`, `swift-perception`, `swift-sharing`
- `swift-clocks` (testable time)
- `swift-log` (AppLogger implementation uses Logging)

## Repository Map (Mental Model)

- `Remission/App/`
  - App wiring, bootstrap, dependency presets, UI-test scenarios/fixtures.
- `Remission/Features/`
  - Feature logic as TCA reducers:
    - `ServerListReducer`: list/manage servers + connection probe + storage summary.
    - `ServerDetailReducer`: connection + embeds `TorrentListReducer` + navigation to settings/diagnostics/add-torrent/detail.
    - `TorrentListReducer`: polling, filtering/search, commands (start/pause/verify/remove), offline mode.
    - `TorrentDetailReducer`, `AddTorrentReducer`, `SettingsReducer`, `DiagnosticsReducer`.
- `Remission/Views/`
  - SwiftUI views that bind to stores and present sheets/alerts.
- `Remission/Network/Transmission/`
  - Transmission RPC protocol implementation (`TransmissionClient` + request/response models).
- `Remission/Domain/`
  - Domain models + mapping layer:
    - `TransmissionDomainMapper*` maps Transmission RPC payloads to domain (`ServerConfig`, `Torrent`, `SessionState`, ...).
- `Remission/Repositories/`
  - High-level data access facades used by reducers:
    - `ServerConfigRepository`: persisted `servers.json` (no passwords).
    - `CredentialsRepository` + `KeychainCredentialsStore`: passwords in Keychain.
    - `TorrentRepository`, `SessionRepository`: built around `TransmissionClientDependency` + mapping + offline snapshot.
- `Remission/Storage/`
  - Offline cache snapshots + HTTP warning preferences + keychain store.
- `Remission/Security/Trust/`
  - TLS trust evaluation + user prompts + persisted fingerprints.
- `Remission/Logging/`
  - Safe logging (masking) + diagnostics sink.

## Core Runtime Flow

1. User selects a server in `ServerListView` -> `ServerListReducer` delegates `.serverSelected`.
2. `AppReducer` pushes `ServerDetailReducer.State(server:)` onto `StackState` path.
3. `ServerDetailReducer` creates a `ServerConnectionEnvironment` via `ServerConnectionEnvironmentFactory`:
   - Loads password via `CredentialsRepository`.
   - Builds `TransmissionClient` configured for the server.
   - Attaches TLS trust decision handler (`TransmissionTrustPromptCenter`).
   - Builds `TorrentRepository` + `SessionRepository` with offline snapshot client.
4. `TorrentListReducer` starts:
   - Loads user preferences (polling interval, auto-refresh).
   - Starts polling using `appClock` (testable) when enabled.
   - Fetches torrents via `TorrentRepository`, updates UI, can go offline and show cached snapshots.

## Dependency Injection (How To Override Correctly)

- Dependency presets:
  - Live app: `/Users/plizkinzmey/SRC/Remission/Remission/App/AppDependencies.swift`
  - Default dependency values: `/Users/plizkinzmey/SRC/Remission/Remission/App/DependencyValues+App.swift`
- Common patterns:
  - Unit tests: use `TestStoreFactory` (`/Users/plizkinzmey/SRC/Remission/RemissionTests/Support/TestStoreFactory.swift`)
    - Starts from `AppDependencies.makeTestDefaults()`, then override what you need.
  - Previews: use `AppDependencies.makePreview()` (see `AppView` previews).
- Server-scoped DI:
  - `ServerConnectionEnvironment` (Sendable) can apply overrides to `DependencyValues` for a single server session:
    - `/Users/plizkinzmey/SRC/Remission/Remission/App/ServerConnectionEnvironment.swift`

## Storage & Security (Where Sensitive Data Goes)

- Servers list (public fields, without password):
  - `ServerConfigRepository.fileBased()` persists JSON:
    - `/Users/plizkinzmey/SRC/Remission/Remission/Repositories/ServerConfigRepository.swift`
    - File path helper: `ServerConfigStoragePaths.defaultURL()` -> `Application Support/Remission/servers.json`
- Passwords:
  - `KeychainCredentialsStore` (`kSecClassGenericPassword`), service `"com.remission.transmission"`:
    - `/Users/plizkinzmey/SRC/Remission/Remission/Storage/KeychainCredentialsStore.swift`
- TLS trust:
  - Trust store + evaluator + prompt center:
    - `/Users/plizkinzmey/SRC/Remission/Remission/Security/Trust/`
- Offline cache:
  - Snapshot repository + file store:
    - `/Users/plizkinzmey/SRC/Remission/Remission/Storage/ServerSnapshotCache.swift`

## UI Testing Hooks (Fixtures/Scenarios)

`AppBootstrap` parses launch arguments and can pre-seed state for UI tests:
`/Users/plizkinzmey/SRC/Remission/Remission/App/AppBootstrap.swift`

- Fixture arg: `--ui-testing-fixture=server-list-sample` or `torrent-list-sample`
- Scenario arg: `--ui-testing-scenario=onboarding-flow` etc.

When a fixture/scenario is present, `RemissionApp` swaps dependencies to UI-test versions.

## Common Change Recipes

### Add a new Transmission RPC call

1. Add a method to `TransmissionClient` (or `TransmissionClientProtocol` if needed):
   - `/Users/plizkinzmey/SRC/Remission/Remission/Network/Transmission/TransmissionClient.swift`
2. Define request/response payload decoding (via `AnyCodable`/mappers).
3. Extend `TransmissionDomainMapper` for domain conversion:
   - `/Users/plizkinzmey/SRC/Remission/Remission/Domain/TransmissionDomainMapper*.swift`
4. Expose it via `TransmissionClientDependency` or a repository method.
5. Add tests:
   - Prefer `MockURLProtocol` for request/response assertions:
     - `/Users/plizkinzmey/SRC/Remission/RemissionTests/Support/MockURLProtocol.swift`

### Add a new feature screen (TCA)

1. Create reducer in `Remission/Features/<FeatureName>/...`.
2. Create SwiftUI view in `Remission/Views/<FeatureName>/...`.
3. Wire navigation/presentation from:
   - `AppReducer` (top-level navigation) or
   - `ServerDetailReducer` (server-scoped flows) or
   - `TorrentListReducer` (torrent list actions).
4. Follow `/Users/plizkinzmey/SRC/Remission/Templates/FeatureChecklist.md`.

## Known Gotchas / Drift Notes

- Xcode project currently sets `IPHONEOS_DEPLOYMENT_TARGET` and `MACOSX_DEPLOYMENT_TARGET` to `26.0` in:
  - `/Users/plizkinzmey/SRC/Remission/Remission.xcodeproj/project.pbxproj`
  - README mentions lower targets (iOS 17 / macOS 14) as intended minimum; treat the pbxproj values as the source of truth.
- `Remission/Info-macOS.plist` has `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` (by design or temporary).

## Deep Dive

For diagrams and a more detailed architecture walkthrough, see:
`/Users/plizkinzmey/SRC/Remission/Doc/ProjectMap.md`

