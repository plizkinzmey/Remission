---
title: Remission Codex Skills
---

# Remission Codex Skills

Эта инструкция описывает, как создавать и упаковывать skills для Codex в этом репозитории.

## Размещение

- Исходники skills храним в `/.codex/skills/<skill-name>/`.
- Сборки `.skill` храним в `/.codex/skills/dist/`.

Структура skill:

```
<skill-name>/
├── SKILL.md
└── references/ (опционально)
```

## Создание skill

1. Создай папку: `/.codex/skills/<skill-name>/`.
2. Добавь `SKILL.md` с YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: краткое описание, когда использовать skill
   metadata:
     short-description: короткое описание
   ---
   ```
3. Если есть дополнительные материалы, положи их в `references/`.
4. Держи `SKILL.md` коротким, а подробности — в `references/`.

## Валидация и упаковка

Для упаковки используем скрипты из репозитория `openai/skills`:

```bash
# Подготовка утилит (временная папка)
mkdir -p /tmp/skills-utils
curl -L https://raw.githubusercontent.com/openai/skills/main/skills/.system/skill-creator/scripts/quick_validate.py \
  -o /tmp/skills-utils/quick_validate.py
curl -L https://raw.githubusercontent.com/openai/skills/main/skills/.system/skill-creator/scripts/package_skill.py \
  -o /tmp/skills-utils/package_skill.py

# Виртуальное окружение + зависимости
python3 -m venv /tmp/skills-venv
/tmp/skills-venv/bin/pip install pyyaml

# Валидация
/tmp/skills-venv/bin/python /tmp/skills-utils/quick_validate.py \
  /path/to/.codex/skills/<skill-name>

# Упаковка (.skill)
/tmp/skills-venv/bin/python /tmp/skills-utils/package_skill.py \
  /path/to/.codex/skills/<skill-name> \
  /path/to/.codex/skills/dist
```

## Проверка набора skills

Повтори упаковку для всех папок в `/.codex/skills/`, кроме `dist/`.

## Обновление

- При изменении `SKILL.md` или `references/` — переупакуй skill.
- `.skill` должен совпадать с текущим содержимым папки skill.
