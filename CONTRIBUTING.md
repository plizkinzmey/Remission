# Contributing to Remission

## Code Style & Quality

Remission maintains strict code quality standards using automated tools to ensure consistency across the codebase.

### Tools Used

- **swift-format** — Automatic Swift code formatting
- **swiftlint** — Swift style guide enforcement
- **Pre-commit hooks** — Automatic checks before commit

## Setup (First Time)

### 1. Install Required Tools

```bash
# Install swift-format
brew install swift-format

# Install swiftlint
brew install swiftlint
```

### 2. Install Pre-commit Hook

Run the setup script once:

```bash
bash Scripts/prepare-hooks.sh
```

This will:
- ✅ Verify your tools are installed
- ✅ Install the pre-commit hook
- ✅ Show you helpful information

**That's it!** Your git commits will now be checked automatically.

## Workflow

### Normal Commit Flow

```bash
git add .
git commit -m "Добавить новую фичу"  # Hook runs automatically
```

If the hook finds issues, it will:
1. 🛑 **Block the commit**
2. 📝 **Show what's wrong**
3. 💡 **Suggest how to fix it**

### Auto-Fix Issues

Swift-format can auto-fix most formatting issues:

```bash
# Auto-fix formatting
swiftformat --configuration .swift-format .

# Auto-fix some swiftlint violations
swiftlint --fix
```

Then commit again:

```bash
git add .
git commit -m "Исправить стиль кода"  # Should pass now
```

### Manual Checks (Without Committing)

```bash
# Check formatting (doesn't modify files)
swiftformat --lint --configuration .swift-format .

# Check style violations
swiftlint lint

# Show detailed swiftlint report
swiftlint lint --reporter xcode
```

## Skip Hook (Emergency Only)

If you absolutely must bypass the checks:

```bash
git commit --no-verify -m "Emergency commit"
```

⚠️ **Use with caution!** This should only be done in exceptional circumstances.

## Configuration Files

- `.swift-format` — Swift-format configuration (JSON)
- `.swiftlint.yml` — SwiftLint configuration (YAML)
- `Scripts/pre-commit` — Git pre-commit hook implementation
- `Scripts/prepare-hooks.sh` — Hook installation script

For detailed configuration info:
- See `devdoc/SWIFTLINT.md` for SwiftLint rules
- See `devdoc/PRD.md` for project standards

## Troubleshooting

### Hook not running?

Re-install the hook:

```bash
bash Scripts/prepare-hooks.sh
```

### Tools not found?

Make sure they're in your PATH:

```bash
which swift-format
which swiftlint
```

If not found, install them:

```bash
brew install swift-format swiftlint
```

### Apple Silicon (M1/M2/M3) issues?

The hook automatically adds `/opt/homebrew/bin` to PATH. If still having issues:

```bash
# Reinstall tools via Homebrew
brew reinstall swift-format swiftlint
```

### Specific file has formatting issues?

Format just that file:

```bash
swiftformat --configuration .swift-format path/to/file.swift
```

## IDE Integration

### VS Code

Install the "Swift for Visual Studio Code" extension. It will automatically use the `.swift-format` configuration.

### Xcode

SwiftLint is integrated into the Xcode build phase and runs automatically during build.

## Best Practices

1. ✅ Run checks before pushing to make reviews faster
2. ✅ Commit auto-fix changes separately from feature changes
3. ✅ Read error messages carefully — they tell you exactly what's wrong
4. ✅ Keep configuration files up to date with team standards

## Questions?

- 📖 Read the PRD: `devdoc/PRD.md`
- 📖 Read SwiftLint docs: `devdoc/SWIFTLINT.md`
- 📝 Check issue tracker for similar issues

---

**Remember:** These tools help keep our code clean and consistent. They're your teammates! 🚀
