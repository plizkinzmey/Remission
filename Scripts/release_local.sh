#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  Scripts/release_local.sh --version X.Y.Z [--unsigned-ios] [--tag] [--push] [--github-release] [--pre-release] [--draft] [--skip-build] [--export-options-plist PATH] [--notes-file PATH]
  Scripts/release_local.sh --bump {major|minor|patch} [--unsigned-ios] [--tag] [--push] [--github-release] [--pre-release] [--draft] [--skip-build] [--export-options-plist PATH] [--notes-file PATH]
  Scripts/release_local.sh --version X.Y.Z --no-version-commit [--tag] [--push]
  Scripts/release_local.sh --version X.Y.Z --version-only [--no-version-commit]

  Scripts/release_local.sh --version X.Y.Z --platform {all|ios|macos}

Builds:
  - iOS IPA (signed export or unsigned Payload packaging)
  - macOS app zip (from .xcarchive Products/Applications)

Rules:
  - Only runs from branch 'main'
  - Requires clean git working tree unless --allow-dirty is set

Options:
  --github-release  Create a GitHub release and upload built artifacts (requires 'gh' CLI).
  --pre-release     Mark the GitHub release as a pre-release.
  --draft           Create the GitHub release as a draft (not published).
  --skip-build      Skip the building process and only perform tagging/pushing/releasing (requires existing artifacts).
  --notes-file      Use a custom Markdown file as GitHub release notes (recommended for bilingual RU/EN notes).

Outputs:
  Build/Releases/vX.Y.Z/
    - ios/Remission.ipa (or exported contents)
    - macos/Remission.app + Remission-macOS-vX.Y.Z.zip
    - metadata.txt

Notes:
  - iOS uses signed export by default; `--unsigned-ios` builds without provisioning and packages the archive app into an IPA.
  - Скрипт обновляет MARKETING_VERSION/CURRENT_PROJECT_VERSION в project.pbxproj и делает коммит,
    если не указан --no-version-commit.
  - --version-only обновляет версию (и опционально коммитит) без сборки.
EOF
}

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "ℹ️  $*"; }
ok() { echo "✅ $*"; }

require_option_value() {
  [[ $# -ge 2 && -n "${2:-}" && "${2:0:2}" != "--" ]] \
    || die "Опция $1 требует значения."
}

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

run_xcodebuild_logged() {
  local log_path="$1"
  shift
  info "Raw xcodebuild log: ${log_path}"
  set +e
  xcodebuild "$@" 2>&1 | tee "$log_path" | pipe_xcbeautify_if_available
  local -a pipeline_status=("${PIPESTATUS[@]}")
  set -e
  local status
  for status in "${pipeline_status[@]}"; do
    [[ "$status" -eq 0 ]] || return "$status"
  done
  return 0
}

require_nonempty_file() {
  local path="$1"
  [[ -s "$path" ]] || die "Не найден или пустой artifact: $path"
}

validate_ipa() {
  local ipa_path="$1"
  require_nonempty_file "$ipa_path"
  unzip -tq "$ipa_path" >/dev/null || die "IPA повреждён: $ipa_path"
  local ipa_entries
  ipa_entries="$(unzip -Z1 "$ipa_path")" \
    || die "Не удалось прочитать содержимое IPA: $ipa_path"
  grep -Eq '^Payload/[^/]+\.app/Info\.plist$' <<<"$ipa_entries" \
    || die "В IPA отсутствует app Info.plist: $ipa_path"
}

validate_macos_zip() {
  local zip_path="$1"
  require_nonempty_file "$zip_path"
  unzip -tq "$zip_path" >/dev/null || die "macOS zip повреждён: $zip_path"
  local zip_entries
  zip_entries="$(unzip -Z1 "$zip_path")" \
    || die "Не удалось прочитать содержимое macOS zip: $zip_path"
  grep -Eq '(^|/)Remission\.app/' <<<"$zip_entries" \
    || die "В macOS zip отсутствует Remission.app: $zip_path"
}

package_unsigned_ipa() {
  local app_path="$1"
  local ipa_path="$2"
  [[ -d "$app_path" ]] || die "Не найден iOS .app для unsigned IPA: $app_path"
  local staging_dir
  staging_dir="$(mktemp -d)"
  mkdir -p "${staging_dir}/Payload"
  cp -R "$app_path" "${staging_dir}/Payload/Remission.app"
  ditto -c -k --sequesterRsrc --keepParent "${staging_dir}/Payload" "$ipa_path"
  rm -rf "$staging_dir"
}

validate_artifacts() {
  local platform="$1"
  local ios_dir="$2"
  local macos_zip="$3"

  if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
    local ipa_path
    ipa_path="$(find "$ios_dir" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
    [[ -n "$ipa_path" ]] || die "iOS artifact отсутствует в $ios_dir"
    validate_ipa "$ipa_path"
  fi
  if [[ "$platform" == "all" || "$platform" == "macos" ]]; then
    validate_macos_zip "$macos_zip"
  fi
}

require_remote_sync() {
  git fetch --quiet origin main develop --tags
  if [[ "${skip_build:-false}" == "true" ]]; then
    git merge-base --is-ancestor origin/main HEAD \
      || die "Recovery требует fast-forward: origin/main не является предком текущего HEAD."
  else
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] \
      || die "Локальный main не синхронизирован с origin/main."
  fi
  git rev-parse --verify --quiet origin/develop >/dev/null \
    || die "На origin отсутствует ветка develop."
  git merge-base --is-ancestor origin/develop HEAD \
    || die "origin/develop содержит изменения, отсутствующие в main."
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

generate_release_notes() {
  local notes_file="$1"
  local previous_tag="$2"
  local range_end="$3"

  {
    cat <<'MD'
## What's New

### English
* (Write user-facing changes here.)

### Русский
* (Напишите изменения для пользователя здесь.)

## Changes (Git Log)
MD

    if [[ -n "$previous_tag" ]]; then
      # Filter out version bump commits; keep user-relevant changes.
      git log "${previous_tag}..${range_end}" --pretty=format:"* %s (%h)" \
        | grep -v -E '^\* Обновить версию ' \
        || true
    else
      echo "* Initial release."
    fi
  } >"$notes_file"
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
  local unsigned_ios="false"
  local github_release="false"
  local pre_release="false"
  local draft="false"
  local skip_build="false"
  local notes_file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) require_option_value "$@"; version="$2"; shift 2 ;;
      --bump) require_option_value "$@"; bump="$2"; shift 2 ;;
      --tag) tag="true"; shift ;;
      --push) push="true"; shift ;;
      --allow-dirty) allow_dirty="true"; shift ;;
      --no-version-commit) version_commit="false"; shift ;;
      --version-only) version_only="true"; shift ;;
      --export-options-plist) require_option_value "$@"; export_options_plist="$2"; shift 2 ;;
      --platform) require_option_value "$@"; platform="$2"; shift 2 ;;
      --unsigned-ios) unsigned_ios="true"; shift ;;
      --github-release) github_release="true"; shift ;;
      --pre-release) pre_release="true"; shift ;;
      --draft) draft="true"; shift ;;
      --skip-build) skip_build="true"; shift ;;
      --notes-file) require_option_value "$@"; notes_file_arg="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Неизвестный аргумент: $1 (см. --help)" ;;
    esac
  done

  [[ -n "$version" || -n "$bump" ]] || { usage; exit 1; }
  [[ -z "$version" || -z "$bump" ]] || die "Используй либо --version, либо --bump (не вместе)."
  if [[ "$version_commit" == "false" && ( "$tag" == "true" || "$push" == "true" || "$github_release" == "true" ) ]]; then
    die "--no-version-commit нельзя использовать вместе с --tag, --push или --github-release."
  fi
  if [[ "$github_release" == "true" && "$push" != "true" ]]; then
    die "--github-release требует --push, чтобы tag существовал на origin."
  fi
  if [[ "$push" == "true" && "$tag" != "true" ]]; then
    die "--push требует --tag."
  fi
  if [[ "$github_release" == "true" && "$tag" != "true" ]]; then
    die "--github-release требует --tag."
  fi
  if [[ "$allow_dirty" == "true" && ( "$tag" == "true" || "$push" == "true" || "$github_release" == "true" ) ]]; then
    die "--allow-dirty нельзя использовать для tag, push или GitHub release."
  fi
  if [[ "$version_only" == "true" && ( "$tag" == "true" || "$push" == "true" || "$github_release" == "true" || "$skip_build" == "true" ) ]]; then
    die "--version-only нельзя комбинировать с tag, push, GitHub release или --skip-build."
  fi

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
  if [[ "$allow_dirty" != "true" ]]; then
    require_remote_sync
  fi

  if [[ -n "$bump" ]]; then
    local last
    last="$(last_tag_version)"
    version="$(semver_bump "$last" "$bump")"
  fi

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Некорректная версия: $version (ожидаю X.Y.Z)"

  local release_tag="v${version}"
  local tag_exists="false"
  if git show-ref --tags --verify --quiet "refs/tags/${release_tag}"; then
    if [[ "$skip_build" == "true" && "$tag" == "true" \
        && "$(git cat-file -t "$release_tag")" == "tag" \
        && "$(git rev-parse "$release_tag^{commit}")" == "$(git rev-parse HEAD)" ]]; then
      tag_exists="true"
      version_commit="false"
      info "Использую существующий tag ${release_tag} для recovery."
    else
      die "Tag уже существует и не может быть автоматически переиспользован: ${release_tag}"
    fi
  fi
  if [[ "$skip_build" == "true" ]]; then
    version_commit="false"
  fi

  local pbxproj="${ROOT_DIR}/Remission.xcodeproj/project.pbxproj"
  [[ -f "$pbxproj" ]] || die "Не найден project.pbxproj: $pbxproj"

  local build_number_base
  build_number_base="$(compute_build_number)"
  local build_number="$build_number_base"
  if [[ "$version_commit" == "true" ]]; then
    build_number=$((build_number_base + 1))
  fi

  if [[ "$version_only" == "true" ]]; then
    update_project_versions "$pbxproj" "$version"
    if [[ "$version_commit" == "true" ]]; then
      git add "$pbxproj"
      git commit -m "Обновить версию ${version}"
    else
      info "project.pbxproj обновлён, но не закоммичен (--no-version-commit)."
    fi
    ok "Версия обновлена, сборка пропущена (--version-only)."
    exit 0
  fi

  local source_commit
  source_commit="$(git rev-parse HEAD)"

  case "$platform" in
    all|ios|macos) ;;
    *) die "Некорректный --platform: $platform (ожидаю all|ios|macos)" ;;
  esac

  if [[ ( "$platform" == "all" || "$platform" == "ios" ) && "$unsigned_ios" != "true" ]]; then
    [[ -f "$export_options_plist" ]] || die "Не найден export options plist: $export_options_plist"
  fi

  local out_dir="Build/Releases/${release_tag}"
  local ios_dir="${out_dir}/ios"
  local macos_dir="${out_dir}/macos"
  local macos_zip="${out_dir}/Remission-macOS-${release_tag}.zip"
  local state_file="${out_dir}/release-state.txt"

  run mkdir -p "$ios_dir" "$macos_dir"
  if [[ "$skip_build" == "true" && -f "$state_file" ]]; then
    printf 'phase=recovery_started\n' >>"$state_file"
  else
    {
      echo "version=${version}"
      echo "platform=${platform}"
      echo "source_commit=${source_commit}"
      echo "phase=started"
    } >"$state_file"
  fi

  info "Версия: ${version} (build: ${build_number})"
  if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
    if [[ "$unsigned_ios" == "true" ]]; then
      info "iOS signing: unsigned (без provisioning profile)"
    else
      info "Export options plist: ${export_options_plist}"
    fi
  fi
  info "Output: ${out_dir}"

  local ios_archive="${out_dir}/Remission-iOS.xcarchive"
  local macos_archive="${out_dir}/Remission-macOS.xcarchive"

  local ios_ok="skipped"
  local macos_ok="skipped"

  if [[ "$skip_build" == "true" ]]; then
    info "⏩ Пропускаю сборку (--skip-build). Использую существующие артефакты."
    [[ -d "$out_dir" ]] || die "Директория с релизом не найдена: $out_dir. Нечего выпускать без сборки."
    [[ -f "${out_dir}/metadata.txt" ]] || die "Не найден metadata.txt для recovery: ${out_dir}"
    grep -Fxq "version=${version}" "${out_dir}/metadata.txt" \
      || die "Metadata version не совпадает с release version."
    grep -Fxq "platform=${platform}" "${out_dir}/metadata.txt" \
      || die "Metadata platform не совпадает с --platform."
    if [[ "$unsigned_ios" == "true" ]]; then
      grep -Fxq "signing=unsigned" "${out_dir}/metadata.txt" \
        || die "Artifact не соответствует unsigned iOS recovery mode."
    fi
    grep -Fxq "commit=${source_commit}" "${out_dir}/metadata.txt" \
      || die "Artifact собран не из текущего HEAD: recovery запрещён."
    validate_artifacts "$platform" "$ios_dir" "$macos_zip"
    [[ "$platform" == "all" || "$platform" == "ios" ]] && ios_ok="true"
    [[ "$platform" == "all" || "$platform" == "macos" ]] && macos_ok="true"
  else
    if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
      info "Архивирую iOS…"
      local ios_archive_args=(
        -project Remission.xcodeproj \
        -scheme Remission \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$ios_archive" \
        MARKETING_VERSION="$version" \
        CURRENT_PROJECT_VERSION="$build_number" \
        archive
      )
      if [[ "$unsigned_ios" == "true" ]]; then
        ios_archive_args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO AD_HOC_CODE_SIGNING_ALLOWED=NO)
      else
        ios_archive_args+=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration)
      fi
      if ! run_xcodebuild_logged "${out_dir}/ios-archive.log" "${ios_archive_args[@]}"; then
        die "iOS archive неуспешен. См. ${out_dir}/ios-archive.log"
      fi

      if [[ "$unsigned_ios" == "true" ]]; then
        info "Упаковываю unsigned iOS IPA…"
        package_unsigned_ipa \
          "${ios_archive}/Products/Applications/Remission.app" \
          "${ios_dir}/Remission-unsigned.ipa"
      else
        info "Экспортирую iOS IPA…"
        if ! run_xcodebuild_logged "${out_dir}/ios-export.log" \
            -exportArchive \
            -archivePath "$ios_archive" \
            -exportOptionsPlist "$export_options_plist" \
            -allowProvisioningUpdates \
            -allowProvisioningDeviceRegistration \
            -exportPath "$ios_dir"; then
          die "iOS export неуспешен. См. ${out_dir}/ios-export.log"
        fi
      fi
      validate_artifacts "ios" "$ios_dir" "$macos_zip"
      ios_ok="true"
    fi

    if [[ "$platform" == "all" || "$platform" == "macos" ]]; then
      info "Архивирую macOS…"
      if ! run_xcodebuild_logged "${out_dir}/macos-archive.log" \
        -project Remission.xcodeproj \
        -scheme Remission \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$macos_archive" \
        MARKETING_VERSION="$version" \
        CURRENT_PROJECT_VERSION="$build_number" \
        archive; then
        die "macOS archive неуспешен. См. ${out_dir}/macos-archive.log"
      fi

      info "Собираю macOS zip…"
      local macos_app="${macos_archive}/Products/Applications/Remission.app"
      [[ -d "$macos_app" ]] || die "Не найден .app в archive: $macos_app"

      run rm -rf "${macos_dir}/Remission.app"
      run cp -R "$macos_app" "${macos_dir}/Remission.app"

      run ditto -c -k --sequesterRsrc --keepParent "${macos_dir}/Remission.app" "$macos_zip"
      validate_artifacts "macos" "$ios_dir" "$macos_zip"
      macos_ok="true"
    fi
  fi

  validate_artifacts "$platform" "$ios_dir" "$macos_zip"
  printf 'phase=artifacts_validated\n' >>"$state_file"

  local release_commit="$source_commit"
  if [[ "$version_commit" == "true" ]]; then
    update_project_versions "$pbxproj" "$version"
    if git diff --quiet -- "$pbxproj"; then
      info "project.pbxproj уже содержит версию ${version}."
    else
      git add "$pbxproj"
      git commit -m "Обновить версию ${version}"
      release_commit="$(git rev-parse HEAD)"
      ok "Закоммичена версия ${version}"
    fi
  fi
  if [[ "$SKIP_WORKTREE_RESTORE" == "true" ]]; then
    git update-index --skip-worktree "$pbxproj"
  fi
  if [[ "$ASSUME_UNCHANGED_RESTORE" == "true" ]]; then
    git update-index --assume-unchanged "$pbxproj"
  fi
  if [[ "$version_commit" == "true" ]]; then
    printf 'phase=version_committed\nrelease_commit=%s\n' "$release_commit" >>"$state_file"
  else
    printf 'phase=artifacts_reused\nrelease_commit=%s\n' "$release_commit" >>"$state_file"
  fi

  {
    echo "tag=${release_tag}"
    echo "version=${version}"
    echo "build_number=${build_number}"
    echo "commit=${release_commit}"
    echo "built_from_commit=${source_commit}"
    echo "platform=${platform}"
    if [[ "$unsigned_ios" == "true" ]]; then
      echo "signing=unsigned"
    else
      echo "signing=configured"
    fi
    if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
      echo "export_options_plist=${export_options_plist}"
    fi
    echo "ios_ok=${ios_ok}"
    echo "macos_ok=${macos_ok}"
    echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"${out_dir}/metadata.txt"

  # Validate local develop before any tag or remote side effect.
  local local_develop_exists="false"
  if git show-ref --verify --quiet refs/heads/develop; then
    local_develop_exists="true"
    git merge-base --is-ancestor develop HEAD \
      || die "Local develop содержит непубликованные изменения; sync отменён."
  fi

  if [[ "$tag" == "true" ]]; then
    if [[ "$ios_ok" != "true" && "$platform" != "macos" ]]; then
      die "iOS сборка неуспешна; тег не создан. Исправь подпись iOS или запусти с --platform macos."
    fi
    if [[ "$macos_ok" != "true" && "$platform" != "ios" ]]; then
      die "macOS сборка неуспешна; тег не создан."
    fi
    if [[ "$tag_exists" == "false" ]]; then
      git tag -a "$release_tag" -m "Release $release_tag"
      ok "Создан git tag: $release_tag"
    else
      ok "Переиспользован существующий git tag: $release_tag"
    fi
    printf 'phase=tag_ready\ntag=%s\n' "$release_tag" >>"$state_file"
  fi

  if [[ "$push" == "true" ]]; then
    [[ "$tag" == "true" ]] || die "--push требует --tag (чтобы пушить именно тег релиза)."
    printf 'phase=main_push_started\n' >>"$state_file"
    git push origin main
    printf 'phase=main_pushed\n' >>"$state_file"
    git push origin "$release_tag"
    ok "Запушены main и тег $release_tag"
    printf 'phase=main_and_tag_pushed\n' >>"$state_file"
  fi

  # Sync develop without checking it out; this keeps the caller on main.
  if [[ "$push" == "true" ]]; then
    info "🔄 Синхронизирую версию в remote develop..."
    git push origin "HEAD:develop"
    ok "Remote develop обновлена."
  fi
  local develop_synced="false"
  if [[ "$push" == "true" ]]; then
    develop_synced="true"
  fi
  if [[ "$local_develop_exists" == "true" ]]; then
    git update-ref refs/heads/develop HEAD
    ok "Local develop обновлена."
    develop_synced="true"
  fi
  if [[ "$develop_synced" == "true" ]]; then
    printf 'phase=develop_synced\n' >>"$state_file"
  else
    printf 'phase=develop_sync_skipped\n' >>"$state_file"
  fi

  if [[ "$github_release" == "true" ]]; then
    info "🚀 Создаю релиз на GitHub..."
    [[ "$tag" == "true" ]] || die "--github-release требует --tag (релиз на GitHub должен быть привязан к тегу)."
    
    local assets=()
    if [[ "$platform" == "all" || "$platform" == "macos" ]]; then
      validate_macos_zip "$macos_zip"
      assets+=("$macos_zip")
    fi

    if [[ "$platform" == "all" || "$platform" == "ios" ]]; then
      local ipa_file
      ipa_file="$(find "$ios_dir" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
      [[ -n "$ipa_file" ]] || die "iOS IPA отсутствует перед GitHub release."
      validate_ipa "$ipa_file"
      assets+=("$ipa_file")
    fi

    [[ ${#assets[@]} -gt 0 ]] || die "Нет обязательных assets для GitHub release."
    local previous_tag
    previous_tag="$(git describe --tags --match 'v[0-9]*' --abbrev=0 HEAD^ 2>/dev/null || true)"

    local notes_file="${out_dir}/release_notes.md"
    if [[ -n "$notes_file_arg" ]]; then
      notes_file="$notes_file_arg"
      [[ -f "$notes_file" ]] || die "Не найден файл заметок: $notes_file"
    else
      generate_release_notes "$notes_file" "$previous_tag" "$release_tag"
    fi

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
    if gh release view "$release_tag" >/dev/null 2>&1; then
      info "GitHub release ${release_tag} уже существует; загружаю assets повторно."
      run gh release upload "$release_tag" "${assets[@]}" --clobber
      release_url="$(gh release view "$release_tag" --json url --jq .url)"
    else
      release_url=$(run gh "${gh_args[@]}" "${assets[@]}")
    fi
    ok "Релиз на GitHub успешно создан: ${release_url}"
    printf 'phase=github_release_created\nrelease_url=%s\n' "$release_url" >>"$state_file"

    if [[ "$draft" == "true" && "$(uname)" == "Darwin" ]]; then
      info "Открываю черновик релиза в браузере..."
      open "$release_url"
    fi
  fi

  ok "Готово: ${out_dir}"
}

main "$@"
