#!/bin/bash
# Валидатор сообщений коммитов для проекта Remission
# Проверяет соответствие Conventional Commits и обязательное использование русского языка

set -e

MSG_FILE="$1"
MSG_CONTENT=$(cat "$MSG_FILE")

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Проверка сообщения коммита...${NC}"

# Получаем первую строку (заголовок)
SUBJECT=$(echo "$MSG_CONTENT" | head -n 1)

# 1. Проверка формата Conventional Commits
# Разрешенные типы: feat, fix, refactor, test, docs, style, chore
CONVENTIONAL_PATTERN="^(feat|fix|refactor|test|docs|style|chore)(\([a-zA-Z0-9_\#\-\/]+\))?: .+$"

if [[ ! "$SUBJECT" =~ $CONVENTIONAL_PATTERN ]]; then
    echo -e "${RED}❌ Ошибка: Сообщение коммита не соответствует стандарту Conventional Commits!${NC}"
    echo "   Ваш заголовок: '$SUBJECT'"
    echo "   Шаблон: тип(сфера): краткое описание"
    echo "   Разрешенные типы: feat, fix, refactor, test, docs, style, chore"
    echo "   Пример: feat(settings): добавить выбор темы оформления"
    exit 1
fi

# 2. Проверка использования русского языка (наличие кириллицы) в заголовке
# Допускаем английские слова в скобках сферы (scope), но само описание должно содержать кириллицу
DESCRIPTION=$(echo "$SUBJECT" | sed -E 's/^(feat|fix|refactor|test|docs|style|chore)(\([^)]+\))?: //')

if [[ ! "$DESCRIPTION" =~ [а-яА-ЯёЁ] ]]; then
    echo -e "${RED}❌ Ошибка: Заголовок коммита должен быть написан на русском языке!${NC}"
    echo "   Ваше описание: '$DESCRIPTION'"
    echo "   Пожалуйста, переведите заголовок коммита на русский язык."
    exit 1
fi

# 3. Рекомендация наличия подробного описания (Body) для не-chore коммитов
TYPE=$(echo "$SUBJECT" | sed -E 's/^([a-z]+).*$/\1/')
LINE_COUNT=$(echo "$MSG_CONTENT" | grep -v '^#' | grep -v '^$' | wc -l | tr -d ' ')

if [[ "$TYPE" != "chore" && "$TYPE" != "style" && $LINE_COUNT -lt 2 ]]; then
    echo -e "${YELLOW}⚠️  Предупреждение: Рекомендуется добавить подробное описание (Body) вашего коммита,${NC}"
    echo -e "${YELLOW}   описывающее ПОЧЕМУ было сделано это изменение (особенно для ИИ-агентов).${NC}"
fi

echo -e "${GREEN}✅ Сообщение коммита успешно прошло проверку!${NC}"
exit 0
