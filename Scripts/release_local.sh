#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  Scripts/release_local.sh --version X.Y.Z [--tag] [--push] [--github-release] [--pre-release] [--draft] [--skip-build] [--export-options-plist PATH]
  Scripts/release_local.sh --bump {major|minor|patch} [--tag] [--push] [--github-release] [--pre-release] [--draft] [--skip-build] [--export-options-plist PATH]
  Scripts/release_local.sh --version X.Y.Z --no-version-commit [--tag] [--push]
  Scripts/release_local.sh --version X.Y.Z --version-only [--no-version-commit]

  Scripts/release_local.sh --version X.Y.Z --platform {all|ios|macos}

Builds:
  - iOS IPA (via xcodebuild archive + exportArchive)
  - macOS app zip (from .xcarchive Products/Applications)

Rules:
  - Only runs from branch 'main'
  - Requires clean git working tree unless --allow-dirty is set

Options:
  --github-release  Create a GitHub release and upload built artifacts (requires 'gh' CLI).
  --pre-release     Mark the GitHub release as a pre-release.
  --draft           Create the GitHub release as a draft (not published).
  --skip-build      Skip the building process and only perform tagging/pushing/releasing (requires existing artifacts).

Outputs:
  Build/Releases/vX.Y.Z/
    - ios/Remission.ipa (or exported contents)
    - macos/Remission.app + Remission-macOS-vX.Y.Z.zip
    - metadata.txt

Notes:
  - iOS export signing depends on your certificates/profiles and export options plist.
  - Скрипт обновляет MARKETING_VERSION/CURRENT_PROJECT_VERSION в project.pbxproj и делает коммит,
    если не указан --no-version-commit.
  - --version-only обновляет версию (и опционально коммитит) без сборки.
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

SKIP_WORKTREE_RESTORE="false"
ASSUME_UNCHANGED_RESTORE="false"

update_project_versions() {
  local pbxproj="$1"
  local version="$2"

  local flag
  flag="$(git ls-files -v "$pbxproj" | awk '{print $1}')"
  
  # S/s = skip-worktree, h = assume-unchanged
  if [[ "$flag" == "S" || "$flag" == "s" ]]; then
    SKIP_WORKTREE_RESTORE="true"
    git update-index --no-skip-worktree "$pbxproj"
  elif [[ "$flag" == "h" ]]; then
    ASSUME_UNCHANGED_RESTORE="true"
    git update-index --no-assume-unchanged "$pbxproj"
  fi

  VERSION="$version" BUILD_NUMBER="$build_number" PBXPROJ="$pbxproj" python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["PBXPROJ"])
version = os.environ["VERSION"]
build_number = os.environ["BUILD_NUMBER"]
text = path.read_text()
text = re.sub(
    r"(MARKETING_VERSION\s*=\s*)([^;]+);",
    rf"\g<1>{version};",
    text,
)
text = re.sub(
    r"(CURRENT_PROJECT_VERSION\s*=\s*)([^;]+);",
    rf"\g<1>{build_number};",
    text,
)
path.write_text(text)
PY
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
  local version_commit="true"
  local version_only="false"
  local export_options_plist="ExportOptions.plist"
  local platform="all"
  local github_release="false"
  local pre_release="false"
  local draft="false"
  local skip_build="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) version="${2:-}"; shift 2 ;;
      --bump) bump="${2:-}"; shift 2 ;;
      --tag) tag="true"; shift ;;
      --push) push="true"; shift ;;
      --allow-dirty) allow_dirty="true"; shift ;;
      --no-version-commit) version_commit="false"; shift ;;
      --version-only) version_only="true"; shift ;;
      --export-options-plist) export_options_plist="${2:-}"; shift 2 ;;
      --platform) platform="${2:-}"; shift 2 ;;
      --github-release) github_release="true"; shift ;;
      --pre-release) pre_release="true"; shift ;;
      --draft) draft="true"; shift ;;
      --skip-build) skip_build="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "Неизвестный аргумент: $1 (см. --help)" ;;
    esac
  done

  [[ -n "$version" || -n "$bump" ]] || { usage; exit 1; }
  [[ -z "$version" || -z "$bump" ]] || die "Используй либо --version, либо --bump (не вместе)."

  if [[ "$github_release" == "true" ]]; then
    command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) не установлен. Установите его через 'brew install gh'."
    gh auth status >/dev/null 2>&1 || die "Вы не авторизованы в GitHub CLI. Выполните 'gh auth login'."

    # Xcode/SwiftPM can opportunistically rewrite workspace SwiftPM files while CLI tools
    # (including `gh`) probe git state, which may temporarily delete a tracked Package.resolved.
    # Keep the release script strict about cleanliness, but auto-restore this known-volatile file.
    git checkout -- Remission.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null || true
  fi

  require_branch_main
  require_clean_tree "$allow_dirty"

  if [[ -n "$bump" ]]; then
    local last
    last="$(last_tag_version)"
    version="$(semver_bump "$last" "$bump")"
  fi

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Некорректная версия: $version (ожидаю X.Y.Z)"

  local pbxproj="${ROOT_DIR}/Remission.xcodeproj/project.pbxproj"
  [[ -f "$pbxproj" ]] || die "Не найден project.pbxproj: $pbxproj"

  local build_number_base
  build_number_base="$(compute_build_number)"
  local build_number="$build_number_base"
  if [[ "$version_commit" == "true" ]]; then
    build_number=$((build_number_base + 1))
  fi

  update_project_versions "$pbxproj" "$version"
  ok "Обновлена версия в project.pbxproj: ${version}"

  if git diff --quiet -- "$pbxproj"; then
    info "project.pbxproj не изменился после обновления версии."
  else
    if [[ "$version_commit" == "true" ]]; then
      git add "$pbxproj"
      git commit -m "Обновить версию ${version}"
      ok "Закоммичена версия ${version}"
    else
      info "project.pbxproj обновлён, но не закоммичен (--no-version-commit)."
    fi
  fi

  if [[ "$SKIP_WORKTREE_RESTORE" == "true" ]]; then
    git update-index --skip-worktree "$pbxproj"
  fi
  if [[ "$ASSUME_UNCHANGED_RESTORE" == "true" ]]; then
    git update-index --assume-unchanged "$pbxproj"
  fi

  if [[ "$version_only" == "true" ]]; then
    ok "Версия обновлена, сборка пропущена (--version-only)."
    exit 0
  fi

  case "$platform" in
    all|ios|macos) ;;
    *) die "Некорректный --platform: $platform (ожидаю all|ios|macos)" ;;
  esac

  if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
    [[ -f "$export_options_plist" ]] || die "Не найден export options plist: $export_options_plist"
  fi

  local release_tag="v${version}"
  local out_dir="Build/Releases/${release_tag}"
  local ios_dir="${out_dir}/ios"
  local macos_dir="${out_dir}/macos"

  run mkdir -p "$ios_dir" "$macos_dir"

  info "Версия: ${version} (build: ${build_number})"
  if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
    info "Export options plist: ${export_options_plist}"
  fi
  info "Output: ${out_dir}"

  local ios_archive="${out_dir}/Remission-iOS.xcarchive"
  local macos_archive="${out_dir}/Remission-macOS.xcarchive"

  local ios_ok="skipped"
  local macos_ok="skipped"

  if [[ "$skip_build" == "true" ]]; then
    info "⏩ Пропускаю сборку (--skip-build). Использую существующие артефакты."
    [[ -d "$out_dir" ]] || die "Директория с релизом не найдена: $out_dir. Нечего выпускать без сборки."
    ios_ok="true"
    macos_ok="true"
  else
    if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
      ios_ok="true"
      info "Архивирую iOS…"
      if ! run xcodebuild \
        -project Remission.xcodeproj \
        -scheme Remission \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$ios_archive" \
        -allowProvisioningUpdates \
        -allowProvisioningDeviceRegistration \
        MARKETING_VERSION="$version" \
        CURRENT_PROJECT_VERSION="$build_number" \
        archive | pipe_xcbeautify_if_available; then
        ios_ok="false"
      fi

      if [[ "$ios_ok" == "true" ]]; then
        info "Экспортирую iOS IPA…"
        if ! run xcodebuild \
          -exportArchive \
          -archivePath "$ios_archive" \
          -exportOptionsPlist "$export_options_plist" \
          -allowProvisioningUpdates \
          -allowProvisioningDeviceRegistration \
          -exportPath "$ios_dir" | pipe_xcbeautify_if_available; then
          ios_ok="false"
        fi
      fi
    fi

    if [[ "$platform" == "all" || "$platform" == "macos" ]]; then
      macos_ok="true"
      info "Архивирую macOS…"
      if ! run xcodebuild \
        -project Remission.xcodeproj \
        -scheme Remission \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$macos_archive" \
        MARKETING_VERSION="$version" \
        CURRENT_PROJECT_VERSION="$build_number" \
        archive | pipe_xcbeautify_if_available; then
        macos_ok="false"
      fi

      if [[ "$macos_ok" == "true" ]]; then
        info "Собираю macOS zip…"
        local macos_app="${macos_archive}/Products/Applications/Remission.app"
        [[ -d "$macos_app" ]] || die "Не найден .app в archive: $macos_app"

        run rm -rf "${macos_dir}/Remission.app"
        run cp -R "$macos_app" "${macos_dir}/Remission.app"

        local macos_zip="${out_dir}/Remission-macOS-${release_tag}.zip"
        run ditto -c -k --sequesterRsrc --keepParent "${macos_dir}/Remission.app" "$macos_zip"
      fi
    fi
  fi

  {
    echo "tag=${release_tag}"
    echo "version=${version}"
    echo "build_number=${build_number}"
    echo "commit=$(git rev-parse HEAD)"
    echo "platform=${platform}"
    if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
      echo "export_options_plist=${export_options_plist}"
    fi
    echo "ios_ok=${ios_ok}"
    echo "macos_ok=${macos_ok}"
    echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"${out_dir}/metadata.txt"

  if [[ "$tag" == "true" ]]; then
    if [[ "$ios_ok" != "true" && "$platform" != "macos" ]]; then
      die "iOS сборка неуспешна; тег не создан. Исправь подпись iOS или запусти с --platform macos."
    fi
    if [[ "$macos_ok" != "true" && "$platform" != "ios" ]]; then
      die "macOS сборка неуспешна; тег не создан."
    fi
    git tag -a "$release_tag" -m "Release $release_tag"
    ok "Создан git tag: $release_tag"
  fi

  if [[ "$push" == "true" ]]; then
    [[ "$tag" == "true" ]] || die "--push требует --tag (чтобы пушить именно тег релиза)."
    git push origin main
    git push origin "$release_tag"
    ok "Запушены main и тег $release_tag"
  fi

  # Sync develop branch with the new version
  if git show-ref --verify --quiet refs/heads/develop; then
    info "🔄 Синхронизирую версию в ветку develop..."
    git checkout develop
    git merge main
    if [[ "$push" == "true" ]]; then
      git push origin develop
      ok "Ветка develop обновлена и запушена."
    else
      ok "Ветка develop обновлена локально (не запушена, т.к. нет --push)."
    fi
    git checkout main
  fi

  if [[ "$github_release" == "true" ]]; then
    info "🚀 Создаю релиз на GitHub..."
    
    local assets=()
    if [[ -f "$macos_zip" ]]; then
      assets+=("$macos_zip")
    fi
    
    local ipa_file
    ipa_file=$(find "$ios_dir" -name "*.ipa" | head -n 1)
    if [[ -n "$ipa_file" ]]; then
      assets+=("$ipa_file")
    fi

    if [[ ${#assets[@]} -eq 0 ]]; then
      info "⚠️  Нет файлов для загрузки (macos zip или ios ipa). Пропускаю создание релиза."
    else
      local previous_tag
      previous_tag=$(git describe --tags --abbrev=0 "$release_tag^" 2>/dev/null || true)
      local notes_file="${out_dir}/release_notes.md"
      
      {
        echo "## What's Changed"
        if [[ -n "$previous_tag" ]]; then
          git log "${previous_tag}..${release_tag}" --oneline --pretty=format:"* %s (%h)"
        else
          echo "Initial release."
        fi
      } > "$notes_file"

      local gh_args=(
        "release" "create" "$release_tag"
        "--title" "Remission ${release_tag}"
        "--notes-file" "$notes_file"
      )
      
      if [[ "$pre_release" == "true" ]]; then
        gh_args+=("--prerelease")
      fi
      
      if [[ "$draft" == "true" ]]; then
        gh_args+=("--draft")
      fi

      info "Загружаю файлы: ${assets[*]}"
      local release_url
      release_url=$(run gh "${gh_args[@]}" "${assets[@]}")
      ok "Релиз на GitHub успешно создан: ${release_url}"

      if [[ "$draft" == "true" && "$(uname)" == "Darwin" ]]; then
        info "Открываю черновик релиза в браузере..."
        open "$release_url"
      fi
    fi
  fi

  ok "Готово: ${out_dir}"
}

main "$@"
