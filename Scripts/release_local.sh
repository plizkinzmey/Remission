#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  Scripts/release_local.sh --version X.Y.Z [--tag] [--push] [--export-options-plist PATH]
  Scripts/release_local.sh --bump {major|minor|patch} [--tag] [--push] [--export-options-plist PATH]

Builds:
  - iOS IPA (via xcodebuild archive + exportArchive)
  - macOS app zip (from .xcarchive Products/Applications)

Rules:
  - Only runs from branch 'main'
  - Requires clean git working tree unless --allow-dirty is set

Outputs:
  Build/Releases/vX.Y.Z/
    - ios/Remission.ipa (or exported contents)
    - macos/Remission.app + Remission-macOS-vX.Y.Z.zip
    - metadata.txt

Notes:
  - iOS export signing depends on your certificates/profiles and export options plist.
EOF
}

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "ℹ️  $*"; }
ok() { echo "✅ $*"; }

run() {
  # shellcheck disable=SC2068
  "$@"
}

pipe_xcbeautify_if_available() {
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify
  else
    cat
  fi
}

require_branch_main() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == "main" ]] || die "Release разрешён только из ветки 'main' (сейчас: $branch)."
}

require_clean_tree() {
  local allow_dirty="$1"
  if [[ "$allow_dirty" == "true" ]]; then
    return 0
  fi
  [[ -z "$(git status --porcelain)" ]] || die "Рабочая директория не чистая. Закоммить/сташни изменения или используй --allow-dirty."
}

last_tag_version() {
  local tag
  tag="$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || true)"
  if [[ -z "$tag" ]]; then
    echo "0.0.0"
    return 0
  fi
  echo "${tag#v}"
}

semver_bump() {
  local version="$1"
  local part="$2"

  IFS='.' read -r major minor patch <<<"$version"
  [[ -n "${major:-}" && -n "${minor:-}" && -n "${patch:-}" ]] || die "Некорректная версия: $version (ожидаю X.Y.Z)"

  case "$part" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) die "Некорректный bump: $part (ожидаю major|minor|patch)" ;;
  esac

  echo "${major}.${minor}.${patch}"
}

compute_build_number() {
  # Stable integer for CFBundleVersion: commit count in repo.
  git rev-list --count HEAD
}

main() {
  local version=""
  local bump=""
  local tag="false"
  local push="false"
  local allow_dirty="false"
  local export_options_plist="ExportOptions.plist"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) version="${2:-}"; shift 2 ;;
      --bump) bump="${2:-}"; shift 2 ;;
      --tag) tag="true"; shift ;;
      --push) push="true"; shift ;;
      --allow-dirty) allow_dirty="true"; shift ;;
      --export-options-plist) export_options_plist="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Неизвестный аргумент: $1 (см. --help)" ;;
    esac
  done

  [[ -n "$version" || -n "$bump" ]] || { usage; exit 1; }
  [[ -z "$version" || -z "$bump" ]] || die "Используй либо --version, либо --bump (не вместе)."

  require_branch_main
  require_clean_tree "$allow_dirty"

  [[ -f "$export_options_plist" ]] || die "Не найден export options plist: $export_options_plist"

  if [[ -n "$bump" ]]; then
    local last
    last="$(last_tag_version)"
    version="$(semver_bump "$last" "$bump")"
  fi

  [[ "$version" =~ ^[0-9]+\\.[0-9]+\\.[0-9]+$ ]] || die "Некорректная версия: $version (ожидаю X.Y.Z)"

  local build_number
  build_number="$(compute_build_number)"

  local release_tag="v${version}"
  local out_dir="Build/Releases/${release_tag}"
  local ios_dir="${out_dir}/ios"
  local macos_dir="${out_dir}/macos"

  run mkdir -p "$ios_dir" "$macos_dir"

  info "Версия: ${version} (build: ${build_number})"
  info "Export options plist: ${export_options_plist}"
  info "Output: ${out_dir}"

  local ios_archive="${out_dir}/Remission-iOS.xcarchive"
  local macos_archive="${out_dir}/Remission-macOS.xcarchive"

  info "Архивирую iOS…"
  run xcodebuild \
    -project Remission.xcodeproj \
    -scheme Remission \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ios_archive" \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build_number" \
    archive | pipe_xcbeautify_if_available

  info "Экспортирую iOS IPA…"
  run xcodebuild \
    -exportArchive \
    -archivePath "$ios_archive" \
    -exportOptionsPlist "$export_options_plist" \
    -exportPath "$ios_dir" | pipe_xcbeautify_if_available

  info "Архивирую macOS…"
  run xcodebuild \
    -project Remission.xcodeproj \
    -scheme Remission \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$macos_archive" \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build_number" \
    archive | pipe_xcbeautify_if_available

  info "Собираю macOS zip…"
  local macos_app="${macos_archive}/Products/Applications/Remission.app"
  [[ -d "$macos_app" ]] || die "Не найден .app в archive: $macos_app"

  run rm -rf "${macos_dir}/Remission.app"
  run cp -R "$macos_app" "${macos_dir}/Remission.app"

  local macos_zip="${out_dir}/Remission-macOS-${release_tag}.zip"
  (cd "$macos_dir" && run ditto -c -k --sequesterRsrc --keepParent "Remission.app" "$macos_zip")

  {
    echo "tag=${release_tag}"
    echo "version=${version}"
    echo "build_number=${build_number}"
    echo "commit=$(git rev-parse HEAD)"
    echo "export_options_plist=${export_options_plist}"
    echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"${out_dir}/metadata.txt"

  if [[ "$tag" == "true" ]]; then
    git tag -a "$release_tag" -m "Release $release_tag"
    ok "Создан git tag: $release_tag"
  fi

  if [[ "$push" == "true" ]]; then
    [[ "$tag" == "true" ]] || die "--push требует --tag (чтобы пушить именно тег релиза)."
    git push origin main
    git push origin "$release_tag"
    ok "Запушены main и тег $release_tag"
  fi

  ok "Готово: ${out_dir}"
}

main "$@"

