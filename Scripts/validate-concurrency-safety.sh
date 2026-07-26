#!/bin/bash
# Валидатор безопасности многопоточности в проекте Remission
# Ищет небезопасное глобальное изменяемое состояние (var на уровне файла)

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}4️⃣  Проверка отсутствия небезопасного глобального состояния...${NC}"

# Получаем список измененных/добавленных Swift-файлов в индексе Git (staged)
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
    echo -e "${GREEN}   ✅ Нет измененных Swift-файлов для проверки конкурентности.${NC}"
    exit 0
fi

CONCURRENCY_FAILED=0

for FILE in $STAGED_SWIFT_FILES; do
    if [ ! -f "$FILE" ]; then
        continue
    fi

    # Ищем строки, начинающиеся с "var " или модификаторов доступа + "var " без отступов (уровень файла)
    # Исключаем строки, содержащие @MainActor, nonisolated(unsafe), @unchecked Sendable, или комментарии
    # Поскольку перед этим запускается swift-format, код гарантированно отформатирован, и все переменные внутри типов имеют отступы.
    GLOBAL_VARS=$(grep -n -E '^(public |private |fileprivate |internal |open )?var[[:space:]]+' "$FILE" || true)

    if [ -n "$GLOBAL_VARS" ]; then
        # Проверяем каждую найденную строку
        while IFS= read -r LINE; do
            if [ -z "$LINE" ]; then continue; fi
            
            LINE_NUM=$(echo "$LINE" | cut -d: -f1)
            LINE_VAL=$(echo "$LINE" | cut -d: -f2-)

            # Проверяем, не является ли это комментарием
            if [[ "$LINE_VAL" =~ ^[[:space:]]*// ]] || [[ "$LINE_VAL" =~ ^[[:space:]]*\* ]]; then
                continue
            fi

            # Проверяем наличие разрешенных аннотаций в текущей или предыдущей строке
            # Для простоты проверяем саму строку на наличие @MainActor, nonisolated или SafeMutex/NSLock
            if [[ "$LINE_VAL" =~ "@MainActor" ]] || [[ "$LINE_VAL" =~ "nonisolated" ]]; then
                continue
            fi

            # Проверяем предыдущую строку файла на наличие @MainActor или nonisolated
            if [ "$LINE_NUM" -gt 1 ]; then
                PREV_LINE_NUM=$((LINE_NUM - 1))
                PREV_LINE=$(sed -n "${PREV_LINE_NUM}p" "$FILE")
                if [[ "$PREV_LINE" =~ "@MainActor" ]] || [[ "$PREV_LINE" =~ "nonisolated" ]]; then
                    continue
                fi
            fi

            echo -e "${RED}   ❌ Ошибка: В файле '$FILE' (строка $LINE_NUM) обнаружена глобальная мутабельная переменная без изоляции!${NC}"
            echo "      Строка: $LINE_VAL"
            echo "      В Swift 6 глобальное изменяемое состояние запрещено во избежание гонок данных (data races)."
            echo "      Решение: Сделайте переменную константой ('let'), изолируйте через '@MainActor',"
            echo "      защитите через актор или пометьте как 'nonisolated(unsafe)' (если потокобезопасность гарантирована вручную)."
            CONCURRENCY_FAILED=1
        done <<< "$GLOBAL_VARS"
    fi
done

if [ $CONCURRENCY_FAILED -eq 0 ]; then
    echo -e "${GREEN}   ✅ Проверка безопасности многопоточности пройдена!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}   ❌ Обнаружены глобальные мутабельные переменные. Исправьте их перед коммитом.${NC}"
    exit 1
fi
