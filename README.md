# Remission

Кроссплатформенный клиент (iOS + macOS) для удалённого управления Transmission через RPC.

## О проекте

**Remission** — это быстрый, удобный и безопасный интерфейс для мониторинга и управления торрентами на удалённом хосте. Приложение поддерживает подключение к одному или нескольким серверам Transmission, просмотр и управление торрентами, добавление `.torrent` и `magnet` ссылок, а также безопасное хранение учётных данных в Keychain.

## Системные требования

### Инструменты разработки

| Инструмент | Версия | Примечание |
|-----------|--------|-----------|
| **Xcode** | 26.0.1 или выше | Требуется для сборки и тестирования |
| **Swift Compiler** | 6.2 или выше | Встроен в Xcode, поддержка Swift 6 (strict concurrency) |
| **Swift Package Manager** | 5.9 или выше | Встроен в Xcode (версия связана с версией Xcode) |

### Целевые платформы (Deployment Targets)

| Платформа | Минимальная версия | Примечание |
|-----------|------------------|-----------|
| **iOS** | 26.0 или выше | iPhone, iPad |
| **macOS** | 26.0 или выше | Intel, Apple Silicon |

### Требования к языку Swift

- **Swift Language Version во всех целях**: 6.0 (с включённым строгим режимом конкурентности — strict concurrency)
- **Стандарт**: следуем [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) и соглашениям, описанным в `AGENTS.md`
- **Компилятор**: Swift 6.2+ требуется для полной поддержки всех функций Swift 6

## Быстрый старт

### Открыть проект в Xcode

```bash
open Remission.xcodeproj
```

Затем выберите схему `Remission` и запустите на симуляторе или устройстве.

### Первая установка (рекомендуется)

#### 1. Установить инструменты контроля качества

```bash
brew install swift-format swiftlint
```

#### 2. Настроить git pre-commit hook

Запустите скрипт для установки git hook'а, который будет проверять код перед каждым коммитом:

```bash
bash Scripts/prepare-hooks.sh
```

Этот скрипт:
- ✅ Проверит, установлены ли `swift-format` и `swiftlint`
- ✅ Установит git pre-commit hook
- ✅ Выведет инструкции по использованию

Теперь при каждом `git commit` будут автоматически запускаться проверки кода.

#### 3. Первая проверка вручную (опционально)

```bash
./Scripts/setup-swiftlint.sh
```

Этот скрипт:
- Проверит, установлен ли SwiftLint
- Запустит первую проверку кода

### Контроль качества кода

Для информации о работе с форматированием и линтингом кода см. **[CONTRIBUTING.md](CONTRIBUTING.md)**.

**Краткая справка:**

```bash
# Проверить форматирование (не изменяет файлы)
swiftformat --lint --configuration .swift-format .

# Проверить стиль кода
swiftlint lint

# Автоисправить форматирование
swiftformat --configuration .swift-format .

# Автоисправить некоторые нарушения swiftlint
swiftlint --fix

# Пропустить pre-commit hook при необходимости
git commit --no-verify
```

### Сборка из командной строки

**Сборка для iOS Simulator:**
```bash
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Сборка для macOS:**
```bash
xcodebuild -scheme Remission -destination 'platform=macOS' build
```

### Запуск тестов

**Unit и интеграционные тесты:**
```bash
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

**UI-тесты:**
```bash
xcodebuild test -scheme Remission -testPlan RemissionUITests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

**TransmissionClient (Swift Testing) + покрытие:**
```bash
xcodebuild test \
  -project Remission.xcodeproj \
  -scheme Remission \
  -testPlan Remission \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES \
  -resultBundlePath build/TestResults.xcresult
```

> Требование: суммарное покрытие TransmissionClient и связанных зависимостей ≥60%.  
> Посмотреть отчёт локально можно командой `xcrun xccov view --report build/TestResults.xcresult`. CI публикует файл `remission-test-results` как artefact, его можно открыть в Xcode (Menu **Window → Organizer → Reports → Import**).

#### Пример отчёта покрытия

**Быстрый просмотр (CLI):**
```bash
xcrun xccov view --report build/TestResults.xcresult
```

**Фрагмент вывода:**
```
  Remission.app (Remission.app) : 78.1%
    TransmissionClient.swift : 72.5%
    TransmissionClientProtocol.swift : 68.3%
```

**Через Xcode UI:**
1. Откройте Xcode → `Window` → `Organizer`.
2. Перейдите во вкладку **Reports**.
3. Нажмите **Import** и выберите `build/TestResults.xcresult`.
4. Просмотрите графики и детализацию покрытия по файлам/строкам.

**Альтернатива:** экспортируйте детальный отчёт в текст:
```bash
xcrun xcresulttool get --format json --path build/TestResults.xcresult > coverage.json
```

## Архитектура

Проект использует следующие архитектурные паттерны:

- **The Composable Architecture (TCA)** для управления состоянием и побочных эффектов
- **MVVM-подход** с разделением слоёв: UI / Presentation / Domain / Services / Persistence
- **Async/await** для асинхронного программирования
- **Keychain** для безопасного хранения учётных данных

### Структура проекта

```
Remission/
├── Remission/              # Основное приложение (SwiftUI)
│   ├── RemissionApp.swift  # @main App struct
│   ├── ContentView.swift   # Главное окно
│   ├── DependencyClients/  # Определения @DependencyClient и тестовые значения
│   │   └── TransmissionClientDependency.swift
│   ├── DependencyClientLive/  # Live-реализации зависимостей
│   │   └── TransmissionClientDependency+Live.swift
│   └── Assets.xcassets/    # Ресурсы (иконки, цвета и т.д.)
├── RemissionTests/         # Unit-тесты
├── RemissionUITests/       # UI-тесты
├── devdoc/
│   └── PRD.md             # Product Requirements Document
├── AGENTS.md              # Справочник для AI-агентов и разработчиков
└── README.md              # Этот файл
```

## Разработка

### Форматирование кода

Проект использует `swift-format` для автоматического форматирования в соответствии с [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) и стилем, описанным в `AGENTS.md`.

#### Установка swift-format

**Для Swift 6 (Xcode 16+)**: `swift-format` уже включён в toolchain:
```bash
swift format --help
```

**Установка через Homebrew (если требуется отдельная версия):**
```bash
brew install swift-format
```

#### Использование

**Вывести отформатированный код в stdout (проверка форматирования):**
```bash
swift-format format --recursive --configuration .swift-format Remission RemissionTests RemissionUITests
```

**Применить форматирование с заменой файлов на месте:**
```bash
swift-format format --in-place --recursive --configuration .swift-format Remission RemissionTests RemissionUITests
```

### Проверка стиля кода (SwiftLint)

Проект использует **SwiftLint** для проверки соответствия стилю кода и выявления типовых ошибок. Конфигурация хранится в `.swiftlint.yml` в корне проекта.

#### Установка SwiftLint

```bash
brew install swiftlint
```

#### Использование

**Локальная проверка (на машине разработчика):**
```bash
# Простая проверка
swiftlint lint

# Автоматическое исправление нарушений (если возможно)
swiftlint --fix

# Проверка с выводом в формате Xcode
swiftlint lint --reporter xcode
```

#### Интеграция в Xcode

SwiftLint автоматически запускается при сборке проекта через Run Script Phase в build phases. Предупреждения и ошибки будут отображаться в Xcode Issue Navigator.

Если вы видите sandbox-related ошибки:
1. Убедитесь, что SwiftLint установлен через Homebrew: `which swiftlint`
2. На Apple Silicon (M1/M2/M3) скрипт автоматически добавляет `/opt/homebrew/bin` в PATH

#### Конфигурация

Файл `.swiftlint.yml` содержит:
- **disabled_rules** - отключённые проверки
- **opt_in_rules** - включённые проверки, требующие явного включения
- **included** - пути для анализа (по умолчанию: `Remission`, `RemissionTests`, `RemissionUITests`)
- **excluded** - исключённые пути (по умолчанию: `Pods`, `Carthage`, `.build`)
- **Кастомные параметры** - настройки для отдельных правил (line_length, identifier_name и т.д.)

````

#### Параметры конфигурации

Конфигурация хранится в файле `.swift-format` в корне репозитория с параметрами:

- **Отступы**: 4 пробела (`indentation.spaces`)
- **Длина строки**: 100 символов (`lineLength`)
- **Максимум пустых строк**: 1 (`maximumBlankLines`)
- **Правила**: 45+ встроенных правил форматирования включая:
  - `AlwaysUseLowerCamelCase` — camelCase для переменных/методов
  - `TypeNamesShouldBeCapitalized` — PascalCase для типов
  - `UseTripleSlashForDocumentationComments` — triple-slash для doc-комментариев
  - `DoNotUseSemicolons` — удаление точек с запятой
  - И другие правила для консистентного стиля

**Важно**: перед коммитом запустите `swift-format` для всех изменённых файлов, чтобы обеспечить консистентность стиля.

### Liniting

Используется `swiftlint` для проверки стиля кода:

```bash
swiftlint lint
```

### Соглашения

- **Наименование**: PascalCase для типов, camelCase для свойств и методов
- **Отступы**: 4 пробела
- **Комментарии к коммитам**: только на русском языке
- Подробные рекомендации см. в `AGENTS.md` и `devdoc/PRD.md`

## Тестирование

### Стратегия тестирования

- **Unit-тесты**: сетевой слой, репозитории, TCA reducers
- **Integration-тесты**: работа с Transmission через RPC
- **UI-тесты**: onboarding, список торрентов, добавление торрентов
- **Целевое покрытие**: ≥60% для ключевых компонентов MVP

### Запуск тестов перед PR

```bash
# Полный набор тестов
xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Документация

- **`devdoc/PRD.md`** — Product Requirements Document с подробным описанием функциональности
- **`AGENTS.md`** — Справочник архитектуры, соглашений и инструкций для разработчиков и AI-агентов
- **`devdoc/plan.md`** — План развития проекта и дорожная карта

## Лицензия

Проект распространяется под лицензией, указанной в LICENSE файле (если присутствует).

## Связь

Для вопросов и предложений обратитесь к владельцу проекта или создайте issue в репозитории.
