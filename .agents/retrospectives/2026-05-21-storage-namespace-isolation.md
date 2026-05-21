# Storage Namespace Isolation

## Outcome

- Added runtime storage namespace selection for release, development, unit tests, and UI tests.
- Wired live dependencies through the selected namespace for server config storage, user defaults, keychain credentials, TLS trust, and offline snapshots.
- Added XCTest coverage for release/development namespace separation, environment override, unit-test detection, and DEBUG fallback away from release storage.

## What Worked

- Keeping release names unchanged preserves existing user data.
- Passing the namespace through `AppDependencies.makeLive` keeps storage ownership in dependency wiring instead of spreading direct path decisions through reducers.
- The DEBUG bundle-id regression test caught a real edge case before final verification.

## Mistakes / Risks

- Xcode Native MCP tools were unavailable during the continuation, so shell/filesystem fallback was used.
- Full `swiftlint lint --quiet` is noisy because current untracked build artifacts are inside the repository tree; scoped lint was used for the changed app code and namespace tests.
- `Scripts/validate-dead-code.sh` could not complete Periphery because the current Xcode project contains a `shellScript` shape Periphery could not decode.

## Learned Patterns

- Release namespace must be selected only by explicit override or non-DEBUG release runtime; DEBUG must not trust a release bundle id as sufficient evidence.
- Unit tests should receive unique temporary namespaces so live dependency construction can be tested without touching app data.

## Follow-ups

- Fix the Periphery project decoding issue or adjust the dead-code gate so it can handle the current Xcode project format.
- Exclude generated build/checkouts directories from repository-level SwiftLint scans.
