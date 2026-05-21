---
name: swift-6-xcode-native
description: "Swift 6, TCA, Xcode Native, safety-gate, preview, post-review, and commit-hygiene workflow for Remission. Use for all Swift code changes, refactors, tests, diagnostics, and pre-commit validation."
---

# Swift 6 & Xcode Native Development Guidelines

This skill is mandatory for Remission development. Remission is a Swift 6 SwiftUI app using TCA and swift-dependencies, so all code changes must preserve strict concurrency safety, testability, previewability, and Xcode project state.

## 1. Xcode Native First

Use Xcode Native MCP tools for project code:

- Read Swift/project files with `XcodeRead`.
- Search Swift/project files with `XcodeGrep` or `XcodeLS`.
- Edit Swift/project files with `XcodeUpdate` or `XcodeWrite`.
- Build with `BuildProject`.
- Inspect diagnostics with `XcodeListNavigatorIssues`.
- Run tests with `RunSomeTests` or the available Xcode test tool.

Allowed filesystem exceptions:

- `.agents/**`
- `AGENTS.md`
- `Scripts/**`
- `.swift-format`, `.swiftlint.yml`, git hooks, Markdown plans/tasks/retrospectives
- Cases where the Xcode Native tool cannot see the file.

For iOS simulator work, use iPhone 12.

## 2. Swift 6 Strict Concurrency

The project is compiled in Swift 6 mode. Treat concurrency warnings as correctness issues.

Required checks:

- Types crossing isolation boundaries must be `Sendable`.
- Reducer `State` and `Action` should be `Sendable`.
- Dependency clients and closures stored in dependencies must be `Sendable`.
- UI state mutations belong on the main actor or inside TCA state transitions.
- Capture immutable local values before entering `.run` effects.
- Prefer structured concurrency (`async let`, task groups, cancellable TCA effects) over unstructured work.

Avoid unless explicitly justified:

- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `Task.detached`
- `DispatchQueue.sync`
- `Semaphore.wait()`
- mutable top-level `var`
- broad `@MainActor` used only to silence the compiler.

## 3. TCA Architecture

Keep feature logic inside reducers and side effects inside dependencies.

- Do not call live network, Keychain, file storage, or singleton services directly from views/reducers.
- Use `DependencyValues` and server-scoped `ServerConnectionEnvironment` for runtime wiring.
- Effects should send explicit actions and remain cancellable where user actions can supersede them.
- Navigation should stay in the existing App/Server/Torrent ownership boundaries.
- Tests should use `TestStoreFactory` and deterministic dependencies.

Effect capture pattern:

```swift
let serverID = state.server.id
return .run { send in
    let result = await client.load(serverID)
    await send(.response(result))
}
```

## 4. TDD and Verification

For new behavior or bug fixes:

1. Write or update the test first.
2. Confirm it fails or does not compile for the missing behavior.
3. Implement the smallest passing change.
4. Refactor with tests still passing.

Before finishing:

- Run `swift-format` for changed Swift paths.
- Run `swiftlint`.
- Build with `BuildProject`.
- Run relevant tests with `RunSomeTests`.
- Inspect `XcodeListNavigatorIssues`.

If a gate cannot run, record the reason and residual risk.

## 5. SwiftUI Previews

Every new screen and input form must include `#Preview`.

Preview rules:

- Use mock data or `AppDependencies.makePreview()`.
- Do not call live Transmission servers, Keychain, or real file stores.
- Include meaningful states for complex screens: loaded, empty, loading, error.
- Keep previews fast and deterministic.

## 6. Safe Workflow and Commit Hygiene

Development must happen on an isolated branch:

- `feat/*` for features.
- `fix/*` for bug fixes.
- `refactor/*` for refactors.

Do not commit directly to `main`.

For non-trivial work:

- Create/update `implementation_plan.md`.
- Track progress in `task.md`.
- Keep commits atomic.
- Use Conventional Commits in Russian for subject and body, for example:

```text
fix(diagnostics): исправить гонку при обновлении фильтра

Причина и архитектурное решение описываются в теле коммита.
```

## 7. Post-Implementation Review

After implementation and normal safety gates, run `.agents/skills/code-review-reflection/SKILL.md` before committing.

This review is mandatory for non-trivial changes and should check:

- duplicate logic,
- dead code and stale paths,
- Swift 6 strict concurrency,
- TCA boundaries,
- SwiftUI previews,
- overengineering,
- API freshness when new or changed APIs are involved,
- test coverage and verification gaps.

Use `Scripts/validate-dead-code.sh` as the strict dead-code gate. Periphery findings, scan failures, TODO/FIXME markers, compiler warnings, and linter warnings block commits until fixed. Do not hide or downgrade real tool warnings; fix them or make an explicit reviewed configuration change for a false positive. Local heuristic output may be shown as review notes, but must remain visible.

Write a persistent retrospective for non-trivial tasks:

```text
.agents/retrospectives/YYYY-MM-DD-<short-task-name>.md
```

The retrospective should capture outcome, what worked, mistakes/risks, learned patterns, and follow-ups.
