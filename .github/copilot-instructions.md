Это репозиторий клиента Remission для удалённого управления Transmission. Документ помогает AI-агентам быстро разобраться в архитектуре SwiftUI/TCA, принятых соглашениях и обязательных шагах перед коммитами.

- Ключевые факты
- Язык: Swift (SwiftUI). Проект использует Swift 6 — все изменения должны быть совместимы с Swift 6 и билдиться с соответствующим режимом компилятора.
- Точка входа приложения: `Remission/RemissionApp.swift` — `@main` App struct.
- Основной UI: `Remission/Views/App/AppView.swift` — корневой `View`, используемый в `WindowGroup`.
- Тесты: `RemissionTests/` (unit tests) и UI-тесты в `RemissionUITests/`. Используется Swift Testing фреймворк с атрибутом `@Test`.
- В репозитории присутствует `.github/copilot-instructions.md`; также добавлены `.gitignore` и `devdoc/PRD.md`. Этот файл служит главным источником инструкций для AI-агентов.

- Что менять и почему
- Небольшие изменения интерфейса/фич: 
  - Feature-модули (TCA Reducers) размещаются в `Remission/Features/<FeatureName>/`
  - View-компоненты размещаются в `Remission/Views/<FeatureName>/`
  - Dependency Clients размещаются в `Remission/DependencyClients/`
  - Live-реализации зависимостей — в `Remission/DependencyClientLive/`
- Жизненный цикл приложения/конфигурация: редактируйте `RemissionApp.swift` (он отвечает за корневой вид `AppView`).
- Тесты размещаются в `RemissionTests/` (unit) и `RemissionUITests/` (UI). В тестах используется Swift Testing фреймворк с атрибутом `@Test`.
  - Вспомогательные утилиты для тестов: `RemissionTests/Support/`
  - Фикстуры и тестовые данные: `RemissionTests/Fixtures/`
- State management: проект использует единую стратегию — The Composable Architecture (TCA). Все feature-модули должны реализовываться через TCA (@ObservableState State, enum Action, Reducer). Не смешивать MVVM и TCA в одном модуле.
- Network layer: TransmissionClient реализует Transmission RPC вызовы (собственный протокол, не JSON-RPC 2.0). Обработка аутентификации (Basic Auth + HTTP 409 handshake для session-id). Справочник: `devdoc/TRANSMISSION_RPC_REFERENCE.md`.
- Mapping layer: любые ответы Transmission RPC переводите в доменные модели (`Torrent`, `SessionState`, `ServerConfig`) через `TransmissionDomainMapper` (файлы `Remission/Domain/TransmissionDomainMapper*.swift`). Не парсим `AnyCodable` в фичах напрямую — это гарантирует единый набор проверок и ошибок (`DomainMappingError`). Допущение по полю `percentDone`: Transmission возвращает либо double 0.0…1.0, либо Int 0…100; интеджеры >1 воспринимаются как проценты и нормализуются до долей.

Сборка и тестирование (рабочие сценарии)
- Открыть в Xcode: двойной клик по `Remission.xcodeproj` и запуск схемы `Remission` в стандартном симуляторе.
- Сборка и тесты из терминала:

```bash
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' build
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e'
```

- Сборка проекта через SwiftPM не поддерживается (проект не оформлен как Swift Package); используйте Xcode или `xcodebuild`.

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

Особенности и соглашения проекта
- Приложение использует модульную структуру поверх SwiftUI `struct`. Старайтесь выносить повторно используемые компоненты в отдельные `View` в `Remission/Views/`, чтобы поддерживать читаемость.
- Превью и быстрая итерация: используйте SwiftUI Preview (Preview area) в каждой View для локальной проверки визуальных изменений.
- Тесты используют Swift Testing фреймворк с атрибутом `@Test`. Добавляйте тесты в том же стиле.
- **Модульная структура проекта:**
  - `Remission/Features/` — TCA Reducers для feature-модулей (Onboarding, ServerList, ServerDetail, ServerEditor)
  - `Remission/Views/` — SwiftUI View компоненты, разделённые по фичам
  - `Remission/Domain/` — доменные модели и маппинг из RPC (Torrent, ServerConfig, SessionState)
  - `Remission/DependencyClients/` — определения dependency clients (протоколы и placeholder реализации)
  - `Remission/DependencyClientLive/` — live-реализации зависимостей для production
  - `Remission/Shared/` — общие утилиты и переиспользуемые компоненты
  - Репозитории и сервисы размещаются в корне `Remission/` (напр., `TorrentRepository.swift`, `TransmissionClient.swift`)

Быстрый старт (First-Time Setup)
- **Установить инструменты:**
  - swift-format 602.0.0+: входит в состав Xcode 15.0+, или установить отдельно через Homebrew
  - SwiftLint 0.61.0+: `brew install swiftlint`

- **Установить pre-commit hook для автоматических проверок:**
  ```bash
  bash Scripts/prepare-hooks.sh
  ```

- **Проверить, что hook работает:**
  ```bash
  git commit --allow-empty -m "Test commit"
  ```
  Вывод должен показать, что swift-format и swiftlint пройдены ✅

Конкретные примеры
- Поменять стартовый экран: редактируйте `Remission/RemissionApp.swift` — сейчас в `WindowGroup` возвращается `AppView(store: store)`.
- Добавить новый feature-модуль:
  1. Создайте Reducer в `Remission/Features/MyFeature/MyFeatureReducer.swift`
  2. Создайте View в `Remission/Views/MyFeature/MyFeatureView.swift`
  3. Добавьте тесты в `RemissionTests/MyFeatureTests.swift`
- Добавить новую View-компоненту: создайте `Remission/Views/Shared/MyComponent.swift` для переиспользуемых элементов.
- Добавить unit-тест: создайте файл в `RemissionTests/` с атрибутом `@Test` и следуйте примерам в существующих тестах.

- Интеграции и внешние зависимости
- Внешние зависимости подключаются через Swift Package Manager. При добавлении новых пакетов фиксируйте изменения в PR и отражайте обновлённую структуру в `devdoc/plan.md`. Для крупных модулей рассматривайте вынос в локальные Swift Packages (`Features/TorrentList`, `Services/TransmissionClient`, `Shared/Models`).

- Библиотека TCA: добавьте зависимость `https://github.com/pointfreeco/swift-composable-architecture` через SPM и используйте её как стандарт для state-management. Все feature-модули должны реализовываться как TCA reducers с @ObservableState, Action enum и Reducer body.

- Swift 6 toolchain: если необходим preview toolchain, добавьте шаг в CI для установки требуемого toolchain.

## Фабрики и динамические зависимости per-context

При работе с несколькими контекстами (например, несколько серверов Transmission с разными клиентами) создавайте **фабрики** через `DependencyKey`:

### Когда использовать фабрики:
- Нужно создать multiple экземпляры сервиса с разными конфигурациями
- Сервис зависит от других dependencies (CredentialsRepository, Clock, Mapper, etc.)
- Нужно кэшировать состояние окружения на уровне Feature (не глобально)

### Пример: ServerConnectionEnvironmentFactory (RTC-67)

```swift
struct ServerConnectionEnvironmentFactory: Sendable {
    var make: @Sendable (_ server: ServerConfig) async throws -> ServerConnectionEnvironment

    func callAsFunction(_ server: ServerConfig) async throws -> ServerConnectionEnvironment {
        try await make(server)
    }
}

extension ServerConnectionEnvironmentFactory: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.credentialsRepository) var credentialsRepository
        @Dependency(\.appClock) var appClock
        @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter

        return Self { server in
            // Загрузить пароль из Keychain
            let password = try await credentialsRepository.load(key: server.credentialsKey)

            // Создать client специфичный для этого сервера
            let config = server.makeTransmissionClientConfig(
                password: password,
                network: .default,
                logger: DefaultTransmissionLogger()
            )
            let client = TransmissionClient(config: config, clock: appClock.clock())
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())

            // Вернуть окружение с изолированными зависимостями
            return ServerConnectionEnvironment(
                serverID: server.id,
                fingerprint: server.connectionFingerprint,
                dependencies: .init(
                    transmissionClient: TransmissionClientDependency.live(client: client),
                    torrentRepository: .placeholder,
                    sessionRepository: .placeholder
                )
            )
        }
    }

    static var previewValue: Self {
        Self { server in
            ServerConnectionEnvironment.preview(server: server)
        }
    }

    static var testValue: Self {
        Self { _ in
            throw ServerConnectionEnvironmentFactoryError.notConfigured("testValue")
        }
    }
}

extension DependencyValues {
    var serverConnectionEnvironmentFactory: ServerConnectionEnvironmentFactory {
        get { self[ServerConnectionEnvironmentFactory.self] }
        set { self[ServerConnectionEnvironmentFactory.self] = newValue }
    }
}
```

### Использование в reducer'е:
```swift
@Reducer
struct ServerDetailReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        var connectionEnvironment: ServerConnectionEnvironment?
        var connectionState: ConnectionState = .init()
    }

    @Dependency(\.serverConnectionEnvironmentFactory) var factory

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            case .task:
                return startConnectionIfNeeded(state: &state)
            // ... остальные cases
        }
    }

    private func connect(server: ServerConfig) -> Effect<Action> {
        .run { send in
            await send(
                .connectionResponse(
                    TaskResult {
                        let environment = try await factory.make(server)
                        let handshake = try await environment.dependencies.transmissionClient.performHandshake()
                        return ConnectionResponse(environment: environment, handshake: handshake)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true)
    }
}
```

### Тестирование фабрик с TestStore:
```swift
@Test
func serverConnectionSuccess() async {
    let server = ServerConfig.previewLocalHTTP
    let mockEnv = ServerConnectionEnvironment.testEnvironment(server: server)

    let store = TestStore(
        initialState: ServerDetailReducer.State(server: server)
    ) {
        ServerDetailReducer()
    } withDependencies: { dependencies in
        dependencies = AppDependencies.makeTestDefaults()
        dependencies.serverConnectionEnvironmentFactory = .mock(environment: mockEnv)
    }

    await store.send(.task) {
        $0.connectionState.phase = .connecting
    }

    await store.receive(.connectionResponse(.success(...))) {
        $0.connectionEnvironment = mockEnv
        $0.connectionState.phase = .ready(...)
    }
}
```

**Справочные файлы:**
- `Remission/ServerConnectionEnvironment.swift` — полная реализация фабрики (RTC-67)
- `RemissionTests/ServerDetailFeatureTests.swift` — примеры тестирования
- `devdoc/FACTORY_PATTERNS.md` — полная справка по паттернам фабрик

## Важно про Transmission RPC

- **Собственный формат** (не JSON-RPC 2.0): используются `method`, `arguments`, `tag` в запросе; ответ содержит `result: "success"` или строку-ошибку
- **HTTP 409 handshake**: обязателен при первом подключении для получения `X-Transmission-Session-Id`
- **Basic Auth + Session ID**: оба обязательны в заголовках
- **Версионирование**: поддержка минимум Transmission 3.0+ (рекомендуется 4.0+)
- **Безопасность**: НИКОГДА не логировать пароли, session-id или чувствительные данные
- **Справочник**: `devdoc/TRANSMISSION_RPC_REFERENCE.md` и `devdoc/TRANSMISSION_RPC_METHOD_MATRIX.md`

- Рекомендации для AI-агентов при правках:
- Делайте маленькие атомарные коммиты — одна логическая правка (вью, редьюсер, тест).
- Используйте TCA для всех feature-модулей: State/Action/Environment/Reducer/View. Effects (сетевая логика) инкапсулируйте в Environment.
- Архитектура: разделение слоёв — UI (View) / Presentation (Reducer/ViewStore) / Domain/Services (Repositories, TransmissionClient) / Persistence (Keychain/CoreData).
- Не смешивать frontend-логику и backend-логику в одном файле или модуле. Сеть и persistence должны быть в `Services`/`Repositories`.
- Не перестраивайте структуру проекта без запроса — сохраняйте простую точку входа приложения. Если требуется рефакторинг — опишите мотивацию в сообщении коммита и создайте отдельный PR.
- При добавлении тестов следуйте использованию `Testing` и `@Test`; добавляйте unit-тесты для редьюсеров и эффектов.

## CI и форматирование
- В CI требуется запускать сборку под Swift 6, `swift-format` и `swiftlint`. Форматирование и линтинг должны проходить в pre-commit или как обязательный шаг в CI.
- **swift-format** (Apple) интегрирован в pre-commit hook. Локально запустите `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests` для проверки. Для применения исправлений: `swift-format format --in-place --configuration .swift-format --recursive Remission RemissionTests RemissionUITests`. Конфигурация в `.swift-format` (JSON).
- **SwiftLint** интегрирован в Xcode build phase и запускается автоматически при сборке. Локально запустите `swiftlint lint` для проверки. Конфигурация в `.swiftlint.yml` (см. документ `devdoc/SWIFTLINT.md`).
- **Pre-commit hooks**: используйте `bash Scripts/prepare-hooks.sh` для установки автоматических проверок перед коммитом. Hook запускает swift-format lint --strict и SwiftLint и блокирует коммит при ошибках. См. `CONTRIBUTING.md` для полной информации.

Политика коммитов
- Все сообщения коммитов должны быть строго на русском языке. Это касается как короткой строки (summary), так и, при необходимости, описания (body). Примеры:
    - Правильно: `Добавить поддержку добавления magnet-ссылок` или `Реализовать TorrentList редьюсер`
    - Неправильно: `Add magnet support` или `Implement TorrentList reducer`

Если что-то непонятно
- Спросите владельца репозитория о таргете (iOS или macOS), устройстве/симуляторе для тестов и о допустимости добавления Swift Package зависимостей.

## Environment & Requirements

- **Xcode:** 15.0 или выше
- **Swift:** 6.0+
- **iOS deployment target:** 26.0+
- **macOS deployment target:** 26.0+
- **visionOS deployment target:** 26.0+
- **Обязательные инструменты:** swift-format 602.0.0+, SwiftLint 0.61.0+

Конец файла
