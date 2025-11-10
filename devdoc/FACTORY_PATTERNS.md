# Фабрики и per-context окружения в Remission

**Документ**: FACTORY_PATTERNS.md  
**Версия**: 1.0 (RTC-67 reference)  
**Цель**: подробное руководство по созданию и использованию factory pattern через DependencyKey в TCA.

## Содержание

1. [Введение](#введение)
2. [Когда использовать](#когда-использовать)
3. [Архитектура решения](#архитектура-решения)
4. [Полный пример: ServerConnectionEnvironmentFactory](#полный-пример-serverconnectionenvironmentfactory)
5. [Паттерны тестирования](#паттерны-тестирования)
6. [Чек-лист для новых фабрик](#чек-лист-для-новых-фабрик)
7. [Типичные ошибки](#типичные-ошибки)

## Введение

Фабрика в контексте Remission — это объект типа `Sendable struct` или `class`, который реализует `DependencyKey` и создаёт **per-context сервисы** с управляемыми зависимостями и жизненным циклом.

**Примеры per-context сценариев**:
- Per-server Transmission клиент (RTC-67): каждый сохранённый сервер имеет свой `TransmissionClient`, session-id, кеш состояния
- Per-workspace окружение (будущее расширение): разные рабочие пространства могут иметь разные settings, кеши, фильтры
- Per-user сессия (многопользовательский режим): разные учётные записи с разными permissions и данными

## Когда использовать

✅ **Используйте фабрику, если**:
- Нужно создавать **multiple экземпляры** сервиса с разными конфигурациями
- Сервис инициализируется **асинхронно** (например, загрузка credentials или handshake)
- Сервис **зависит от других DependencyKey** (CredentialsRepository, Clock, Logger и др.)
- Требуется **изолировать состояние** между контекстами (session-id, кеш, connections)
- Нужно **управлять жизненным циклом** окружения (инициализация, cleanup, cancellation)

❌ **Не используйте фабрику, если**:
- Нужен **глобальный синглтон** (например, LoggingClient) — используйте простой DependencyKey
- Сервис **не требует асинхронной инициализации** — используйте обычный init с параметрами
- **Нет необходимости в изоляции** состояния между экземплярами — используйте обычный DependencyKey

## Архитектура решения

### Шаг 1: Определить Environment структуру

```swift
// Remission/ServerConnectionEnvironment.swift

/// Изолированное окружение для одного Transmission сервера
struct ServerConnectionEnvironment: Sendable {
    let serverID: UUID
    let fingerprint: String
    let dependencies: EnvironmentDependencies
    
    struct EnvironmentDependencies: Sendable {
        var transmissionClient: TransmissionClientDependency
        var torrentRepository: TorrentRepositoryDependency
        var sessionRepository: SessionRepositoryDependency
    }
    
    // Превью и тестовые конфигурации
    static func preview(server: ServerConfig) -> Self {
        let client = TransmissionClientDependency.preview
        return Self(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: client,
                torrentRepository: .preview,
                sessionRepository: .preview
            )
        )
    }
    
    static func testEnvironment(
        server: ServerConfig,
        handshake: TransmissionHandshakeResult
    ) -> Self {
        // Тестовое окружение с mock-данными
        ...
    }
}
```

### Шаг 2: Определить фабрику

```swift
// Remission/ServerConnectionEnvironmentFactory.swift

struct ServerConnectionEnvironmentFactory: Sendable {
    /// Асинхронная функция для создания окружения
    var make: @Sendable (_ server: ServerConfig) async throws -> ServerConnectionEnvironment
    
    /// Вспомогательный метод для удобства
    func callAsFunction(_ server: ServerConfig) async throws -> ServerConnectionEnvironment {
        try await make(server)
    }
}

// MARK: - DependencyKey реализация

extension ServerConnectionEnvironmentFactory: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.credentialsRepository) var credentialsRepository
        @Dependency(\.appClock) var appClock
        @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter

        return Self { server in
            // 1. Загрузить пароль из Keychain
            let password = try await credentialsRepository.load(key: server.credentialsKey)

            // 2. Создать конфигурацию для TransmissionClient
            let config = server.makeTransmissionClientConfig(
                password: password,
                network: .default,
                logger: DefaultTransmissionLogger()
            )
            
            // 3. Инициализировать клиент со своими часами
            let client = TransmissionClient(config: config, clock: appClock.clock())
            
            // 4. Подключить обработчик для SSL/TLS диалогов
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())

            // 5. Выполнить handshake и получить session-id
            let handshake = try await client.performHandshake()

            // 6. Вернуть полностью инициализированное окружение
            return ServerConnectionEnvironment(
                serverID: server.id,
                fingerprint: server.connectionFingerprint,
                dependencies: .init(
                    transmissionClient: .live(client: client),
                    torrentRepository: .live(client: client),
                    sessionRepository: .live(client: client)
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

// MARK: - DependencyValues extension

extension DependencyValues {
    var serverConnectionEnvironmentFactory: ServerConnectionEnvironmentFactory {
        get { self[ServerConnectionEnvironmentFactory.self] }
        set { self[ServerConnectionEnvironmentFactory.self] = newValue }
    }
}

// MARK: - Ошибки

enum ServerConnectionEnvironmentFactoryError: LocalizedError {
    case missingCredentials
    case handshakeFailed(APIError)
    case notConfigured(String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Учётные данные не найдены для этого сервера"
        case .handshakeFailed(let error):
            return "Ошибка подключения: \(error.localizedDescription)"
        case .notConfigured(let message):
            return "Factory не настроена: \(message)"
        }
    }
}
```

### Шаг 3: Использовать в Reducer

```swift
// Remission/Features/ServerDetail/ServerDetailFeature.swift

@Reducer
struct ServerDetailReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        var connectionEnvironment: ServerConnectionEnvironment?
        var connectionState: ConnectionState = .init()
    }

    enum Action {
        case task
        case connectionResponse(TaskResult<ConnectionResponse>)
        case retryConnectionButtonTapped
    }
    
    struct ConnectionResponse: Equatable {
        let environment: ServerConnectionEnvironment
        let handshake: TransmissionHandshakeResult
    }
    
    @Dependency(\.serverConnectionEnvironmentFactory) var factory
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return startConnectionIfNeeded(state: &state)
                
            case .connectionResponse(.success(let response)):
                state.connectionEnvironment = response.environment
                state.connectionState.phase = .ready(
                    .init(fingerprint: response.environment.fingerprint, handshake: response.handshake)
                )
                return .none
                
            case .connectionResponse(.failure(let error)):
                state.connectionEnvironment = nil
                state.connectionState.phase = .failed(.init(message: error.localizedDescription ?? "Unknown error"))
                return .none
                
            case .retryConnectionButtonTapped:
                return startConnectionIfNeeded(state: &state)
            }
        }
    }
    
    private func startConnectionIfNeeded(state: inout State) -> Effect<Action> {
        guard state.connectionEnvironment == nil else { return .none }
        
        state.connectionState.phase = .connecting
        
        return .run { send in
            await send(
                .connectionResponse(
                    TaskResult {
                        let environment = try await factory.make(state.server)
                        let handshake = try await environment.dependencies.transmissionClient.performHandshake()
                        return ConnectionResponse(environment: environment, handshake: handshake)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true)
    }
}

// MARK: - ConnectionState (вспомогательная структура)

struct ConnectionState: Equatable {
    enum Phase: Equatable {
        case idle
        case connecting
        case ready(ReadyState)
        case failed(FailedState)
    }
    
    struct ReadyState: Equatable {
        let fingerprint: String
        let handshake: TransmissionHandshakeResult
    }
    
    struct FailedState: Equatable {
        let message: String
    }
    
    var phase: Phase = .idle
}

enum ConnectionCancellationID {
    case connection
}
```

## Паттерны тестирования

### Тест 1: Happy path (успешное подключение)

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
        dependencies = AppDependencies.makeTestDefaults()
        dependencies.serverConnectionEnvironmentFactory = .init { _ in environment }
    }

    await store.send(.task) {
        $0.connectionState.phase = .connecting
    }

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
```

### Тест 2: Error path (ошибка подключения)

```swift
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
        dependencies.serverConnectionEnvironmentFactory = .init { _ in
            throw expectedError
        }
    }

    await store.send(.task) {
        $0.connectionState.phase = .connecting
    }

    await store.receive(.connectionResponse(.failure(expectedError))) {
        $0.connectionEnvironment = nil
        $0.connectionState.phase = .failed(.init(message: expectedError.errorDescription ?? ""))
    }
}
```

### Тест 3: Retry после ошибки

```swift
@Test
func serverConnectionRetryAfterFailure() async {
    let server = ServerConfig.previewLocalHTTP
    let successEnvironment = ServerConnectionEnvironment.testEnvironment(server: server)
    var attemptCount = 0
    
    let store = TestStore(
        initialState: ServerDetailReducer.State(server: server)
    ) {
        ServerDetailReducer()
    } withDependencies: { dependencies in
        dependencies = AppDependencies.makeTestDefaults()
        dependencies.serverConnectionEnvironmentFactory = .init { _ in
            attemptCount += 1
            if attemptCount == 1 {
                throw ServerConnectionEnvironmentFactoryError.handshakeFailed(.unknown("Network timeout"))
            }
            return successEnvironment
        }
    }

    // Первая попытка: ошибка
    await store.send(.task) {
        $0.connectionState.phase = .connecting
    }

    await store.receive(.connectionResponse(.failure(APIError.unknown("Network timeout")))) {
        $0.connectionEnvironment = nil
        $0.connectionState.phase = .failed(...)
    }

    // Retry: успех
    await store.send(.retryConnectionButtonTapped) {
        $0.connectionState.phase = .connecting
    }

    await store.receive(.connectionResponse(.success(...))) {
        $0.connectionEnvironment = successEnvironment
        $0.connectionState.phase = .ready(...)
    }
}
```

## Чек-лист для новых фабрик

При создании новой фабрики следуйте этому чек-листу:

- [ ] **1. Определить Environment структуру**
  - [ ] Структура реализует `Sendable`
  - [ ] Содержит все необходимые зависимости для контекста
  - [ ] Включает `.preview` и `.testEnvironment` статические методы
  - [ ] Задокументированы ключевые поля

- [ ] **2. Создать Factory struct**
  - [ ] Реализует `Sendable`
  - [ ] Имеет `var make: @Sendable (_ input) async throws -> Environment`
  - [ ] Реализует `DependencyKey` с `liveValue`, `previewValue`, `testValue`
  - [ ] Содержит `callAsFunction` для удобного вызова

- [ ] **3. Определить Error enum**
  - [ ] Реализует `LocalizedError`
  - [ ] Содержит все возможные ошибки инициализации
  - [ ] Имеет `errorDescription` для UI-отображения

- [ ] **4. Расширить DependencyValues**
  - [ ] Добавить getter/setter для factory
  - [ ] Зарегистрировать в `AppDependencies.swift`

- [ ] **5. Использовать в Reducer**
  - [ ] Получить фабрику через `@Dependency(\.factory)`
  - [ ] Вызвать `factory.make(...)` в effect
  - [ ] Обработать success/failure path в `connectionResponse` action
  - [ ] Добавить cancellation с `id` для cleanup

- [ ] **6. Добавить тесты**
  - [ ] Happy path тест с mock-средой
  - [ ] Error path тест с ошибкой от factory
  - [ ] Retry тест (если применимо)
  - [ ] Cleanup тест (если требуется)

- [ ] **7. Обновить документацию**
  - [ ] Описать когда использовать фабрику
  - [ ] Добавить ссылку в `devdoc/plan.md`
  - [ ] Добавить пример в `AGENTS.md` (если новый паттерн)
  - [ ] Обновить `Project Layout` раздел в `AGENTS.md` о размещении файла

- [ ] **8. Форматирование и тестирование**
  - [ ] Запустить `swift-format` и `swiftlint`
  - [ ] Пройти `xcodebuild test`
  - [ ] Убедиться в 100% прохождении новых тестов
  - [ ] Покрытие новых файлов >= 60%

## Типичные ошибки

### Ошибка 1: Синхронная инициализация в лiveValue

❌ **НЕПРАВИЛЬНО**:
```swift
static var liveValue: Self {
    @Dependency(\.credentialsRepository) var credentialsRepository
    
    // ❌ Синхронный вызов async функции
    let password = credentialsRepository.load(key: "key") // CRASH!
    
    return Self { server in
        // ...
    }
}
```

✅ **ПРАВИЛЬНО**:
```swift
static var liveValue: Self {
    @Dependency(\.credentialsRepository) var credentialsRepository
    
    return Self { server in
        // ✅ Async операции внутри async блока factory
        let password = try await credentialsRepository.load(key: server.credentialsKey)
        // ...
    }
}
```

### Ошибка 2: Забыли `Sendable` на Factory

❌ **НЕПРАВИЛЬНО**:
```swift
struct ServerConnectionEnvironmentFactory { // ❌ Не Sendable!
    var make: @Sendable (_ server: ServerConfig) async throws -> ServerConnectionEnvironment
}
```

✅ **ПРАВИЛЬНО**:
```swift
struct ServerConnectionEnvironmentFactory: Sendable {
    var make: @Sendable (_ server: ServerConfig) async throws -> ServerConnectionEnvironment
}
```

### Ошибка 3: Не переопределили factory в TestStore

❌ **НЕПРАВИЛЬНО**:
```swift
let store = TestStore(initialState: ...) {
    ServerDetailReducer()
} withDependencies: { dependencies in
    // ❌ Забыли переопределить factory — будет использован testValue (не настроена!)
    // dependencies.serverConnectionEnvironmentFactory = ...
}
```

✅ **ПРАВИЛЬНО**:
```swift
let store = TestStore(initialState: ...) {
    ServerDetailReducer()
} withDependencies: { dependencies in
    dependencies = AppDependencies.makeTestDefaults()
    // ✅ Явно мокируем factory
    dependencies.serverConnectionEnvironmentFactory = .init { _ in mockEnv }
}
```

### Ошибка 4: State mutations вне Reduce блока

❌ **НЕПРАВИЛЬНО**:
```swift
var body: some Reducer<State, Action> {
    Reduce { state, action in
        case .task:
            state.connectionEnvironment = nil // ❌ mutation перед effect!
            return .run { send in ... }
    }
}
```

✅ **ПРАВИЛЬНО**:
```swift
var body: some Reducer<State, Action> {
    Reduce { state, action in
        case .task:
            state.connectionState.phase = .connecting // ✅ только начальное состояние
            return .run { send in ... }
                .cancellable(id: ConnectionCancellationID.connection)
    }
}
```

### Ошибка 5: Забыли cleanup (cancellation)

❌ **НЕПРАВИЛЬНО**:
```swift
return .run { send in
    // ❌ Без cancellation — effect продолжит работать после выхода со страницы!
    await send(.connectionResponse(...))
}
```

✅ **ПРАВИЛЬНО**:
```swift
return .run { send in
    await send(.connectionResponse(...))
}
.cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true) // ✅ cleanup
```

## Ссылки

- **RTC-67**: ServerConnectionEnvironmentFactory implementation
- **devdoc/plan.md**: "Фабрики и динамические per-context зависимости"
- **AGENTS.md**: Project Layout rules для фабрик
- **TCA Documentation**: https://github.com/pointfreeco/swift-composable-architecture
- **Swift Concurrency Best Practices**: https://developer.apple.com/videos/play/wwdc2022/110350/
