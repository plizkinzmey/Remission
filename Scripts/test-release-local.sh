#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/Scripts/release_local.sh"

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    printf 'Expected failure but command succeeded: %s\n' "$*" >&2
    exit 1
  fi
  grep -F -- "$expected" <<<"$output" >/dev/null || {
    printf 'Expected error not found: %s\nOutput:\n%s\n' "$expected" "$output" >&2
    exit 1
  }
}

bash -n "$SCRIPT"
"$SCRIPT" --help >/dev/null
expect_failure \
  "--no-version-commit нельзя использовать вместе" \
  "$SCRIPT" --version 1.2.3 --no-version-commit --tag
expect_failure \
  "--github-release требует --push" \
  "$SCRIPT" --version 1.2.3 --github-release
expect_failure \
  "--push требует --tag" \
  "$SCRIPT" --version 1.2.3 --push
expect_failure \
  "--allow-dirty нельзя использовать" \
  "$SCRIPT" --version 1.2.3 --allow-dirty --tag --push
expect_failure \
  "--version требует значения" \
  "$SCRIPT" --version
expect_failure \
  "--version-only нельзя комбинировать" \
  "$SCRIPT" --version 1.2.3 --version-only --skip-build

grep -F 'run_xcodebuild_logged' "$SCRIPT" >/dev/null
grep -F 'validate_artifacts' "$SCRIPT" >/dev/null
grep -F 'require_remote_sync' "$SCRIPT" >/dev/null

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
repo="$fixture/repo"
bare="$fixture/origin.git"
bin="$fixture/bin"
mkdir -p "$repo/Scripts" "$repo/Remission.xcodeproj" "$bin"
git init --bare -q "$bare"
git init -q -b main "$repo"
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name ReleaseTest
git -C "$repo" remote add origin "$bare"
printf 'MARKETING_VERSION = 1.0.0;\nCURRENT_PROJECT_VERSION = 1;\n' > "$repo/Remission.xcodeproj/project.pbxproj"
printf '%s\n' '<plist><dict><key>method</key><string>development</string></dict></plist>' > "$repo/ExportOptions.plist"
printf 'Build/\n' > "$repo/.gitignore"
git -C "$repo" add .
git -C "$repo" commit -q -m initial
git -C "$repo" branch develop
git -C "$repo" push -q origin main develop
cp "$SCRIPT" "$repo/Scripts/release_local.sh"
git -C "$repo" add Scripts/release_local.sh
git -C "$repo" commit -q -m 'add release script fixture'
git -C "$repo" push -q origin main develop

cat > "$bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" -exportArchive "* ]]; then
  echo "simulated iOS export failure" >&2
  exit 42
fi
archive_path=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-archivePath" ]]; then archive_path="$2"; shift 2; continue; fi
  shift
done
mkdir -p "$archive_path/Products/Applications/Remission.app"
exit 0
EOF
chmod +x "$bin/xcodebuild"

initial_commit="$(git -C "$repo" rev-parse HEAD)"
expect_failure \
  "iOS export неуспешен" \
  env PATH="$bin:$PATH" bash "$repo/Scripts/release_local.sh" --version 1.0.1 --platform all
[[ "$(git -C "$repo" rev-parse HEAD)" == "$initial_commit" ]]
grep -Fxq 'MARKETING_VERSION = 1.0.0;' "$repo/Remission.xcodeproj/project.pbxproj"
test -s "$repo/Build/Releases/v1.0.1/ios-export.log"
rm -rf "$repo/Build"
expect_failure \
  "Не найден metadata.txt для recovery" \
  env PATH="$bin:$PATH" bash "$repo/Scripts/release_local.sh" --version 1.0.0 --platform all --skip-build

env PATH="$bin:$PATH" bash "$repo/Scripts/release_local.sh" --version 1.0.2 --platform macos
release_head="$(git -C "$repo" rev-parse HEAD)"
grep -Fxq "commit=${release_head}" "$repo/Build/Releases/v1.0.2/metadata.txt"
grep -Fxq 'phase=develop_synced' "$repo/Build/Releases/v1.0.2/release-state.txt"
zip_entries="$(unzip -Z1 "$repo/Build/Releases/v1.0.2/Remission-macOS-v1.0.2.zip")"
grep -Eq '(^|/)Remission\.app/' <<<"$zip_entries"
git -C "$repo" push -q origin main

env PATH="$bin:$PATH" bash "$repo/Scripts/release_local.sh" \
  --version 1.0.2 --platform macos --skip-build --tag
tagged_head="$(git -C "$repo" rev-parse HEAD)"
[[ "$tagged_head" == "$release_head" ]]
[[ "$(git -C "$repo" cat-file -t v1.0.2)" == "tag" ]]
env PATH="$bin:$PATH" bash "$repo/Scripts/release_local.sh" \
  --version 1.0.2 --platform macos --skip-build --tag
[[ "$(git -C "$repo" rev-parse HEAD)" == "$release_head" ]]

echo "release-local smoke tests: PASS"
