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
  - State sharing: используйте `@Presents` для опциональных состояний (sheets, alerts, navigation stacks) и `IdentifiedArrayOf` для коллекций.
    - **@Presents использовать для:**
      - Alerts: `@Presents var alert: AlertState<AlertAction>?`
      - Modals/Sheets: `@Presents var editor: ServerEditorReducer.State?`
      - Navigation с tree-based routing (будущая веха)
    - **Пример (RTC-67)**:
      ```swift
      @ObservableState
      struct State: Equatable {
          var server: ServerConfig
          @Presents var alert: AlertState<AlertAction>?  // Alert state
          @Presents var editor: ServerEditorReducer.State?  // Modal
      }
      ```
  - Effects: все побочные эффекты инкапсулируются через `.run { send in ... }` блоки в reducer.
  - Navigation: используйте SwiftUI's `NavigationStack` с TCA state-driven подходом.
  - Тестирование: используйте `TestStore` для exhaustive тестирования reducers и effects (все mutations и side effects проверяются).
- Для каждого TCA reducer минимум два теста (happy path + error path); эффекты мокируются через зависимости в Environment.
- `TransmissionClientProtocol` реализует Transmission RPC вызовы (собственный протокол поверх HTTP(S), НЕ JSON-RPC 2.0). Обработка рукопожатия (HTTP 409, session-id). Версионирование: поддержка Transmission 3.0+ (рекомендуется 4.0+). **Справочник**: `devdoc/TRANSMISSION_RPC_REFERENCE.md`. Репозитории превращают сырой RPC в доменные модели.
- Используем async/await, Task, actors; помечаем публичные API @MainActor/@Sendable при необходимости; для детерминированных тестов времени применяем `swift-clocks`.
- Все преобразования Transmission RPC → доменных моделей выполняем через `TransmissionDomainMapper` (см. `Remission/Domain/TransmissionDomainMapper*.swift`). В фичах и сервисах не разбираем `AnyCodable` вручную; это обеспечит единое поведение ошибок (`DomainMappingError`) и учёт допущений (например, `percentDone` трактуется как доля при значениях 0…1 и как проценты при значениях >1).

## Project Layout & Toolchain
- `Remission/` - SwiftUI entry point (`RemissionApp.swift`), основные экраны, ресурсы (`Assets.xcassets`).
  - **Модульная структура:**
    - `Remission/Features/<FeatureName>/` — TCA Reducers для feature-модулей
      - `Onboarding/` — онбординг и первичная настройка
      - `ServerList/` — список серверов
      - `ServerDetail/` — детали сервера и управление подключением
      - `ServerEditor/` — создание/редактирование конфигурации сервера
    - `Remission/Views/<FeatureName>/` — SwiftUI View компоненты
      - `App/` — корневой AppView
      - `Onboarding/`, `ServerList/`, `ServerDetail/`, `ServerEditor/` — Views для соответствующих features
      - `TorrentDetail/` — компоненты детального просмотра торрента
      - `Shared/` — переиспользуемые UI компоненты
    - `Remission/Domain/` — доменные модели и маппинг из RPC
      - `ServerConfig.swift`, `Torrent.swift`, `SessionState.swift`, `UserPreferences.swift`
      - `TransmissionDomainMapper*.swift` — маппинг RPC ответов в доменные модели
    - `Remission/DependencyClients/` — определения dependency clients (протоколы и placeholder реализации)
      - `AppClockDependency.swift`, `TransmissionClientDependency.swift`, `KeychainCredentialsDependency.swift`, и т.д.
    - `Remission/DependencyClientLive/` — live-реализации зависимостей для production
      - `TransmissionClientDependency+Live.swift`, `KeychainCredentialsDependency+Live.swift`
    - `Remission/Shared/` — общие утилиты и типы
      - `ServerConnectionFormState.swift` — переиспользуемые состояния и модели
    - **Корневые файлы** — репозитории, сервисы, фабрики окружений:
      - Repositories: `TorrentRepository.swift`, `SessionRepository.swift`, `CredentialsRepository.swift`, `ServerConfigRepository.swift`, `UserPreferencesRepository.swift`, `OnboardingProgressRepository.swift`
      - Network: `TransmissionClient.swift`, `TransmissionClientConfig.swift`, `TransmissionClientProtocol.swift`
      - Trust & Security: `TransmissionTrustStore.swift`, `TransmissionTrustPromptCenter.swift`, `KeychainCredentialsStore.swift`
      - Factories: `ServerConnectionEnvironment.swift` — фабрика per-server окружений
      - Bootstrap: `AppBootstrap.swift`, `AppDependencies.swift`, `AppFeature.swift`
  - **Размещение зависимостей и фабрик:**
    - **Простые DependencyClient**: размещайте в `Remission/DependencyClients/` (например, `UserPreferencesClient.swift`, `ClockClient.swift`)
    - **Сложные фабрики**: размещайте в корне `Remission/` как отдельные файлы (например, `ServerConnectionEnvironment.swift` для RTC-67). Фабрика должна быть видна всем reducers
    - **Правило**: Если factory создаёт per-context сервисы (per-server, per-workspace), размещайте в `Remission/` и регистрируйте в `AppDependencies.swift`
    - **Environment структуры**: размещайте рядом с фабриками (например, `ServerConnectionEnvironment.swift` рядом с фабрикой)
- `RemissionTests/` - Тесты на Swift Testing фреймворке; именуйте файлы в паре с production-модулями.
  - `RemissionTests/Support/` — вспомогательные утилиты для тестов
    - `DependencyOverrides.swift` — шаблоны переопределения зависимостей для TestStore
    - `TestStoreFactory.swift` — фабрики TestStore с преднастроенными зависимостями
  - `RemissionTests/Fixtures/` — тестовые данные и фикстуры
    - `Transmission/` — JSON-фикстуры ответов Transmission RPC
    - `Domain/` — фикстуры доменных моделей
    - `TransmissionFixture.swift` — загрузчик фикстур
    - `README-fixtures.md` — документация по использованию фикстур
  - Тесты фич: `OnboardingFeatureTests.swift`, `ServerListFeatureTests.swift`, `ServerDetailFeatureTests.swift`, и т.д.
  - Тесты инфраструктуры: `TransmissionClient*Tests.swift`, `TransmissionDomainMapperTests.swift`
- `RemissionUITests/` - XCUITest сценарии и smoke-проверки.
- `devdoc/PRD.md` - PRD, обязательное обновление при функциональных изменениях.

### Структура при разделении на Swift Packages (будущая масштабируемость):
- `Sources/` — корневая папка для Swift Package модулей
  - `Features/` — feature-модули как отдельные пакеты (TorrentList, TorrentDetail, AddTorrent)
  - `Services/` — сетевой слой и бизнес-логика (TransmissionClient, SyncService, Repositories)
  - `Shared/` — общие модели, утилиты и переиспользуемые UI компоненты (Models, Utils, Views)

### Стартовые команды:
  - `open Remission.xcodeproj` - запуск Xcode (схема `Remission`).
  - `xcodebuild -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e' build` - CLI-сборка.
  - `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e'` - unit + UI тесты; запускайте перед любым PR.

**VS Code Tasks (рекомендуется для AI-агентов):**
Проект настроен с готовыми tasks в `.vscode/tasks.json`. Используйте их через Command Palette (`Cmd+Shift+P` → "Tasks: Run Task"):

- `SwiftLint (run)` — запуск линтера с JSON-репортером
- `Run Unit Tests` — запуск unit-тестов для macOS (быстрее, чем симулятор)
- `Xcode Build (Debug)` — сборка Debug конфигурации (зависит от SwiftLint и тестов)
- `Run App` — открыть собранное приложение
- `Archive (Release)` — создание Release-архива с автоинкрементом версии
- `Export App (IPA)` — экспорт IPA из архива
- `Archive & Export (Personal Team)` — полный цикл: increment version → archive → export

Для запуска task из командной строки или в агентских сценариях:
```bash
# Запуск линтера
swiftlint lint --quiet --reporter json

# Запуск тестов на macOS (быстрее)
xcodebuild test -scheme Remission -configuration Debug -destination 'platform=macOS,arch=arm64' | xcbeautify

# Полная сборка с проверками
xcodebuild -scheme Remission -configuration Debug build | xcbeautify
```

- Воспользуйтесь SwiftUI previews (см. примеры в `Remission/Views/App/AppView.swift`) для быстрой итерации UI.
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

### Пример: Тестирование TCA reducer с TestStore и мокированием зависимостей (RTC-67+)

```swift
@Test
func serverDetailConnectionSuccess() async {
    let server = ServerConfig.previewLocalHTTP
    let handshake = TransmissionHandshakeResult(
        sessionID: "session-1",
        rpcVersion: 20,
        minimumSupportedRpcVersion: 14,
        serverVersionDescription: "Transmission 4.0.3",
        isCompatible: true
    )
    let environment = ServerConnectionEnvironment.testEnvironment(
        server: server,
        handshake: handshake
    )

    let store = TestStore(
        initialState: ServerDetailReducer.State(server: server)
    ) {
        ServerDetailReducer()
    } withDependencies: { dependencies in
        // Переопределить зависимости для теста
        dependencies = AppDependencies.makeTestDefaults()
        dependencies.serverConnectionEnvironmentFactory = .mock(environment: environment)
    }

    // Отправить действие и проверить state mutations
    await store.send(.task) {
        $0.connectionState.phase = .connecting
    }

    // Проверить эффект (асинхронный результат)
    await store.receive(
        .connectionResponse(
            .success(
                ServerDetailReducer.ConnectionResponse(
                    environment: environment,
                    handshake: handshake
                )
            )
        )
    ) {
        $0.connectionEnvironment = environment
        $0.connectionState.phase = .ready(
            .init(fingerprint: environment.fingerprint, handshake: handshake)
        )
    }
}

@Test
func serverConnectionFailureShowsAlert() async {
    let server = ServerConfig.previewSecureSeedbox
    let expectedError = ServerConnectionEnvironmentFactoryError.missingCredentials

    let store = TestStore(
        initialState: ServerDetailReducer.State(server: server)
    ) {
        ServerDetailReducer()
    } withDependencies: { dependencies in
        dependencies = AppDependencies.makeTestDefaults()
        // Мокировать factory с ошибкой
        dependencies.serverConnectionEnvironmentFactory = .init { _ in
            throw expectedError
        }
    }

    await store.send(.task) {
        $0.connectionState.phase = .connecting
    }

    // Проверить error path
    await store.receive(.connectionResponse(.failure(expectedError))) {
        $0.connectionEnvironment = nil
        $0.connectionState.phase = .failed(.init(message: expectedError.errorDescription ?? ""))
        $0.alert = .connectionFailure(message: expectedError.errorDescription ?? "")
    }
}
```

**Ключевые моменты**:
- `withDependencies` блок для переопределения всех зависимостей
- `await store.send(...)` для диспатча действия с проверкой state mutations
- `await store.receive(...)` для проверки эффектов (асинхронных результатов)
- Happy path и error path тестируются отдельно
- Используйте `LockedValue` для thread-safe проверки побочных эффектов в сложных тестах
- **Пример многослойной композиции (ServerDetail → TorrentDetail)**:
  ```swift
  // Родитель сохраняет окружение и передаёт детям
  case .connectionResponse(.success(let response)):
      state.connectionEnvironment = response.environment
      state.torrentList.connectionEnvironment = response.environment
      state.torrentDetail?.applyConnectionEnvironment(response.environment)

  case .torrentList(.delegate(.openTorrent(let id))):
      guard let item = state.torrentList.items[id: id] else { return .none }
      var detailState = TorrentDetailReducer.State(torrent: item.torrent)
      detailState.applyConnectionEnvironment(state.torrentList.connectionEnvironment)
      state.torrentDetail = detailState
  ```
  ```swift
  @Reducer
  struct TorrentDetailReducer {
      mutating func applyConnectionEnvironment(
          _ environment: ServerConnectionEnvironment?
      ) {
          connectionEnvironment = environment
          guard environment == nil else { return }
          pendingCommands.removeAll()
          activeCommand = nil
      }
  }
  ```
  Такой шаблон гарантирует повторное использование `ServerConnectionEnvironment` на всех уровнях и предотвращает повторный handshake/создание клиентов при навигации по дочерним экранам.

- Integration: поднятие Transmission через Docker-compose в CI, прогон сценариев connect/add/start/stop/remove.
- UI: XCUITest для onboarding, списка и добавления торрента (Given/When/Then комментарии).
- Цель покрытия >=60% на ключевых компонентах; отчёты прикладываем к PR.

### Измерение код-кавера:
- **Инструменты**: xcov или встроенные Code Coverage инструменты Xcode
- **Запуск с отчётом**:
```bash
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' \
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
  - Нюанс: правило `opening_brace` конфликтует с длинными условиями после `swift-format`; читайте раздел «Совместимость со swift-format» в `devdoc/SWIFTLINT.md`
  - На Apple Silicon (M1/M2/M3): скрипт автоматически добавляет `/opt/homebrew/bin` в PATH
  - Полная документация: `devdoc/SWIFTLINT.md`
- **Pre-commit hooks**: используйте `bash Scripts/prepare-hooks.sh` для установки git hook'а, который автоматически проверяет код перед коммитом. Hook запускает swift-format lint --strict и SwiftLint.

### Обязательные checks перед merge

- ✅ `swift-format lint --configuration .swift-format --recursive --strict`
- ✅ `swiftlint lint` (0 violations)
- ✅ `Scripts/check-localizations.sh` (или Xcode build phase “Localizations Check”) — падение сборки при пропущенных переводах/плейсхолдерах
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
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' build

# macOS
xcodebuild -scheme Remission -sdk macosx build

# Все тесты
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e'
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
- [ ] **TCA-композиция:** пройти `Templates/FeatureChecklist.md` и убедиться, что фича соответствует гайду из `devdoc/plan.md` (раздел RTC-59).
- [ ] **Dependency overrides:** используйте `RemissionTests/Support/DependencyOverrides.swift` и `RemissionTests/README.md` для примеров `withDependencies` и моков.

**Перед push запустите:**
```bash
bash Scripts/prepare-hooks.sh  # если ещё не установлены hooks
git status                      # проверка изменений
swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests
swiftlint lint
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e'
```
