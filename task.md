# Task: UI Recovery After Release Merge

Restore the pre-merge presentation layer while retaining release functional changes.

## Status
- [x] Investigate v0.13.0 merge graph and identify `f057820` as UI baseline
- [x] Restore presentation-layer sources with functional deltas preserved
- [x] Run format, lint, iOS/macOS tests, and post-implementation review

## Details
- Repository: Remission
- Platforms: iOS 26, macOS 26
- Pattern: Native Onboarding (NavigationStack + ContentUnavailableView) + Fixed-size Initial Window (macOS)
