---
name: remission-localization-assets
description: "Add or update localized strings and assets in Remission: manage `Localizable.xcstrings`, follow asset naming conventions, and verify localization checks. Use when touching user-visible text, icons, images, or string catalog entries."
---

# Remission Localization & Assets

## Overview
Use this workflow to add user-visible text and assets safely across iOS/macOS targets with required localization checks.

## Workflow
1. Add or edit strings in the catalog
   - Use `Remission/Localizable.xcstrings` only; do not add .strings files.
   - Keep RU as the default localization.

2. Use generated string symbols in Swift
   - Prefer string catalog symbols if enabled in the target build settings.

3. Add assets
   - Place assets in `Remission/Assets.xcassets`.
   - Use snake_case names (e.g., `icon_start`).

4. Validate localization
   - Run `Scripts/check-localizations.sh` or the Xcode build phase.

## References
- See `references/localization-assets.md` for file locations and commands.
