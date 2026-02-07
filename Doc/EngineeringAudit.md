# Remission: Engineering Audit (Architecture + Code Quality)

Date: 2026-02-07

This document is an engineering-focused audit of the Remission codebase (Swift 6, SwiftUI, TCA, swift-dependencies).
It is intended to answer:

- Is the architecture sound and maintainable?
- Are technologies applied correctly (Swift Concurrency, TCA, DI, networking)?
- Are there high-risk flaws (crashes, hangs, data races)?
- Is there unnecessary duplication or dead code?

## TL;DR

Overall the project is in a good shape:

- Clear feature boundaries (TCA reducers + views), good test coverage, and a reasonably clean dependency graph.
- Networking layer is separated from domain and repositories.
- Recent refactors removed the highest-risk production hangs/crashes around TLS trust prompts and server URL building.

Remaining work is mostly “hygiene”:

- Reduce `@unchecked Sendable` usage by migrating some small in-memory stores and logger sinks to `actor`s.
- Centralize a few duplicated “UserDefaultsBox/NSLock storage” utilities.
- Consider enabling stricter concurrency checking in Debug to catch regressions earlier.

## Strengths

- **TCA architecture is applied consistently**: reducers contain business logic, views are mostly bindings and presentation.
- **DI via swift-dependencies** keeps the code testable; there are live/preview/test values for most clients/stores.
- **Repositories layer** sits above raw RPC client and keeps reducers simpler (TorrentRepository/SessionRepository/etc.).
- **Offline/cache story** exists (snapshots + expiration), and reducers handle offline mode.
- **Tests exist where it matters**: domain mapping, repositories, and reducer flows; view coverage tests are present.

## Findings (Ordered by severity)

### P0 (must fix / regressions to avoid)

- None found after the latest refactor cycle, assuming:
  - TLS trust prompts are always presented at App level (global consumer).
  - Server configuration can no longer crash on invalid host/path.

### P1 (high value / medium risk)

#### 1) Remaining `@unchecked Sendable` hotspots

Locations (non-exhaustive; grep for `@unchecked Sendable`):

- `Remission/Repositories/OnboardingProgressRepository.swift`
- `Remission/Storage/HttpWarningPreferencesStore.swift`
- `Remission/DependencyClients/DiagnosticsLogStoreDependency.swift`
- `Remission/Security/Trust/TransmissionTrustStore.swift`
- `Remission/Network/Transmission/TransmissionSessionDelegate.swift`
- `Remission/Logging/AppLogger.swift`
- `Remission/DependencyClientLive/UserPreferencesRepository+Live.swift`

Why it matters:

- With Swift 6, concurrency correctness depends on real `Sendable` safety, not just annotations.
- `@unchecked Sendable` is fine when the invariant is real and documented, but it tends to accumulate.

Recommended approach:

- For small in-memory stores (NSLock + dictionary/bool): migrate to `actor` (minimal blast radius).
- For wrappers around non-Sendable system types (e.g. `SecTrust`): keep wrappers, but document invariants next to the annotation.
- Keep a short checklist: “why safe” + “who owns synchronization” near each `@unchecked Sendable`.

#### 2) Notification permission request in reducers (test friction)

`TorrentListReducer` requests notification permission in `.task`.

This is OK UX-wise, but test-wise it forces tests to stub `NotificationClient.requestAuthorization`.

Mitigations:

- Keep `NotificationClient.testValue` as a no-op (recommended; prevents brittle tests).
- If you later want more control, gate permission request behind a preference flag or “first run” state.

### P2 (cleanup / maintainability)

#### 1) Duplication: multiple `UserDefaultsBox` / lock-box implementations

Example:

- `OnboardingProgressRepository.swift` defines `UserDefaultsBox`
- `HttpWarningPreferencesStore.swift` defines another `UserDefaultsBox`
- `DiagnosticsLogStoreDependency.swift` defines `DiagnosticsUserDefaultsBox`

Recommendation:

- Introduce one small internal utility (e.g. `UserDefaultsBox` in `Remission/Storage/`) or replace with an `actor` wrapper.
- This reduces copy/paste and makes “thread-safety” a single responsibility.

#### 2) SwiftUI view-coverage tests emit warnings about `State` usage

Warnings like:

> Accessing State's value outside of being installed on a View...

These warnings are common in snapshot/view-coverage tests that initialize views in isolation.

Recommendation:

- Decide if you want to enforce “warning-free tests”.
- If yes, wrap view construction in the recommended TCA view test harness patterns, or adjust the tests to avoid reading `@State` bindings directly.

#### 3) Concurrency settings are permissive at project level

In `Remission.xcodeproj/project.pbxproj`:

- `SWIFT_VERSION = 6.0`
- Upcoming features: `MemberImportVisibility`
- No `SWIFT_STRICT_CONCURRENCY` / no `SWIFT_DEFAULT_ACTOR_ISOLATION`

Recommendation:

- Consider enabling `SWIFT_STRICT_CONCURRENCY = targeted` at least for Debug.
- Keep Release conservative if you want, but Debug should catch regressions early.

## Dead Code / Build Hygiene

- Only one “example” file exists:
  - `Remission/Network/Transmission/TransmissionClientUsageExample.swift`
- It should remain excluded from Release builds (and ideally wrapped in `#if DEBUG` as an extra safety net).

If you want a stronger guarantee:

- Add a CI step that checks for `*UsageExample*.swift`/`*Scratch*.swift` membership in build phases.

## Architectural Notes (What to watch over time)

- **Reducer size**: keep large reducers split by concern (you already do `+Reducer/+State/+Helpers` style).
- **Domain mapping**: mapping layers tend to accrete; keep them test-covered and avoid “silent lossy mapping”.
- **Prompt/stream semantics**: any new `AsyncStream` should be explicit about single-consumer vs broadcast.
- **Server-scoped dependency overrides**: keep overrides narrow and avoid passing entire `DependencyValues` around.

## Suggested Next Refactor Wave (Small and safe)

1. Migrate the following to `actor`:
   - `OnboardingProgressMemoryStore`
   - `HttpWarningPreferencesMemoryStore`
   - any other NSLock-based in-memory boxes used at runtime
2. Document invariants for remaining `@unchecked Sendable` wrappers (especially around system types).
3. Add a Debug-only strict concurrency config (targeted) and fix any new warnings it surfaces.

