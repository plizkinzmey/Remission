---
name: code-review-reflection
description: "Mandatory post-implementation review and retrospective workflow for Remission. Use after code changes and before commit to check duplicates, dead code, Swift 6/TCA correctness, overengineering, API freshness, tests, and to write a persistent retrospective."
---

# Code Review & Reflection

Use this skill after implementation and verification, before staging or committing changes. The goal is to switch from writer mode to reviewer mode and find problems the implementation pass may have missed.

## Trigger

Run this workflow when any of these are true:

- A feature, bugfix, refactor, test change, or SwiftUI view change is complete.
- The user asks for review, ретроспектива, рефлексия, quality pass, or "проверь что не сломали".
- A commit is about to be created.

Order:

1. Finish the implementation.
2. Run the normal safety gates: formatting, linting, build, relevant tests.
3. Run this post-implementation review.
4. Fix any real findings.
5. Write/update the retrospective.
6. Commit only after the remaining risks are explicit.

## Tool Rules

- For Swift project files, use Xcode Native tools first: `XcodeRead`, `XcodeGrep`, `XcodeUpdate`, `BuildProject`, `XcodeListNavigatorIssues`, `RunSomeTests`.
- For repo metadata, shell scripts, `.agents`, `AGENTS.md`, `task.md`, `implementation_plan.md`, and retrospectives, filesystem tools are allowed.
- Use Context7 or current official documentation only for API freshness checks. Do not use documentation lookup as a substitute for reviewing local code.
- If a tool is unavailable, record the limitation in the final review notes.

## Review Checklist

### 1. Behavioral Correctness

- Re-read the changed reducers, views, repositories, and tests.
- Confirm the code implements only the approved plan and does not create hidden behavior changes.
- Verify edge states: empty, loading, error, cancellation, offline/cache, repeated actions.

Minimum search:
- For every changed reducer action, search the action name and delegate path.
- For every changed dependency, search its live, test, and preview overrides.

### 2. Duplicate Logic

- Search for equivalent functions, view components, formatting helpers, validation logic, and mapping code.
- Prefer existing local helpers over new parallel abstractions.
- If duplication remains, justify why it is intentionally separate.

Minimum search:
- For each new function/type name, run a project-wide search.
- For each non-trivial new condition or formatter, search by the key field names and literals.

### 3. Dead Code and Stale Paths

- Run `Scripts/validate-dead-code.sh`.
- Treat Periphery findings, scan failures, TODO/FIXME markers, compiler warnings, and linter warnings as blockers.
- Do not hide or downgrade real tool warnings. Fix them before commit, or make an explicit, reviewed project configuration change that removes the false positive from future output.
- Keep local heuristic output visible as review notes. If a note points to a real issue, fix the issue and make the note disappear through code improvement or a better detector.
- Do not remove code only because Periphery reports it; verify usage across SwiftUI previews, tests, App entry points, platform-specific code, and reflection/dynamic hooks.

Minimum search:
- Search newly deleted/renamed symbols.
- Search old code paths that should no longer be reachable.
- Check staged TODO/FIXME items in changed files.

### 4. Swift 6 Strict Concurrency

- Apply the Swift 6 rules from `.agents/skills/swift-6-xcode-native/SKILL.md` and `.agents/skills/swift-concurrency/SKILL.md`.
- Check `Sendable`, `@MainActor`, actor isolation, `@Sendable` closures, mutable global state, and captures in `.run` effects.
- Avoid `@unchecked Sendable`, `nonisolated(unsafe)`, `Task.detached`, blocking waits, and broad `@MainActor` unless justified.

Minimum search:
- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `Task.detached`
- `DispatchQueue.sync`
- `Semaphore`
- top-level mutable `var`

### 5. TCA Architecture

- State and actions should remain `Sendable`.
- Reducers must not perform live work directly; use dependencies.
- Effects should capture immutable state before `.run`.
- Navigation and presentation should follow existing App/Server/Torrent feature boundaries.
- Tests should use `TestStoreFactory` and dependency overrides rather than real network/keychain/file state.

Minimum search:
- Changed reducer actions and effects.
- Changed dependency keys and live/test/preview values.
- Any new direct `URLSession`, `Keychain`, file IO, or singleton usage.

### 6. SwiftUI and Preview Quality

- Every new screen and input form must have `#Preview` with mock data or preview dependencies.
- Views should keep state ownership clear and avoid expensive work in `body`.
- Check layout for duplicated ad-hoc styling that should be a local component.
- **UI Metrics & Sizing Space Budget**: Verify that window/view minimum sizes are selected based on a precise element space budget analysis (e.g. at least 920px for multi-column lists) to prevent any text truncation, speed value squeezing, or button overlapping. Do not use generic layout sizes blindly.
- **Code Cleanliness & SRP**: Check that dynamic frame metrics are encapsulated into distinct enums/structs (e.g., `AppWindowMetrics`) instead of cluttering SwiftUI declarative layout tree with ternary expressions.
- **Isolation of AppKit Logic**: Verify that platform-specific window styling and delegate configuration closures are extracted from SwiftUI `body` into clean helper methods.

Minimum search:
- New/changed `struct ...: View`.
- `#Preview`.
- Heavy formatting/sorting/filtering inside `body`.

### 7. Simplicity and Overengineering

- Remove speculative abstractions, unused genericity, unnecessary protocols, and "future-proof" parameters that are not used by the current behavior.
- Keep the smallest implementation that satisfies tests and product behavior.

### 8. Tests and Verification

- Confirm the test added for TDD fails for the original bug/feature gap and passes after implementation.
- Run the narrowest relevant tests plus build.
- If full test execution is skipped, record why and what remains unverified.

## Retrospective

Write a persistent retrospective for every non-trivial task:

Path:

```text
.agents/retrospectives/YYYY-MM-DD-<short-task-name>.md
```

Keep it concise:

```markdown
# <Task>

## Outcome
- What changed.

## What Worked
- Specific practices or decisions that helped.

## Mistakes / Risks
- Bugs found, weak assumptions, or verification gaps.

## Learned Patterns
- Reusable repo-specific lessons.

## Follow-ups
- Concrete remaining work, or "None".
```

If the task is too small for a full file, add a short note to the final response instead of creating noise.

## Output

In the final response, include:

- Review result: passed or failed. Do not finish with unresolved warnings.
- Real issues found and fixed.
- Verification commands/tools used.
- Retrospective path when created.
