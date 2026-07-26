#!/bin/bash
# Setup script for installing Remission git hooks.
# Installs pre-commit and commit-msg hooks for formatting, linting,
# previews, concurrency, dead-code checks, and commit messages.

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
PRE_COMMIT_HOOK="$GIT_HOOKS_DIR/pre-commit"
COMMIT_MSG_HOOK="$GIT_HOOKS_DIR/commit-msg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Git Pre-commit Hooks Setup ===${NC}"
echo ""

# Check if .git directory exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}❌ Error: Not a git repository${NC}"
    echo "   Make sure you run this script from the project root or its subdirectories"
    exit 1
fi

# Check if swift-format is installed
echo "Checking dependencies..."
if ! command -v swift-format &> /dev/null; then
    echo -e "${RED}❌ swift-format not found${NC}"
    echo "   Install using: brew install swift-format"
    DEPS_MISSING=1
else
    SWIFT_FORMAT_VERSION=$(swift-format --version 2>/dev/null | head -1)
    echo -e "${GREEN}✅ swift-format found: $SWIFT_FORMAT_VERSION${NC}"
fi

# Check if swiftlint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found${NC}"
    echo "   Install using: brew install swiftlint"
    DEPS_MISSING=1
else
    SWIFTLINT_VERSION=$(swiftlint version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ SwiftLint found: $SWIFTLINT_VERSION${NC}"
fi

# Check if Periphery is installed
if ! command -v periphery &> /dev/null; then
    echo -e "${RED}❌ Periphery not found${NC}"
    echo "   Required install: brew install peripheryapp/periphery/periphery"
    DEPS_MISSING=1
else
    PERIPHERY_VERSION=$(periphery version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Periphery found: $PERIPHERY_VERSION${NC}"
fi

echo ""

if [ ${DEPS_MISSING:-0} -eq 1 ]; then
    echo -e "${RED}⚠️  Some dependencies are missing. Please install them before continuing.${NC}"
fi

# Ensure hooks directory exists
mkdir -p "$GIT_HOOKS_DIR"

# Set executable permissions on all validation scripts
chmod +x "$SCRIPT_DIR"/validate-*.sh
chmod +x "$SCRIPT_DIR"/check-localizations.sh
chmod +x "$SCRIPT_DIR"/test-platform.sh

# Copy pre-commit hook
echo "Installing pre-commit hook..."
cp "$SCRIPT_DIR/pre-commit" "$PRE_COMMIT_HOOK"
chmod +x "$PRE_COMMIT_HOOK"

# Copy commit-msg hook
echo "Installing commit-msg hook..."
cp "$SCRIPT_DIR/validate-commit-msg.sh" "$COMMIT_MSG_HOOK"
chmod +x "$COMMIT_MSG_HOOK"

echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo -e "${BLUE}=== Configuration ===${NC}"
echo "📁 Hook location: $PRE_COMMIT_HOOK"
echo "📁 Hook location: $COMMIT_MSG_HOOK"
echo "🔧 swift-format config: .swift-format"
echo "🔧 SwiftLint config: .swiftlint.yml"
echo ""

echo -e "${BLUE}=== What this hook does ===${NC}"
echo "Before each commit, the hook will:"
echo "  1️⃣  Check code formatting with swift-format lint --strict"
echo "  2️⃣  Check code style with SwiftLint"
echo "  3️⃣  Check SwiftUI previews for changed views"
echo "  4️⃣  Check obvious Swift 6 concurrency hazards"
echo "  5️⃣  Run strict dead-code and cleanup checks"
echo "  6️⃣  Block the commit if any errors or warnings are found"
echo "Commit messages are checked for Russian Conventional Commits format."
echo ""

echo -e "${BLUE}=== Usage ===${NC}"
echo "✨ Normal workflow:"
echo "   $ git add ."
echo "   $ git commit -m 'Your message'  # Hook will check automatically"
echo ""
echo "⏭️  Skip hook if needed (use with caution):"
echo "   $ git commit --no-verify -m 'Your message'"
echo ""
echo "🔍 Manual checks:"
echo "   $ swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests"
echo "   $ swiftlint lint"
echo "   $ Scripts/validate-swiftui-previews.sh"
echo "   $ Scripts/validate-concurrency-safety.sh"
echo "   $ Scripts/validate-dead-code.sh"
echo ""
echo "🔧 Auto-fix formatting:"
echo "   $ swift-format format --in-place --configuration .swift-format --recursive Remission RemissionTests RemissionUITests"
echo "   $ swiftlint --fix"
echo ""

echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Read the documentation: devdoc/CONTRIBUTING.md (or README.md)"
echo "2. Try making a commit to test the hook"
echo "3. If you need to skip the hook: git commit --no-verify"
echo ""

echo -e "${GREEN}✨ Setup complete! Happy coding! ✨${NC}"
