# SwiftLint Конфигурация и Использование

## Обзор

**SwiftLint** — это инструмент для проверки стиля кода Swift и выявления типовых ошибок на основе сообщества Best Practices. В проекте Remission используется версия **0.61.0** и выше.

## Установка

### Через Homebrew (рекомендуется)

```bash
brew install swiftlint
```

После установки проверьте, что команда доступна:
```bash
swiftlint --version
```

### На Apple Silicon (M1/M2/M3)

Если вы используете Mac на Apple Silicon, убедитесь, что SwiftLint установлен через Homebrew в `/opt/homebrew/bin`:
```bash
which swiftlint
# Должен вывести: /opt/homebrew/bin/swiftlint
```

## Файл конфигурации

Конфигурация хранится в `.swiftlint.yml` в корне проекта:

```yaml
# SwiftLint Configuration for Remission project
# Swift 6 compatible configuration with strict style rules

disabled_rules:
  - trailing_whitespace
  - force_cast

opt_in_rules:
  - closure_spacing
  - explicit_type_interface
  - missing_docs
  - empty_count
  - static_over_final_class

analyzer_rules:
  - unused_declaration
  - unused_import
  - explicit_self

# Paths to include in linting
included:
  - Remission
  - RemissionTests
  - RemissionUITests

# Paths to exclude from linting
excluded:
  - Pods
  - Carthage
  - .build
  - Build
  - DerivedData

# Global settings
allow_zero_lintable_files: false
strict: false
lenient: false
check_for_updates: false

# Rule-specific configuration
line_length:
  warning: 120
  error: 150
  ignores_comments: true
  ignores_urls: true
  ignores_function_declarations: true
  ignores_interpolated_strings: true

type_body_length:
  warning: 300
  error: 400

file_length:
  warning: 500
  error: 800
  ignore_comment_only_lines: true

identifier_name:
  min_length:
    warning: 2
    error: 1
  max_length:
    warning: 40
    error: 50
  excluded:
    - id
    - URL
    - x
    - y
  allowed_symbols: ["_"]
  validates_start_with_lowercase: true

type_name:
  min_length: 3
  max_length:
    warning: 40
    error: 50
  excluded:
    - iPhone

force_try:
  severity: warning

# Reporter format for Xcode integration
reporter: "xcode"
```

## Использование

### Локальная проверка

**Простая проверка всех файлов:**
```bash
swiftlint lint
```

**Ожидаемый результат:**
```
Linting Swift files in current working directory
Done linting! Found 0 violations, 0 serious in X files.
```

**Проверка с выводом в формате Xcode (удобно при работе в IDE):**
```bash
swiftlint lint --reporter xcode
```

**Список всех доступных правил:**
```bash
swiftlint rules
```

### Автоматическое исправление

SwiftLint может автоматически исправить некоторые нарушения:

```bash
# Применить все возможные автоматические исправления
swiftlint --fix

# Проверить после исправления
swiftlint lint
```

**Важно:** Всегда проверяйте результаты автоисправления перед коммитом!

### Интеграция в Xcode

SwiftLint автоматически запускается при сборке проекта благодаря Run Script Phase в build phases целевого проекта. 

**При сборке:**
1. Запускается скрипт, добавляющий PATH для Apple Silicon
2. Выполняется `swiftlint lint --reporter xcode`
3. Нарушения отображаются в **Issue Navigator** в Xcode
4. Сборка продолжает работу (нарушения — это предупреждения, не ошибки)

**Если SwiftLint не найдена:**
- Скрипт выведет предупреждение: `warning: swiftlint command not found`
- Сборка продолжит работу нормально

## Правила и соглашения

### Отключённые правила

- `trailing_whitespace` — пробелы в конце строк (может конфликтовать с swift-format)
- `force_cast` — принудительное приведение типов (разрешено с осторожностью)

### Включённые правила (opt-in)

- `closure_spacing` — правильное использование пробелов в замыканиях
- `explicit_type_interface` — явное указание типов переменных
- `missing_docs` — предупреждение о отсутствующих комментариях (для публичных API)
- `empty_count` — проверка на пустые коллекции
- `static_over_final_class` — использование `static` вместо `class` в final классах

### Основные пороги

| Параметр | Предупреждение | Ошибка | Комментарий |
|----------|---|---|---|
| `line_length` | 120 символов | 150 символов | Исключаются комментарии, URLs, объявления функций |
| `type_body_length` | 300 строк | 400 строк | Длина тела типа (struct, class, enum) |
| `file_length` | 500 строк | 800 строк | Общая длина файла |
| `identifier_name` | 2+ символа | 1+ символ (ошибка) | Имена переменных и функций |

## CI и автоматизация

### GitHub Actions

SwiftLint может быть интегрирован в CI pipeline:

```yaml
name: SwiftLint

on: [pull_request]

jobs:
  swiftlint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install SwiftLint
        run: brew install swiftlint
      - name: Run SwiftLint
        run: swiftlint lint --strict --reporter xcode
```

### Pre-commit hook

Для автоматической проверки перед коммитом добавьте в `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/realm/SwiftLint
    rev: 0.61.0
    hooks:
      - id: swiftlint
```

Установите pre-commit:
```bash
pip install pre-commit
pre-commit install
```

## Решение проблем

### Проблема: "SwiftLint not found" при сборке в Xcode

**Решение:** SwiftLint установлен, но Xcode не может его найти.

```bash
# Убедитесь, что SwiftLint установлен
which swiftlint

# Если вывод пуст, переустановите
brew reinstall swiftlint

# Попробуйте создать символьную ссылку (может потребоваться sudo)
ln -s /opt/homebrew/bin/swiftlint /usr/local/bin/swiftlint
```

### Проблема: Sandbox ошибки при сборке

**Решение:** Скрипт build phase должен автоматически добавлять `/opt/homebrew/bin` в PATH для Apple Silicon. Если ошибка persists:

1. Очистите Xcode cache: `xcodebuild clean`
2. Перезагрузитесь
3. Переустановите SwiftLint: `brew reinstall swiftlint`

### Проблема: Слишком много предупреждений

**Решение:** Отключите ненужные правила в `.swiftlint.yml`:

```yaml
disabled_rules:
  - explicit_type_interface  # Если слишком строгая проверка
  - missing_docs             # Если не требуется документирование
```

## Дополнительные ресурсы

- [SwiftLint GitHub](https://github.com/realm/swiftlint)
- [SwiftLint Rules](https://realm.io/docs/swift/latest/#rules)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)

## Контакты и вопросы

Если возникают вопросы по конфигурации SwiftLint:
1. Проверьте [README.md](../README.md)
2. Обратитесь к [AGENTS.md](../AGENTS.md)
3. Посмотрите документацию в [devdoc/](./README.md)
