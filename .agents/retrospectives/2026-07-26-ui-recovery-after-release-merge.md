# UI Recovery After Release Merge

## Outcome

- Restored the presentation layer from `f057820` after the v0.13.0 release merge brought in a stale, broad native-UI rewrite.
- Kept current runtime isolation, HTTP warnings, TCA add-server navigation, and the user-local connection-button styling change.

## What Worked

- Comparing both parents of the release merge identified the UI branch separately from the RPC and test branch.
- A build before test execution exposed the two UI-to-reducer integration points that required manual adaptation.

## Mistakes / Risks

- Test-source mismatches on `HEAD` were repaired narrowly: the add-server test now follows each platform's reducer contract, and XCTest methods no longer use Swift Testing's `@Test` macro.
- iOS ran 487 tests: 484 passed; three failures are unrelated to this UI recovery (an exhausted RPC mock queue, an outdated password-sanitization expectation, and unavailable Keychain entitlement in the simulator). macOS compiled but LaunchServices could not start the test runner in this environment.

## Learned Patterns

- When restoring an older SwiftUI presentation layer, preserve current reducer contracts at the view boundary instead of reverting reducer state or networking code.
- Xcode synchronized groups compile restored source files without a `project.pbxproj` edit.

## Follow-ups

- Manually verify the restored torrent list, server form, settings, and diagnostics on iPhone 12 and macOS.
- Investigate the three unrelated iOS test failures and the local macOS test-runner LaunchServices failure separately.
