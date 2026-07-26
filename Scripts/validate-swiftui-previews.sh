#!/bin/bash
# Валидатор наличия SwiftUI Previews в проекте Remission
# Сканирует измененные файлы представлений и проверяет наличие макроса #Preview

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}3️⃣  Проверка наличия SwiftUI Previews (#Preview)...${NC}"

# Получаем список новых Swift-файлов в индексе Git (staged). Для существующих
# экранов отсутствие превью проверяется ревью, иначе UI-рефакторинг старых
# компонентов превращается в массовую миграцию без отношения к текущей задаче.
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=A | grep '\.swift$' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
    echo -e "${GREEN}   ✅ Нет измененных Swift-файлов для проверки вью.${NC}"
    exit 0
fi

PREVIEWS_FAILED=0

for FILE in $STAGED_SWIFT_FILES; do
    # Проверяем, существует ли файл (мог быть удален)
    if [ ! -f "$FILE" ]; then
        continue
    fi

    BASENAME="$(basename "$FILE")"

    # Требуем preview только для новых экранов и форм. Leaf-компоненты в
    # Components/Cells не блокируются этим эвристическим gate.
    if [[ "$FILE" == *"/Components/"* ]] || [[ "$FILE" == *"/Cells/"* ]]; then
        continue
    fi
    if [[ "$BASENAME" != *View.swift ]] && [[ "$BASENAME" != *Form*.swift ]]; then
        continue
    fi

    # Ищем объявление структуры View: "struct ... : View" или "struct ...:View"
    # Исключаем комментарии.
    if grep -E 'struct[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*View\b' "$FILE" | grep -q -v '^[[:space:]]*//' ; then
        # Файл содержит SwiftUI View. Теперь ищем макрос "#Preview" или "PreviewProvider"
        if ! grep -q -E '^[[:space:]]*#Preview\b' "$FILE" && ! grep -q -E '^[[:space:]]*struct[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*PreviewProvider\b' "$FILE"; then
            echo -e "${RED}   ❌ Ошибка: В файле '$FILE' обнаружено SwiftUI-представление без макроса '#Preview'!${NC}"
            echo -e "      Согласно правилу 4 в AGENTS.md, каждый экран и форма ввода ОБЯЗАНЫ иметь макрос #Preview"
            echo -e "      с демонстрационными данными или mock-зависимостями."
            PREVIEWS_FAILED=1
        fi
    fi
done

if [ $PREVIEWS_FAILED -eq 0 ]; then
    echo -e "${GREEN}   ✅ Все измененные SwiftUI View содержат Previews!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}   ❌ Проверка SwiftUI Previews провалена! Добавьте #Preview и попробуйте снова.${NC}"
    exit 1
fi
