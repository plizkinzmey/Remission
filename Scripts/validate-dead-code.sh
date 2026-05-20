#!/bin/bash
# Strict dead-code and cleanup validator for Remission.
# Real tool warnings/errors are visible and block the commit until fixed.
# Lightweight local heuristics are printed as review notes, not warnings.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}5️⃣  Dead-code and cleanup gate...${NC}"

WARNINGS=0

if [[ "$(uname -m)" == arm64 ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

CHANGED_FILES=$(
    {
        git diff --cached --name-only --diff-filter=ACM
        git diff --name-only --diff-filter=ACM
    } | sort -u
)
CHANGED_SWIFT_FILES=$(echo "$CHANGED_FILES" | grep '\.swift$' || true)
CHANGED_TEXT_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(swift|md|sh|yml|yaml|json)$' || true)

if command -v periphery >/dev/null 2>&1; then
    echo -e "${BLUE}   Running Periphery scan...${NC}"
    PERIPHERY_OUTPUT=$(mktemp)
    if periphery scan \
        --project Remission.xcodeproj \
        --schemes Remission \
        --targets Remission \
        --format xcode \
        --retain-swift-ui-previews \
        --disable-update-check \
        --retain-public >"$PERIPHERY_OUTPUT" 2>&1; then
        if grep -q '\* No unused code detected\.' "$PERIPHERY_OUTPUT"; then
            echo -e "${GREEN}   ✅ Periphery found no unused code.${NC}"
        elif grep -qE '^[^*[:space:]].*\.swift:[0-9]+:[0-9]+:' "$PERIPHERY_OUTPUT"; then
            echo -e "${YELLOW}   ⚠️  Periphery reported possible unused code:${NC}"
            sed 's/^/      /' "$PERIPHERY_OUTPUT"
            WARNINGS=1
        elif [ -s "$PERIPHERY_OUTPUT" ]; then
            echo -e "${GREEN}   ✅ Periphery completed. Output:${NC}"
            sed 's/^/      /' "$PERIPHERY_OUTPUT"
        else
            echo -e "${GREEN}   ✅ Periphery found no unused-code warnings.${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  Periphery scan did not complete. Output:${NC}"
        sed 's/^/      /' "$PERIPHERY_OUTPUT"
        if grep -q 'DecodingError.typeMismatch.*shellScript' "$PERIPHERY_OUTPUT"; then
            echo -e "${YELLOW}      Periphery could not decode the current Xcode project shellScript field.${NC}"
            echo -e "${YELLOW}      Fallback heuristics below still run, but this gate will fail until Periphery works.${NC}"
        fi
        WARNINGS=1
    fi
    rm -f "$PERIPHERY_OUTPUT"
else
    echo -e "${YELLOW}   ⚠️  Periphery not found; skipping unused-code scan.${NC}"
    echo -e "${YELLOW}      Install: brew install peripheryapp/periphery/periphery${NC}"
    WARNINGS=1
fi

if [ -n "$CHANGED_TEXT_FILES" ]; then
    TODO_OUTPUT=$(mktemp)
    while IFS= read -r FILE; do
        [ -f "$FILE" ] || continue
        if [[ "$FILE" == *"validate-dead-code.sh"* ]]; then
            continue
        fi
        grep -n -E 'TODO:|FIXME:' "$FILE" | sed "s|^|$FILE:|" || true
    done <<< "$CHANGED_TEXT_FILES" >"$TODO_OUTPUT"

    if [ -s "$TODO_OUTPUT" ]; then
        echo -e "${YELLOW}   ⚠️  TODO/FIXME markers in changed files:${NC}"
        sed 's/^/      /' "$TODO_OUTPUT"
        WARNINGS=1
    else
        echo -e "${GREEN}   ✅ No TODO/FIXME markers in changed text files.${NC}"
    fi
    rm -f "$TODO_OUTPUT"
fi

if [ -n "$CHANGED_SWIFT_FILES" ]; then
    LARGE_FILE_OUTPUT=$(mktemp)
    while IFS= read -r FILE; do
        [ -f "$FILE" ] || continue
        LINE_COUNT=$(wc -l < "$FILE" | tr -d ' ')
        if [ "$LINE_COUNT" -gt 400 ]; then
            echo "$FILE:$LINE_COUNT lines"
        fi
    done <<< "$CHANGED_SWIFT_FILES" >"$LARGE_FILE_OUTPUT"

    if [ -s "$LARGE_FILE_OUTPUT" ]; then
        echo -e "${BLUE}   Review notes: large changed Swift files; inspect for split/refactor opportunities:${NC}"
        sed 's/^/      /' "$LARGE_FILE_OUTPUT"
    else
        echo -e "${GREEN}   ✅ No changed Swift file exceeds 400 lines.${NC}"
    fi
    rm -f "$LARGE_FILE_OUTPUT"

    DUPLICATE_OUTPUT=$(mktemp)
    while IFS= read -r FILE; do
        [ -f "$FILE" ] || continue
        grep -E '^[[:space:]]*(public |private |fileprivate |internal |open )?(struct|final class|class|enum|protocol|func)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$FILE" \
            | sed -E 's/^[[:space:]]*(public |private |fileprivate |internal |open )?(struct|final class|class|enum|protocol|func)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/' \
            | sort -u \
            | while IFS= read -r SYMBOL; do
                [ -n "$SYMBOL" ] || continue
                case "$SYMBOL" in
                    State|Action|Delegate|AlertAction|body|application|makeUIView|updateUIView|describe|Retry)
                        continue
                        ;;
                esac
                COUNT=$(grep -R --include='*.swift' -n -E "(struct|final class|class|enum|protocol|func)[[:space:]]+$SYMBOL\\b" Remission RemissionTests RemissionUITests 2>/dev/null | wc -l | tr -d ' ')
                if [ "$COUNT" -gt 1 ]; then
                    echo "$FILE:$SYMBOL appears in $COUNT declarations"
                fi
            done
    done <<< "$CHANGED_SWIFT_FILES" >"$DUPLICATE_OUTPUT"

    if [ -s "$DUPLICATE_OUTPUT" ]; then
        echo -e "${BLUE}   Review notes: similar declaration names in changed Swift files; inspect for real duplication:${NC}"
        sed 's/^/      /' "$DUPLICATE_OUTPUT"
    else
        echo -e "${GREEN}   ✅ No obvious duplicate Swift declaration names in changed files.${NC}"
    fi
    rm -f "$DUPLICATE_OUTPUT"
else
    echo -e "${GREEN}   ✅ No changed Swift files for dead-code heuristics.${NC}"
fi

if [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}   ✅ Dead-code and cleanup gate passed with no warnings.${NC}"
    exit 0
fi

echo -e "${RED}   ❌ Dead-code and cleanup gate failed. Fix all warnings before committing.${NC}"
exit 1
