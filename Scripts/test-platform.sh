#!/usr/bin/env bash
set -euo pipefail

PROJECT="/Users/plizkinzmey/SRC/Remission/Remission.xcodeproj"
SCHEME="Remission"

usage() {
  cat <<USAGE
Usage:
  Scripts/test-platform.sh macos-unit
  Scripts/test-platform.sh macos-ui
  Scripts/test-platform.sh macos-all
  Scripts/test-platform.sh ios-sim [simulator-name]

Examples:
  Scripts/test-platform.sh macos-unit
  Scripts/test-platform.sh macos-ui
  Scripts/test-platform.sh ios-sim "iPhone 16e"
USAGE
}

mode="${1:-}"
if [[ -z "$mode" ]]; then
  usage
  exit 1
fi

case "$mode" in
  macos-unit)
    xcodebuild test \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -testPlan Remission.Unit \
      -sdk macosx \
      -destination 'platform=macOS,arch=arm64' \
      -destination-timeout 5
    ;;

  macos-ui)
    xcodebuild test \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -sdk macosx \
      -destination 'platform=macOS,arch=arm64' \
      -destination-timeout 5 \
      -only-testing:RemissionUITests
    ;;

  macos-all)
    "$0" macos-unit
    "$0" macos-ui
    ;;

  ios-sim)
    simulator="${2:-iPhone 16e}"
    xcodebuild test \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -sdk iphonesimulator \
      -destination "platform=iOS Simulator,name=${simulator}" \
      -destination-timeout 30
    ;;

  *)
    echo "Unknown mode: $mode" >&2
    usage
    exit 1
    ;;
esac
