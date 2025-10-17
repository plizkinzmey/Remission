#!/bin/bash
# Quick setup script for SwiftLint integration

echo "=== SwiftLint Setup ==="
echo ""

# Check if swiftlint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "❌ SwiftLint not found. Installing via Homebrew..."
    brew install swiftlint
else
    SWIFTLINT_VERSION=$(swiftlint --version)
    echo "✅ SwiftLint found: $SWIFTLINT_VERSION"
fi

echo ""
echo "=== Running SwiftLint Lint Check ==="
cd "$(dirname "$0")/.." || exit 1

swiftlint lint --reporter xcode

echo ""
echo "=== Summary ==="
echo "✅ SwiftLint is configured and integrated into Xcode build phases"
echo "📖 For more information, see: devdoc/SWIFTLINT.md"
echo "📖 For configuration details, see: .swiftlint.yml"
