#!/bin/bash
set -e

echo "🔍 Searching for generated Info.plist..."

DERIVED_DATA=$(xcodebuild -scheme Remission -destination 'platform=macOS,arch=arm64' -showBuildSettings 2>/dev/null | grep -E "DERIVED_DATA_PATH" | head -1 | awk -F= '{print $2}' | xargs)

if [ -z "$DERIVED_DATA" ]; then
  DERIVED_DATA=$(xcodebuild -scheme Remission -destination 'platform=macOS,arch=arm64' -showBuildSettings 2>/dev/null | grep -E "BUILD_DIR" | head -1 | awk -F= '{print $2}' | xargs)
fi

if [ -z "$DERIVED_DATA" ]; then
  echo "❌ Не удалось определить путь DerivedData. Возможно, проект ещё не собирался."
  echo "👉 Выполни: xcodebuild -scheme Remission -configuration Debug build"
  exit 1
fi

echo "📂 DerivedData path: $DERIVED_DATA"

# ищем Info.plist во всех возможных вариантах
INFO_PLIST=$(find "$DERIVED_DATA" -type f -path "*/Remission.app/Contents/Info.plist" | grep "Debug" | head -1)

if [ -z "$INFO_PLIST" ]; then
  INFO_PLIST=$(find "$DERIVED_DATA" -type f -path "*/Remission.app/Info.plist" | grep "Debug" | head -1)
fi

if [ -z "$INFO_PLIST" ]; then
  echo "❌ Не найден Info.plist. Собери проект хотя бы один раз (Debug)."
  echo "👉 Команда: xcodebuild -scheme Remission -configuration Debug build"
  exit 1
fi

echo "✅ Найден Info.plist: $INFO_PLIST"

CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "0")
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_VERSION="$CURRENT_VERSION"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$INFO_PLIST" || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $NEW_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$INFO_PLIST" || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $NEW_BUILD" "$INFO_PLIST"

echo "✅ Версия обновлена: $NEW_VERSION ($NEW_BUILD)"
