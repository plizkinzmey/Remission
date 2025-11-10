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
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
```

**Сборка для macOS:**
```bash
xcodebuild -scheme Remission -destination 'platform=macOS' build
```

### Запуск тестов

**Unit и интеграционные тесты:**
```bash
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

**UI-тесты:**
```bash
xcodebuild test -scheme Remission -testPlan RemissionUITests -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

UI smoke покрывает две ключевые ветки: пустое состояние списка серверов и переход к деталям через фикстурные данные. Для сценария навигации используется launch-аргумент `--ui-testing-fixture=server-list-sample`, который подготавливает преднастроенные сервера при запуске UI-тестов.

**Покрытие кода (целевое значение ≥ 60%):**
```bash
# 1. Запускаем тесты с сохранением результата и включённым покрытием
xcodebuild test \
  -scheme Remission \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath build/TestResults/Remission.xcresult \
  -enableCodeCoverage YES

# 2. Просматриваем отчёт о покрытии через xccov
xcrun xccov view --report build/TestResults/Remission.xcresult

# (опционально) Сохраняем отчёт в JSON для анализа/CI
xcrun xccov view --report --json build/TestResults/Remission.xcresult > build/TestResults/coverage.json
```

Пример актуального запуска: общая доля покрытых строк составила **77.8%**, при этом `TransmissionClient.swift` и зависимые DTO полностью попали в отчёт.

### Статус CI

На текущем этапе CI-пайплайн отключён: проект поддерживается одним разработчиком, и мы временно приняли решение выполнять проверки вручную, чтобы не тратить ресурсы на автоматизацию. Перед push запускайте локальные lint/format и `xcodebuild test` — это остаётся обязательным чек-листом.

## Архитектура

Проект использует следующие архитектурные паттерны:

- **The Composable Architecture (TCA)** для управления состоянием и побочных эффектов
- **MVVM-подход** с разделением слоёв: UI / Presentation / Domain / Services / Persistence
- **Async/await** для асинхронного программирования
- **Keychain** для безопасного хранения учётных данных

## Сохранение серверов и резервные копии

- Список серверов хранится в файле `~/Library/Application Support/Remission/servers.json` (для iOS Simulator путь будет внутри контейнера приложения, но структура совпадает).
- Каждый сервер сериализуется в `StoredServerConfigRecord` (id, host, port, путь, настройки HTTPS, имя пользователя и дата создания).
- Пароли **никогда** не попадают в `servers.json` — они лежат в Keychain под ключом `transmission-credentials-{host}-{port}-{username}`.

### Как сделать резервную копию
1. Закройте приложение Remission (чтобы файл не перезаписывался).
2. Скопируйте `servers.json` в безопасное место, например:
   ```bash
   mkdir -p ~/Backups/remission
   cp ~/Library/Application\ Support/Remission/servers.json \
      ~/Backups/remission/servers-$(date +%Y%m%d).json
   ```
3. Экспортируйте связанные записи Keychain через стандартное приложение «Связка ключей» или команду `security export` (фильтр по `transmission-credentials`), чтобы сохранить пароли.

### Восстановление
1. Скопируйте нужную версию `servers.json` обратно в `~/Library/Application Support/Remission/`.
2. Импортируйте соответствующие элементы Keychain (если они отсутствуют).
3. Запустите приложение — серверы будут подхвачены автоматически при старте.

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
xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Документация

- **`devdoc/PRD.md`** — Product Requirements Document с подробным описанием функциональности
- **`AGENTS.md`** — Справочник архитектуры, соглашений и инструкций для разработчиков и AI-агентов
- **`devdoc/plan.md`** — План развития проекта и дорожная карта

## Лицензия

Проект распространяется под лицензией, указанной в LICENSE файле (если присутствует).

## Связь

Для вопросов и предложений обратитесь к владельцу проекта или создайте issue в репозитории.
