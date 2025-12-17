#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CATALOG_PATH="${1:-${REPO_ROOT}/Remission/Localizable.xcstrings}"

if [[ ! -f "${CATALOG_PATH}" ]]; then
    echo "error: String Catalog not found at ${CATALOG_PATH}" >&2
    exit 1
fi

python3 - <<'PY' "${CATALOG_PATH}"
import collections
import json
import os
import pathlib
import re
import sys
from typing import Counter, Dict, Iterable, List

catalog_path = pathlib.Path(sys.argv[1])

try:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
except Exception as error:  # noqa: BLE001
    print(f"error: failed to read catalog: {error}", file=sys.stderr)
    sys.exit(1)

strings: Dict[str, dict] = catalog.get("strings", {})
explicit_locales = [item for item in (os.environ.get("LOCALES") or "").split(",") if item]

if explicit_locales:
    expected_locales = explicit_locales
else:
    locales = set()
    if "sourceLanguage" in catalog:
        locales.add(catalog["sourceLanguage"])
    for entry in strings.values():
        locales.update(entry.get("localizations", {}).keys())
    expected_locales = sorted(locales)

if not expected_locales:
    print("error: unable to determine locales. Pass LOCALES or specify sourceLanguage.", file=sys.stderr)
    sys.exit(1)

base_locale = catalog.get("sourceLanguage", expected_locales[0])

PLACEHOLDER_PATTERN = re.compile(
    r"%(?!%)"  # skip literal percent
    r"(?:\d+\$)?"  # optional positional index
    r"[-+#0 ]*"  # flags
    r"(?:\d+)?"  # width
    r"(?:\.\d+)?"  # precision
    r"(?:hh|h|ll|l|q|L|z|t|j)?"  # length modifiers
    r"[@A-Za-z]"  # conversion / object
)


def collect_values(node: object) -> List[str]:
    values: List[str] = []
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "value" and isinstance(value, str):
                values.append(value)
            elif isinstance(value, (dict, list)):
                values.extend(collect_values(value))
    elif isinstance(node, list):
        for item in node:
            values.extend(collect_values(item))
    return values


def collect_string_units(node: object) -> List[dict]:
    units: List[dict] = []
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "stringUnit" and isinstance(value, dict):
                units.append(value)
            elif isinstance(value, (dict, list)):
                units.extend(collect_string_units(value))
    elif isinstance(node, list):
        for item in node:
            units.extend(collect_string_units(item))
    return units


def extract_placeholders(text: str) -> Iterable[str]:
    return PLACEHOLDER_PATTERN.findall(text)


def placeholder_set(node: dict) -> set[str]:
    placeholders: set[str] = set()
    for value in collect_values(node):
        placeholders.update(extract_placeholders(value))
    return placeholders


def format_placeholder_set(placeholders: set[str]) -> str:
    if not placeholders:
        return "no placeholders"
    return ", ".join(sorted(placeholders))


missing: List[str] = []
placeholder_mismatches: List[str] = []

for key in sorted(strings.keys()):
    # Skip empty keys (Xcode may generate them as placeholders)
    if not key:
        continue

    entry = strings[key]
    localizations = entry.get("localizations", {})

    for locale in expected_locales:
        localization = localizations.get(locale)
        if not localization:
            missing.append(f"[{locale}] {key}: missing localization")
            continue

        units = collect_string_units(localization)
        if not units:
            missing.append(f"[{locale}] {key}: missing stringUnit")
            continue

        has_value = any(value.strip() for value in collect_values(localization))
        states = {unit.get("state") for unit in units}

        if states != {"translated"}:
            state_label = ", ".join(sorted(str(state or "unknown") for state in states))
            missing.append(f"[{locale}] {key}: state is '{state_label}'")
        if not has_value:
            missing.append(f"[{locale}] {key}: empty translation value")

    base_localization = localizations.get(base_locale, {})
    if not collect_string_units(base_localization):
        continue  # base locale missing already reported above

    base_placeholders = placeholder_set(base_localization)

    for locale in expected_locales:
        if locale == base_locale:
            continue
        localization = localizations.get(locale, {})
        if not collect_string_units(localization):
            continue
        placeholders = placeholder_set(localization)
        if placeholders != base_placeholders:
            placeholder_mismatches.append(
                f"[{locale}] {key}: expected ({base_locale}) {format_placeholder_set(base_placeholders)}, "
                f"found {format_placeholder_set(placeholders)}"
            )

if missing or placeholder_mismatches:
    if missing:
        print("Localization issues:", file=sys.stderr)
        for item in missing:
            print(f"- {item}", file=sys.stderr)
    if placeholder_mismatches:
        print("\nPlaceholder mismatches:", file=sys.stderr)
        for item in placeholder_mismatches:
            print(f"- {item}", file=sys.stderr)
    sys.exit(1)

print(
    f"Localization check passed for {len(strings)} keys across locales: {', '.join(expected_locales)}."
)
PY
