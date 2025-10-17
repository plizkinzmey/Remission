# Remission Agent Handbook

## Product Overview
- Remission - кроссплатформенный клиент (iOS + macOS) для удалённого управления Transmission через RPC, ориентированный на быстрый контроль и мониторинг торрентов.
- MVP обеспечивает подключение к одному или нескольким серверам, просмотр и управление торрентами, добавление .torrent/magnet, безопасное хранение учётных данных в Keychain.
- Основные пользователи - домашние администраторы NAS/серверов и технические пользователи, которым нужен мобильный и десктопный доступ.
- Любое изменение пользовательских сценариев синхронизируйте с `devdoc/PRD.md`; PRD остаётся источником истины по функционалу.

## Functional Scope (MVP->v1)
- **Подключение и конфигурация**: настройка host/port/proto, Basic Auth, проверка статуса соединения, управление сохранёнными серверами, обязательная запись секретов в Keychain.
- **Список торрентов**: отображение идентификатора, статуса, прогресса, скоростей и peers; поиск, сортировки, фильтры; обновление по настраиваемому polling-интервалу.
- **Детали торрента**: файлы, трекеры, peers, история скоростей, путь загрузки; действия Start/Pause/Remove/Verify/Set Priority.
- **Добавление торрентов**: импорт .torrent из Files/Share, обработка magnet-ссылок, выбор каталога, запуск в паузе, опциональные теги.
- **Настройки**: polling interval, автообновление при старте, лимиты скоростей, локализации RU/EN (RU по умолчанию), управление сохранёнными серверами.
- **Логи и телеметрия**: локальное логирование сетевых ошибок; внешняя отправка метрик только по явному согласию пользователя.
- **Нефункциональные цели**: отзывчивость UI при 200+ торрентах (<200 мс в LAN), успех команд >98%, тестовое покрытие ключевых компонентов >=60%.

## Architecture & Patterns
- Базовая архитектура: **TCA (The Composable Architecture)** для всех feature-модулей + слои network/domain/persistence; бизнес-логика не живёт во View.
- **The Composable Architecture (TCA)** для feature-модулей: обязательный паттерн для управления состоянием (исключение: только тривиальные View без состояния).
  - Структура: `@ObservableState struct State`, `enum Action`, `Reducer` с `var body`, store инициализируется с `Store(initialState:, reducer:)`.
  - State sharing: используйте `@Presents` для опциональных состояний (sheets, alerts) и `IdentifiedArrayOf` для коллекций.
  - Effects: все побочные эффекты инкапсулируются через `.run { send in ... }` блоки в reducer.
  - Navigation: используйте SwiftUI's `NavigationStack` с TCA state-driven подходом.
  - Тестирование: используйте `TestStore` для exhaustive тестирования reducers и effects (все mutations и side effects проверяются).
- Для каждого TCA reducer минимум два теста (happy path + error path); эффекты мокируются через зависимости в Environment.
- `TransmissionClientProtocol` реализует Transmission RPC вызовы (собственный протокол поверх HTTP(S), НЕ JSON-RPC 2.0). Обработка рукопожатия (HTTP 409, session-id). Версионирование: поддержка Transmission 3.0+ (рекомендуется 4.0+). **Справочник**: `devdoc/TRANSMISSION_RPC_REFERENCE.md`. Репозитории превращают сырой RPC в доменные модели.
- Используем async/await, Task, actors; помечаем публичные API @MainActor/@Sendable при необходимости; для детерминированных тестов времени применяем `swift-clocks`.

## Project Layout & Toolchain
- `Remission/` - SwiftUI entry point (`RemissionApp.swift`), основные экраны, ресурсы (`Assets.xcassets`).
- `RemissionTests/` - Тесты на Swift Testing фреймворке; именуйте файлы в паре с production-модулями.
- `RemissionUITests/` - XCUITest сценарии и smoke-проверки.
- `devdoc/PRD.md` - PRD, обязательное обновление при функциональных изменениях.

### Структура при разделении на Swift Packages (будущая масштабируемость):
- `Sources/` — корневая папка для Swift Package модулей
  - `Features/` — feature-модули как отдельные пакеты (TorrentList, TorrentDetail, AddTorrent)
  - `Services/` — сетевой слой и бизнес-логика (TransmissionClient, SyncService, Repositories)
  - `Shared/` — общие модели, утилиты и переиспользуемые UI компоненты (Models, Utils, Views)

### Стартовые команды:
  - `open Remission.xcodeproj` - запуск Xcode (схема `Remission`).
  - `xcodebuild -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15' build` - CLI-сборка.
  - `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15'` - unit + UI тесты; запускайте перед любым PR.
- Воспользуйтесь SwiftUI previews (`ContentView.swift`) для быстрой итерации UI.
- Форматирование и стиль: `swift-format` (обязательно в pre-commit/CI) и `swiftlint`. Следуйте Swift 6 API Design Guidelines (4 пробела, PascalCase типов, camelCase членов, noun-based протоколы).
- Извлекайте переиспользуемые SwiftUI компоненты в отдельные файлы после ~150 строк; ассеты именуем в snake_case (`icon_start`).

## Security, Reliability & Performance
- Все учётные данные сохраняем через Keychain; исключаем утечки секретов в логи.
- Поддерживаем HTTPS/TLS и проверяем сертификаты, если сервер предоставляет.
- Basic Auth отправляем безопасно и храним минимально необходимый набор.
- Сетевые ошибки логируем, показываем понятные сообщения, реализуем retry c экспоненциальной задержкой и обработку несовместимости версий Transmission.
- UI должен оставаться responsive при потоках >200 торрентов: используйте lazy-loading/pagination и оптимизируйте запросы (`torrent-get` с выбранными полями).

## Testing & QA
- **Фреймворк тестирования**: Swift Testing (встроенный модуль) с атрибутом `@Test` — современная альтернатива XCTest.
  - Структура: `@Test` вместо `test*` методов, `@Suite` для группировки, `#expect` и `#require` для проверок.
  - Параметризованные тесты поддерживают аргументы, что снижает дублирование кода.
  - Conditional traits (`@Test(.enabled(if:))`, `@Suite(.serialized)`) управляют выполнением тестов.
- Unit-тесты: сетевой слой (TransmissionClientProtocol), репозитории, TCA редьюсеры с TestStore. Все тесты используют Swift Testing фреймворк и мокируют зависимости через @Dependency DI.
- Integration: поднятие Transmission через Docker-compose в CI, прогон сценариев connect/add/start/stop/remove.
- UI: XCUITest для onboarding, списка и добавления торрента (Given/When/Then комментарии).
- Цель покрытия >=60% на ключевых компонентах; отчёты прикладываем к PR.

### Измерение код-кавера:
- **Инструменты**: xcov или встроенные Code Coverage инструменты Xcode
- **Запуск с отчётом**:
```bash
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12' \
  -resultBundlePath ./build/test.xcresult -code-coverage
xcov report --workspace Remission.xcworkspace --scheme Remission --output_directory ./coverage
```

## CI Pipeline

CI pipeline автоматически запускает проверки при push. Все checks обязательны перед merge.

### Инструменты и конфигурация

- CI pipeline: swift-format, swiftlint, build, unit/UI тесты, интеграционные сценарии (Transmission docker). Рассмотрите статический анализ Swift 6 preview, если требуется.
- **swift-format** (Apple): конфигурация хранится в `.swift-format` в корне репозитория. 
  - Локально запустите: `swift-format format --in-place --configuration .swift-format --recursive Remission RemissionTests RemissionUITests` для форматирования
  - Проверка: `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests`
- **SwiftLint** (версия 0.61.0+): конфигурация в `.swiftlint.yml`, интегрирован в Xcode build phase
  - Локально: `swiftlint lint` для проверки, `swiftlint --fix` для автоисправлений
  - На Apple Silicon (M1/M2/M3): скрипт автоматически добавляет `/opt/homebrew/bin` в PATH
  - Полная документация: `devdoc/SWIFTLINT.md`
- **Pre-commit hooks**: используйте `bash Scripts/prepare-hooks.sh` для установки git hook'а, который автоматически проверяет код перед коммитом. Hook запускает swift-format lint --strict и SwiftLint.

### Обязательные checks перед merge

- ✅ `swift-format lint --configuration .swift-format --recursive --strict`
- ✅ `swiftlint lint` (0 violations)
- ✅ `xcodebuild build`
- ✅ `xcodebuild test` (unit + UI тесты)
- ✅ Покрытие тестами >= 60% на ключевых компонентах

### Локальный workflow перед push

```bash
bash Scripts/prepare-hooks.sh  # установить pre-commit hook (один раз)
git status                      # проверка изменений
swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests
swiftlint lint
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
git commit -m "Your message"    # hook автоматически проверит код перед коммитом
```

### Релиз и совместимость

- Перед релизом проверяйте миграции API Transmission, избегайте жёстких зависимостей от конкретной версии
- Добавьте handshake/compatibility checks для новых версий Transmission
- Документируйте публичные API и контракты краткими комментариями
- Избегайте дублирования бизнес-логики между слоями

## Documentation & Knowledge Base

### Structure

```
devdoc/
├── PRD.md                           # Product Requirements
├── plan.md                          # Architecture, roadmap, API contracts
├── SWIFTLINT.md                     # SwiftLint configuration details
├── CONTEXT7_GUIDE.md                # How to research documentation (THIS IS CRITICAL)
└── TRANSMISSION_RPC_REFERENCE.md    # Transmission RPC API reference
```

### Key Documents

**devdoc/plan.md**
- Contains: Milestones, architecture decisions, API contracts (e.g., "Transmission RPC API контракт")
- Updated by: Architecture tasks (RTC-N), research/investigation tasks
- Used by: All implementation tasks link here for reference

**devdoc/CONTEXT7_GUIDE.md** ⭐ READ THIS FIRST
- Purpose: How to use Context7 for research (DO NOT skip this!)
- Contains: Step-by-step workflow, real examples, best practices
- When to use: Before researching any new API, library, or framework
- Workflow: resolve-library-id → get-library-docs → create-contract → update-tasks

**devdoc/TRANSMISSION_RPC_REFERENCE.md**
- Contains: Transmission RPC methods, authentication, error handling, edge cases
- Purpose: Quick reference for developers implementing RTC-19+
- Sections: Core methods, auth flow, JSON-RPC structure, status codes, compatibility
- Links: Used by RTC-11, RTC-12, RTC-13, RTC-19, etc.

**devdoc/PRD.md**
- Product requirements and user scenarios
- Updated when functional scope changes
- Read this FIRST when starting work on any task

### Knowledge Sharing Pattern

Every research task (like RTC-16) follows this pattern:

```
1. Investigate through Context7
   ↓
2. Create/update contract in devdoc/plan.md or separate reference file
   ↓
3. Update ALL related Linear tasks with "Справочные материалы" sections
   ↓
4. Each task now has direct link to documentation
   ↓
5. Developers don't need to hunt for docs—they're in every task!
```

**Why this matters**: If developer only reads task description, they'll find the link they need. No knowledge is siloed in one place.

## Workflow & Collaboration
- **КРИТИЧЕСКИ ВАЖНО**: Перед реализацией любого кода, конфигурации или инструмента **обязательно обратитесь в Context7** для получения актуальной информации и документации. Никогда не полагайтесь на гипотезы или устаревшие знания. Используйте `mcp_context7_resolve-library-id` и `mcp_context7_get-library-docs` для получения последней информации. **Прочитайте `devdoc/CONTEXT7_GUIDE.md` для понимания workflow!**
- Коммит-месседжи: лаконичные императивы на русском (`Добавить поддержку удаленного подключения`), одна логическая правка на коммит.
- PR содержат описание изменений, ссылки на PRD/тикеты, доказательство прогона тестов (лог или скрин).
- Поддерживайте синхронизацию документации: изменения функционала -> обновления `devdoc/PRD.md`, релевантные README/CONTRIBUTING правки.
- Перед мерджем убедитесь, что новая функциональность покрыта тестами и проверена локально (`xcodebuild test ...`).

## Environment & Requirements

- **Xcode:** 15.0 или выше
- **Swift:** 6.0+
- **iOS deployment target:** 26.0+
- **macOS deployment target:** 26.0+
- **visionOS deployment target:** 26.0+
- **Обязательные инструменты:** swift-format 602.0.0+, SwiftLint 0.61.0+

## Build Settings & Unified Configuration

Проект использует унифицированные build settings для всех целей и платформ (iOS, macOS, visionOS) с целью предотвращения расхождений в поведении приложения и упрощения поддержки кроссплатформенности.

### Ключевые параметры сборки

| Параметр | Значение | Обоснование |
|----------|----------|-----------|
| **SWIFT_VERSION** | 6.0 | Все цели используют Swift 6.0 для совместимости с требованиями проекта |
| **IPHONEOS_DEPLOYMENT_TARGET** | 26.0 | Минимальная поддерживаемая версия iOS согласно требованиям Environment & Requirements |
| **MACOSX_DEPLOYMENT_TARGET** | 26.0 | Минимальная поддерживаемая версия macOS согласно требованиям |
| **XROS_DEPLOYMENT_TARGET** | 26.0 | Минимальная поддерживаемая версия visionOS согласно требованиям |
| **SUPPORTED_PLATFORMS** | iphoneos iphonesimulator macosx xros xrsimulator | Все поддерживаемые платформы |
| **SDKROOT** | auto | Автоматический выбор SDK в зависимости от целевой платформы |
| **SWIFT_APPROACHABLE_CONCURRENCY** | YES | Встроенная поддержка async/await и современного concurrency подхода |
| **SWIFT_DEFAULT_ACTOR_ISOLATION** | MainActor | Все основные цели маркируются как @MainActor по умолчанию для безопасности потокового кода |
| **SWIFT_EMIT_LOC_STRINGS** | YES (основное) / NO (тесты) | Генерация локализованных строк для основного приложения, отключено для тестов |
| **SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY** | YES | Включение предстоящих фич Swift 6 для лучшей совместимости |
| **STRING_CATALOG_GENERATE_SYMBOLS** | YES (основное) / NO (тесты) | Генерация символов из строковых каталогов для основного приложения |

### Отличия между целями

**Основная цель (Remission app):**
- Все warning flags включены
- App Sandbox включён (`ENABLE_APP_SANDBOX = YES`)
- Hardened Runtime включён (`ENABLE_HARDENED_RUNTIME = YES`)
- User-selected files поддержка readonly (`ENABLE_USER_SELECTED_FILES = readonly`)
- Автоматическое распределение рабочей нагрузки (`BuildIndependentTargetsInParallel = 1`)

**Тестовые цели (RemissionTests, RemissionUITests):**
- Те же базовые параметры Swift и Deployment Target
- Строка каталогов не генерируется (`STRING_CATALOG_GENERATE_SYMBOLS = NO`)
- Локализованные строки не эмитируются (`SWIFT_EMIT_LOC_STRINGS = NO`)
- TEST_HOST указывает на основную цель для удобства линкования

### Проверка унифицированности

Для проверки, что все build settings синхронизированы, выполните:

```bash
# iOS Simulator
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12' build

# macOS
xcodebuild -scheme Remission -sdk macosx build

# Все тесты
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12'
xcodebuild test -scheme Remission -sdk macosx
```

Обе сборки должны завершиться с **BUILD SUCCEEDED** и **TEST SUCCEEDED** без новых предупреждений.

## Git & Branching

- **Branch naming:** `feature/RTC-N-краткое-описание`, `fix/RTC-N-краткое-описание`, `docs/RTC-N-краткое-описание`
- **Commits:** все сообщения на русском, одна логическая правка на коммит
- **Подпись коммитов:** рекомендуется `git commit -S` (GPG signing), но не обязательна
- **Pull Requests:** все изменения через PRs с обязательным ревью перед merge

## Common Pitfalls & How to Avoid

1. **Смешение TCA и @State/@StateObject в одной View**
   - ❌ Неправильно: `@State var torrents = []` + TCA Store одновременно
   - ✅ Правильно: всё состояние идёт через Store и `@Bindable`

2. **Сохранение секретов в лог**
   - ❌ Неправильно: `print("Transmission auth: \(username):\(password)")`
   - ✅ Правильно: логировать только "Auth successful" или error codes

3. **Прямые network calls в View**
   - ❌ Неправильно: `URLSession.shared.dataTask(...).resume()` в `body { }`
   - ✅ Правильно: в Reducer effect через `.run { send in ... }`

4. **Забывают тесты для редьюсеров**
   - ❌ Новая фича без TestStore
   - ✅ Минимум: happy path + 1 error path тест

5. **Модифицируют State напрямую вне Reducer**
   - ❌ Неправильно: `store.state.torrents.append(newTorrent)`
   - ✅ Правильно: `store.send(.addTorrent(newTorrent))` через Action → Reducer

6. **Забывают инициализировать Store с правильными зависимостями**
   - ❌ Неправильно: `Store(initialState: TorrentListState())` без Environment
   - ✅ Правильно: использовать `@Dependency(\.repository)` в Reducer body и предоставить моки в тестах через TestStore

## Quick Checklist для нового feature

При создании нового feature-модуля убедитесь перед commit:

- [ ] **Ветка:** `feature/RTC-N-описание` или `fix/RTC-N-описание`
- [ ] **TCA структура:** @ObservableState State → enum Action → @Reducer
- [ ] **Покрытие тестами:** TestStore с happy path + error path (минимум 2 теста)
- [ ] **Форматирование:** `swift-format lint --configuration .swift-format --recursive --strict` ✅
- [ ] **Линтинг:** `swiftlint lint` ✅ (0 violations)
- [ ] **Тестовое покрытие:** >= 60% критических путей
- [ ] **Коммит-месседж:** на русском, одна логическая правка
- [ ] **PR:** ссылка на Linear task (RTC-N), доказательство прогона тестов
- [ ] **Никаких credentials в логах:** пароли, session-id, API keys НЕ логируются
- [ ] **Keychain для секретов:** все credentials сохраняются в Keychain, не в UserDefaults

**Перед push запустите:**
```bash
bash Scripts/prepare-hooks.sh  # если ещё не установлены hooks
git status                      # проверка изменений
swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests
swiftlint lint
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```
