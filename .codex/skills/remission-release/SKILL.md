---
name: remission-release
description: Run a Remission release using Scripts/release_local.sh, including version bumping, tagging, pushing, and artifact locations.
metadata:
  short-description: Remission release workflow
---

# Remission Release

Use this skill when the user asks to cut a release (minor/patch/major) for Remission.

## Preconditions

- On `main` branch.
- Clean git status.

## Recommended command

Default release (minor/patch/major) with tag and push:

```bash
Scripts/release_local.sh --bump minor --tag --push
```

## Variants

- Specific version:
  ```bash
  Scripts/release_local.sh --version X.Y.Z --tag --push
  ```
- Version bump without auto-commit:
  ```bash
  Scripts/release_local.sh --version X.Y.Z --no-version-commit
  ```

## Output

Artifacts are written to:

```
Build/Releases/vX.Y.Z/
```

## Notes

- The script updates `Remission.xcodeproj/project.pbxproj` with the version and can create a version commit.
- A release is considered valid only when the git tag `vX.Y.Z` exists (use `--tag`, and usually `--push`).
