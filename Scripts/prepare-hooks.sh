#!/bin/bash
# Setup script for installing git hooks (pre-commit with swift-format and swiftlint)
# This script installs pre-commit hook that checks code formatting and style before commit

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
PRE_COMMIT_HOOK="$GIT_HOOKS_DIR/pre-commit"

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
    echo -e "${YELLOW}⚠️  swift-format not found${NC}"
    echo "   Install using: brew install swift-format"
    echo ""
fi

# Check if swiftlint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found${NC}"
    echo "   Install using: brew install swiftlint"
    echo ""
fi

# Ensure hooks directory exists
mkdir -p "$GIT_HOOKS_DIR"

# Copy pre-commit hook
echo "Installing pre-commit hook..."
cp "$SCRIPT_DIR/pre-commit" "$PRE_COMMIT_HOOK"
chmod +x "$PRE_COMMIT_HOOK"

echo -e "${GREEN}✅ Pre-commit hook installed successfully!${NC}"
echo ""
echo -e "${BLUE}=== Configuration ===${NC}"
echo "📁 Hook location: $PRE_COMMIT_HOOK"
echo "🔧 swift-format config: .swift-format"
echo "🔧 swiftlint config: .swiftlint.yml"
echo ""

echo -e "${BLUE}=== What this hook does ===${NC}"
echo "Before each commit, the hook will:"
echo "  1️⃣  Check code formatting with swift-format (--lint mode)"
echo "  2️⃣  Check code style with SwiftLint"
echo "  3️⃣  Block the commit if any violations are found"
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
echo "   $ swiftformat --lint --configuration .swift-format ."
echo "   $ swiftlint lint"
echo ""
echo "🔧 Auto-fix formatting:"
echo "   $ swiftformat --configuration .swift-format ."
echo "   $ swiftlint --fix"
echo ""

echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Read the documentation: devdoc/CONTRIBUTING.md (or README.md)"
echo "2. Try making a commit to test the hook"
echo "3. If you need to skip the hook: git commit --no-verify"
echo ""

echo -e "${GREEN}✨ Setup complete! Happy coding! ✨${NC}"
