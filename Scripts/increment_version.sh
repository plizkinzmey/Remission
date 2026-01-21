#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="${ROOT_DIR}/Remission.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "❌ Не найден project.pbxproj: $PBXPROJ"
  exit 1
fi

BUMP="${1:-patch}"
case "$BUMP" in
  major|minor|patch) ;;
  *) echo "❌ Некорректный bump: $BUMP (ожидаю major|minor|patch)"; exit 1 ;;
esac

VERSION_BUMP="$BUMP" PBXPROJ="$PBXPROJ" python3 - <<'PY'
from pathlib import Path
import os
import re

path = Path(os.environ["PBXPROJ"])
bump = os.environ["VERSION_BUMP"]
text = path.read_text()

version_match = re.search(r"MARKETING_VERSION\s*=\s*([^;]+);", text)
build_match = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*([^;]+);", text)

if not version_match or not build_match:
    raise SystemExit("❌ Не удалось найти MARKETING_VERSION/CURRENT_PROJECT_VERSION в project.pbxproj")

version = version_match.group(1).strip()
parts = version.split(".")
if len(parts) != 3 or not all(p.isdigit() for p in parts):
    raise SystemExit(f"❌ Некорректная версия MARKETING_VERSION: {version} (ожидаю X.Y.Z)")

major, minor, patch = (int(p) for p in parts)
if bump == "major":
    major += 1
    minor = 0
    patch = 0
elif bump == "minor":
    minor += 1
    patch = 0
else:
    patch += 1

new_version = f"{major}.{minor}.{patch}"

build = int(build_match.group(1).strip())
new_build = build + 1

text = re.sub(
    r"(MARKETING_VERSION\s*=\s*)([^;]+);",
    rf"\g<1>{new_version};",
    text,
)
text = re.sub(
    r"(CURRENT_PROJECT_VERSION\s*=\s*)([^;]+);",
    rf"\g<1>{new_build};",
    text,
)

path.write_text(text)

print(f"✅ Версия обновлена: {new_version} ({new_build})")
PY
