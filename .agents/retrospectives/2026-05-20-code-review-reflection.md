# Code Review Reflection Workflow

## Outcome
- Added a mandatory post-implementation review skill and wired it into `AGENTS.md` and `swift-6-xcode-native`.
- Added persistent retrospectives under `.agents/retrospectives/`.
- Added strict `Scripts/validate-dead-code.sh` and connected it to the pre-commit hook.

## What Worked
- Strict Periphery and cleanup gates keep errors and warnings visible and prevent them from entering commits.
- Explicit trigger rules make the review step run after safety gates and before commit.

## Mistakes / Risks
- The existing `swift-6-xcode-native/SKILL.md` contained invalid UTF-8 and duplicated sections, so it had to be normalized before adding the new review rule.
- Periphery originally could not decode this Xcode project because of a `shellScript` field mismatch; converting shell script phases to string values fixed project decoding.

## Learned Patterns
- Agent workflow files under `.agents` may not be visible to Xcode Native, so filesystem edits are acceptable for those metadata paths.
- Dead-code tooling should be strict: findings are either fixed or removed through explicit, reviewed configuration for false positives.

## Follow-ups
- Keep Periphery working as a hard gate and update retain/config rules only when a reported false positive has been verified.
