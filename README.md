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

### Проверка локализаций

- Скрипт `Scripts/check-localizations.sh` проверяет `Remission/Localizable.xcstrings` на отсутствие переводов и несовпадение плейсхолдеров между `ru` и `en`.
- Запускать вручную из корня репозитория:  
  ```bash
  Scripts/check-localizations.sh
  ```
- Проверка встроена в Xcode build phase **Localizations Check**; при ошибках сборка завершится с кодом 1.

### Сборка из командной строки

**Сборка для iOS Simulator:**
```bash
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' build
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
│   ├── Features/           # TCA Reducers для feature-модулей
│   │   ├── Onboarding/     # Онбординг
│   │   ├── ServerList/     # Список серверов
│   │   ├── ServerDetail/   # Детали сервера
│   │   └── ServerEditor/   # Редактирование сервера
│   ├── Views/              # SwiftUI View компоненты
│   │   ├── App/            # Корневой AppView
│   │   ├── Onboarding/     # Views онбординга
│   │   ├── ServerList/     # Views списка серверов
│   │   ├── ServerDetail/   # Views деталей сервера
│   │   ├── ServerEditor/   # Views редактора сервера
│   │   ├── TorrentDetail/  # Views деталей торрента
│   │   └── Shared/         # Переиспользуемые компоненты
│   ├── Domain/             # Доменные модели и маппинг RPC
│   │   ├── ServerConfig.swift
│   │   ├── Torrent.swift
│   │   ├── SessionState.swift
│   │   └── TransmissionDomainMapper*.swift
│   ├── DependencyClients/  # Определения @DependencyClient
│   │   ├── TransmissionClientDependency.swift
│   │   ├── AppClockDependency.swift
│   │   └── KeychainCredentialsDependency.swift
│   ├── DependencyClientLive/  # Live-реализации зависимостей
│   │   ├── TransmissionClientDependency+Live.swift
│   │   └── KeychainCredentialsDependency+Live.swift
│   ├── Shared/             # Общие утилиты
│   ├── Assets.xcassets/    # Ресурсы (иконки, цвета и т.д.)
│   └── [корневые файлы]    # Repositories, Network, Bootstrap
├── RemissionTests/         # Unit-тесты (Swift Testing)
│   ├── Support/            # Утилиты для тестов
│   │   ├── DependencyOverrides.swift
│   │   └── TestStoreFactory.swift
│   └── Fixtures/           # Фикстуры и тестовые данные
│       ├── Transmission/   # JSON-фикстуры Transmission RPC
│       ├── Domain/         # Доменные фикстуры
│       └── TransmissionFixture.swift
├── RemissionUITests/       # UI-тесты
├── devdoc/
│   ├── PRD.md              # Product Requirements Document
│   ├── plan.md             # Архитектура и roadmap
│   ├── CONTEXT7_GUIDE.md   # Гайд по исследованию документации
│   └── TRANSMISSION_RPC_REFERENCE.md
├── AGENTS.md               # Справочник для AI-агентов и разработчиков
└── README.md               # Этот файл
```

## Разработка

### VS Code Tasks

Проект включает готовые задачи в `.vscode/tasks.json` для упрощения разработки и CI/CD процессов:

- **SwiftLint (run)** — запуск линтера с JSON-репортером
- **Run Unit Tests** — запуск unit-тестов для macOS (быстрее симулятора)
- **Xcode Build (Debug)** — Debug сборка с автоматическим запуском линтера и тестов
- **Run App** — открытие собранного приложения
- **Archive (Release)** — создание Release-архива с автоинкрементом версии
- **Export App (IPA)** — экспорт IPA из архива
- **Archive & Export (Personal Team)** — полный цикл релиза

Запуск через VS Code Command Palette: `Cmd+Shift+P` → "Tasks: Run Task"

Или из командной строки:
```bash
# Запуск линтера
swiftlint lint --quiet --reporter json

# Запуск тестов (macOS быстрее симулятора)
xcodebuild test -scheme Remission -configuration Debug -destination 'platform=macOS,arch=arm64' | xcbeautify

# Полная сборка
xcodebuild -scheme Remission -configuration Debug build | xcbeautify
```

### Локальный релиз (main-only)

Скрипт `Scripts/release_local.sh` собирает **iOS IPA** и **macOS .app (zip)** с автоматической установкой `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` на время сборки.
Перед релизом версия обновляется автоматически: скрипт правит `Remission.xcodeproj/project.pbxproj` и делает коммит, если не указан `--no-version-commit`.

Важно: релиз считается корректным только при наличии git-тега `vX.Y.Z`, поэтому запускать скрипт нужно с `--tag` (и обычно `--push`).

```bash
# релиз только из main (ветка должна быть активной) + чистый git status
Scripts/release_local.sh --version 1.2.3

# или авто-bump от последнего тега vX.Y.Z
Scripts/release_local.sh --bump patch

# обязательно: создать тег и запушить main + тег (релиз без тега запрещён)
Scripts/release_local.sh --bump minor --tag --push

# если указываете версию вручную — тоже добавляйте --tag/--push
Scripts/release_local.sh --version 1.2.3 --tag --push

# если нужно обновить версию без автокоммита
Scripts/release_local.sh --version 1.2.3 --no-version-commit
```

Артефакты сохраняются в `Build/Releases/vX.Y.Z/`. Для iOS export используется `ExportOptions.plist` (можно переопределить `--export-options-plist`).

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

# Только SettingsReducer с сохранением результата в xcresult
xcodebuild test \
  -scheme Remission \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RemissionTests/SettingsFeatureTests \
  -resultBundlePath build/TestResults/SettingsFeatureTests.xcresult

# UI-тест персистентности настроек (использует UI_TESTING_PREFERENCES_SUITE)
UI_TESTING_PREFERENCES_SUITE=ui-settings-persistence \
xcodebuild test \
  -scheme Remission \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RemissionUITests/RemissionUITests/testSettingsPersistenceAcrossLaunches \
  -resultBundlePath build/TestResults/SettingsPersistenceUI.xcresult
```

#### Точечные проверки списка торрентов

```bash
# Только редьюсер TorrentListReducer (Swift Testing)
xcodebuild test \
  -scheme Remission \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RemissionTests/TorrentListFeatureTests

# UI-тест списка торрентов (фикстура torrent-list)
xcodebuild test \
  -scheme Remission \
  -testPlan RemissionUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:RemissionUITests/RemissionUITests/testTorrentListSearchAndRefresh
```

#### UI фикстуры, аргументы и переменные окружения

| Аргумент | Назначение |
| --- | --- |
| `--ui-testing-fixture=server-list-sample` | Предзаполняет список серверов демо-данными |
| `--ui-testing-fixture=torrent-list-sample` | Создаёт in-memory `ServerConnectionEnvironment` и `TorrentRepository` с тремя торрентовыми фикстурами |
| `--ui-testing-scenario=server-list-sample` | Настраивает сценарий перехода в детали из списка серверов |
| `--ui-testing-scenario=torrent-list-sample` | Включает вспомогательные зависимости для теста поиска/refresh в списке торрентов |
| `--ui-testing-scenario=onboarding-flow` | Инициализирует in-memory репозитории для онбординга |
| `UI_TESTING_PREFERENCES_SUITE=<suite>` | Направляет UI-тесты настроек в отдельный `UserDefaults(suiteName:)`, чтобы проверять персистентность между перезапусками |

Добавьте аргументы в схему (`Edit Scheme… → Arguments`) или передайте через CLI (`xcodebuild test ... OTHER_ARGUMENTS`).

## Troubleshooting

### Сброс ServerConnectionEnvironment при ошибках подключения

`ServerConnectionEnvironment` инкапсулирует TransmissionClient/TorrentRepository для конкретного сервера. Если список торрентов перестал обновляться (поллинг завис в ошибке, UI не выходит из «Подключаемся…»):

1. **Повторите подключение** — на экране сервера нажмите «Повторить подключение». Редьюсер заново вызовет `serverConnectionEnvironmentFactory.make(...)` и пересоздаст клиент.
2. **Сделайте teardown вручную** — закройте экран деталей или перезапустите приложение. Это диспатчит `.torrentList(.teardown)` и принудительно обнуляет окружение; при следующем `task` окружение будет создано заново.
3. **Пересохраните сервер** — нажмите «Редактировать», измените любой параметр (или нажмите «Сохранить» без изменений). Обновлённый `connectionFingerprint` вызовет teardown и создание нового окружения.
4. **Используйте фикстуру** — для UI-тестов и ручного smoke прогона запустите приложение с аргументом `--ui-testing-fixture=torrent-list-sample`: он подставит in-memory зависимости и гарантирует чистое состояние.

Если после этих шагов ошибка сохраняется, удалите сервер из списка (что очистит креды/траст) и добавьте заново; при необходимости см. логи Transmission (см. `devdoc/LOGGING_GUIDE.md`) или консоль Xcode.

## Документация

- **`devdoc/PRD.md`** — Product Requirements Document с подробным описанием функциональности
- **`AGENTS.md`** — Справочник архитектуры, соглашений и инструкций для разработчиков и AI-агентов
- **`devdoc/plan.md`** — План развития проекта и дорожная карта
- **`devdoc/LOGGING_GUIDE.md`** — как включать/собирать логи, правила безопасности, телеметрия
- **`devdoc/QA_REPORT_RTC70+.md`** — smoke-сценарии QA для списка торрентов и связанных фич

## Лицензия

Проект распространяется под лицензией, указанной в LICENSE файле (если присутствует).

## Связь

Для вопросов и предложений обратитесь к владельцу проекта или создайте issue в репозитории.
