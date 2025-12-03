# План внедрения Remission

**Быстрые ссылки на документацию**:
- 📚 [CONTEXT7_GUIDE.md](CONTEXT7_GUIDE.md) — Как исследовать документацию через Context7
- 📖 [TRANSMISSION_RPC_REFERENCE.md](TRANSMISSION_RPC_REFERENCE.md) — Справочник по Transmission RPC API
 - 📑 [TRANSMISSION_RPC_METHOD_MATRIX.md](TRANSMISSION_RPC_METHOD_MATRIX.md) — Матрица методов/полей для MVP
- 🪵 [LOGGING_GUIDE.md](LOGGING_GUIDE.md) — Логи, диагностика, безопасность и телеметрия
- 🧱 [SwiftUI + TCA Template](https://github.com/ethanhuang13/swiftui-tca-template) — Рекомендованная модульная структура (Models/Features/Views/Dependencies)
- 📦 [TCA Documentation](https://github.com/pointfreeco/swift-composable-architecture/tree/main/Sources/ComposableArchitecture/Documentation.docc) — Best practices по декомпозиции редьюсеров и навигации

## Обязательный предстартовый workflow
Перед любым изменением кода выполняем последовательность:
1. **Чтение требований** — освежить контекст в [PRD.md](PRD.md) и текущей секции этого плана.
2. **Архитектурный чек** — свериться с актуальными решениями в `devdoc/plan.md` и разделами про TCA/модульность.
3. **Context7-исследование** — по всем новым паттернам/библиотекам вызвать `resolve-library-id` → `get-library-docs` (см. [CONTEXT7_GUIDE.md](CONTEXT7_GUIDE.md)) и зафиксировать ссылки в задачах/документации.
4. **Чек-лист модульности** — убедиться, что работа вписывается в схему `Models` → `Features` → `Views` → `DependencyClients` (см. SwiftUI+TCA Template) и не смешивает UI, бизнес-логику и инфраструктуру.
5. **Только после этого** — переход к дизайну и реализации. Любое отступление документируем в комментариях к задаче.

## Требования ко всем этапам
- **Context7 критический чек-лист**: перед добавлением любой зависимости, конфигурацией инструмента или использованием новых версий обратитесь в Context7 для актуальной документации. Используйте `mcp_context7_resolve-library-id` и `mcp_context7_get-library-docs` для получения последней информации. **Прочитайте [CONTEXT7_GUIDE.md](CONTEXT7_GUIDE.md) для подробного workflow!**
- **Фреймворк тестирования**: Swift Testing (встроенный модуль) с атрибутом `@Test`, а не XCTest. Минимум покрытия: happy path + error path для каждого редьюсера.
- **Архитектура**: The Composable Architecture (TCA) для всего управления состоянием. @ObservableState, enum Action, @Reducer. Не смешивать TCA и MVVM.
- **Форматирование и стиль**: 
  - `swift-format format --in-place --recursive --configuration .swift-format` для форматирования
  - `swift-format lint --configuration .swift-format --recursive --strict` для проверки
  - `swiftlint lint` для стиля кода (встроено в Xcode build phase)
- **Безопасность**: все credentials хранятся в Keychain, никогда не логируются пароли; поддержка как HTTP (по умолчанию для локальных серверов), так и HTTPS (опционально, с явным выбором и предупреждениями). См. [PRD.md](PRD.md) раздел "HTTP vs HTTPS политика".
- **CI статус**: автоматический CI пайплайн временно отключён (один разработчик, нет экономического смысла держать раннеры). Все проверки выполняем локально перед push: форматирование, линт, `xcodebuild test`.

## TransmissionClient — ручной тест-план

1. **Локальный прогон** — запустить Swift Testing свитки (TransmissionClientMethods/HappyPath/ErrorScenarios/Infrastructure) и UI smoke `RemissionUITests`:
   ```bash
   xcodebuild test \
     -scheme Remission \
     -sdk iphonesimulator \
     -destination 'platform=iOS Simulator,name=iPhone 16e' \
     -resultBundlePath build/TestResults/Remission.xcresult \
     -enableCodeCoverage YES
   ```
   Все свитки используют мок-инфраструктуру из RTC-14 (`TransmissionMockServer`, URLProtocol) и проверяют happy path + error path для handshake, torrent-команд и повторов.

2. **Покрытие кода** — анализируем отчёт через `xccov`. Порог: ≥ 60% по проекту, TransmissionClient.swift должен фигурировать в отчёте.
   ```bash
   xcrun xccov view --report build/TestResults/Remission.xcresult
   xcrun xccov view --report --json build/TestResults/Remission.xcresult > build/TestResults/coverage.json
   ```
   Последний прогон (27.10.2025) дал **77.8%** суммарного покрытия.

3. **Документация/ссылки** — актуальные рекомендации по Swift Testing и TCA TestStore:
   - Swift Testing best practices: <https://developer.apple.com/documentation/testing>
   - TCA Testing guide: <https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TestingTCA.md>

4. **Результаты** — при завершении задачи публикуем в Linear итоговую команду запуска, путь к `.xcresult` и выдержку из `xccov` с процентажем.

### Swift Clocks для детерминированного управления временем (RTC-44)

**Контекст**: TransmissionClient использует retry-логику с exponential backoff через `Task.sleep`. Для детерминированного тестирования без реальных задержек используется library `swift-clocks` (v1.0.6+).

**Архитектура решения**:
- **Зависимость**: `swift-clocks` добавлена в проект через SPM (версия 1.0.6)
- **Injection**: TransmissionClient инициализируется с параметром `clock: any Clock<Duration>`, по умолчанию `ContinuousClock()`
- **Testing**: Тесты инъецируют `TestClock()` для детерминированного управления временем через `await clock.advance(by:)` и `await clock.run()`

**Использование в production**:
```swift
// Live режим — использует системные часы (ContinuousClock)
let client = TransmissionClient(config: config, session: session)
```

**Использование в тестах**:
```swift
// Test режим — полный контроль над временем
#if canImport(Clocks)
    let testClock = TestClock()
    let client = TransmissionClient(config: config, session: session, clock: testClock)
#endif

// В тесте: управляем временем явно
try await client.torrentGet() // retry без реальной задержки
await testClock.advance(by: .milliseconds(2))
```

**Преимущества**:
- ✅ Тесты выполняются мгновенно (нет реальных задержек)
- ✅ Полный контроль над timing — можно тестировать exponential backoff
- ✅ Детерминированные результаты (no flaky tests из-за timing)
- ✅ Соответствует Swift Concurrency best practices

**Справочные материалы**:
- Swift Clocks documentation: https://github.com/pointfreeco/swift-clocks/blob/main/README.md
- Clock protocol: Built-in Swift 5.9+ в Foundation
- TestClock API: методы `advance(by:)`, `advance(to:)`, `run(timeout:)`

**Обновлённые файлы**:
- `Remission/TransmissionClient.swift` — добавлен параметр `clock` в инициализатор
- `Remission/TransmissionClient.swift` (retry logic) — заменено `Task.sleep(nanoseconds:)` на `clock.sleep(for: .seconds(...))`
- `Remission/DependencyClients/AppClockDependency.swift` — универсальный dependency client (RTC-57)
- `RemissionTests/*.swift` — все тесты обновлены на использование TestClock()

### Фабрики и динамические per-context зависимости (RTC-67)

**Контекст**: когда приложению требуется создавать несколько независимых контекстов (например, per-server TransmissionClient, per-workspace environment, per-user session), используется паттерн **Factory через DependencyKey**. Это обеспечивает изоляцию состояния, параллелизм и чистоту ресурсов.

**Когда использовать фабрики:**
- Нужно создать multiple экземпляры сервиса с разными конфигурациями
- Сервис зависит от других dependencies (CredentialsRepository, Clock, Mapper и др.)
- Нужно кэшировать состояние окружения на уровне Feature (не глобально)
- Требуется асинхронная инициализация (загрузка credentials, handshake, проверка версии)

**Примеры**: `ServerConnectionEnvironmentFactory` для per-server Transmission клиентов (RTC-67).

**Архитектура решения**:

```swift
// 1. Определить фабрику как DependencyKey
struct ServerConnectionEnvironmentFactory: Sendable {
    var make: @Sendable (_ server: ServerConfig) async throws -> ServerConnectionEnvironment
    
    func callAsFunction(_ server: ServerConfig) async throws -> ServerConnectionEnvironment {
        try await make(server)
    }
}

// 2. Реализовать liveValue (production), previewValue, testValue
extension ServerConnectionEnvironmentFactory: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.credentialsRepository) var credentialsRepository
        @Dependency(\.appClock) var appClock
        
        return Self { server in
            let password = try await credentialsRepository.load(key: server.credentialsKey)
            let config = server.makeTransmissionClientConfig(password: password, ...)
            let client = TransmissionClient(config: config, clock: appClock.clock())
            // ... инициализировать все зависимости окружения
            return ServerConnectionEnvironment(serverID: server.id, dependencies: ...)
        }
    }
    
    static var previewValue: Self {
        Self { server in ServerConnectionEnvironment.preview(server: server) }
    }
    
    static var testValue: Self {
        Self { _ in throw ServerConnectionEnvironmentFactoryError.notConfigured }
    }
}

// 3. Зарегистрировать в DependencyValues
extension DependencyValues {
    var serverConnectionEnvironmentFactory: ServerConnectionEnvironmentFactory {
        get { self[ServerConnectionEnvironmentFactory.self] }
        set { self[ServerConnectionEnvironmentFactory.self] = newValue }
    }
}

// 4. Использовать в reducer через @Dependency
@Reducer
struct ServerDetailReducer {
    @Dependency(\.serverConnectionEnvironmentFactory) var factory
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            case .task:
                return .run { send in
                    do {
                        let environment = try await factory.make(state.server)
                        await send(.connectionResponse(.success(environment)))
                    } catch {
                        await send(.connectionResponse(.failure(error)))
                    }
                }
                .cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true)
        }
    }
}

// 5. Тестирование: override через withDependencies
@Test
func serverConnectionSuccess() async {
    let mockEnv = ServerConnectionEnvironment.testEnvironment(server: .previewLocalHTTP)
    
    let store = TestStore(
        initialState: ServerDetailReducer.State(server: .previewLocalHTTP)
    ) {
        ServerDetailReducer()
    } withDependencies: { dependencies in
        dependencies.serverConnectionEnvironmentFactory = .init { _ in mockEnv }
    }
    
    await store.send(.task) { $0.connectionState.phase = .connecting }
    await store.receive(.connectionResponse(.success(mockEnv))) { ... }
}
```

**Преимущества паттерна**:
- ✅ **Изоляция**: каждый контекст (сервер) имеет независимые credentials, session-id, кеш
- ✅ **Тестируемость**: фабрика мокируется через `.mock()` без реальной инициализации
- ✅ **Параллелизм**: допускается работа с несколькими контекстами одновременно
- ✅ **Ленивая инициализация**: окружение создаётся только при запросе, не при старте приложения
- ✅ **Композируемость**: фабрика может использовать другие зависимости через `@Dependency`

**Файлы реализации**:
- `Remission/ServerConnectionEnvironment.swift` — Environment структура и factory (RTC-67)
- `Remission/ServerDetailFeature.swift` — Reducer используя factory
- `RemissionTests/ServerDetailFeatureTests.swift` — TestStore примеры с factory mocking

**Документирование фабрик при добавлении новых**: 
- Всегда включайте `.previewValue` и `.testValue`
- Документируйте возможные ошибки и их обработку
- Добавляйте примеры использования в TestStore примеры
- Обновляйте раздел Project Layout в AGENTS.md с правилами размещения

### Политика кеширования офлайн-данных (RTC-115)
- **Ключи**: кеш изолируется per-server по UUID + fingerprint соединения (host/port/username/transport) + fingerprint учётных данных (SHA-256 от `accountIdentifier:password` без хранения пароля). RPC-версия добавляется после успешного handshake.
- **TTL**: 30 минут для всех снапшотов (торренты, сессия). Просроченный кеш удаляется при чтении.
- **Размер**: не более 5 МБ на сервер (JSON-слепок в Application Support/Remission/Snapshots). При превышении лимита кеш очищается и не используется.
- **Инвалидация**: при смене учётных данных, отличающейся RPC-версии, удалении сервера, ошибке несовместимой версии Transmission или ошибке чтения/записи кеш сбрасывается.
- **Использование**: кеш читается при старте/офлайне, обновляется после успешных `torrent-get`/`session-get`, очищается при удалении сервера и при ошибке несовместимости версии. PRD синхронизирован.

### Модульность и декомпозиция TCA
- **Разделение слоёв**: UI (`Views`), бизнес-логика (`Features`/редьюсеры), модели (`Models`) и инфраструктура (`DependencyClients`) оформляются отдельными таргетами/файлами. Ссылайтесь на [SwiftUI+TCA Template](https://github.com/ethanhuang13/swiftui-tca-template) как эталон.
- **Структура зависимостей**: определения `@DependencyClient` и тестовых значений живут в `Remission/DependencyClients`, live-реализации и фабрики — в `Remission/DependencyClientLive`. Любые новые клиенты повторяют эту схему, чтобы тесты и прод-код использовали единый источник.
- **Бутстрап TransmissionClient**: корневой `Store` создаётся в `RemissionApp` и при инициализации подставляет `TransmissionClientDependency.live(client:)` через вспомогательную фабрику. Пока onboarding/Keychain не готов, фабрика возвращает временную конфигурацию `http://localhost:9091/transmission/rpc` (см. `TransmissionClientBootstrap`), а превью/тесты переопределяют зависимость на `.testValue`.
- **Компоновка редьюсеров**: долгие/многофункциональные редьюсеры делятся с помощью `Scope`, `.ifLet`, `Reducer.forEach`. Навигация оформляется через отдельные `Destination`/`Path` редьюсеры (см. [TCA TreeBasedNavigation](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TreeBasedNavigation.md)).
- **Dismiss для @Presents**: если `.ifLet` обрабатывает `PresentationAction`, добавляйте явное действие закрытия (например, `settingsDismissed`) и отправляйте его из дочернего редьюсера/делегата перед обнулением `state`. Это предотвращает предупреждения TCA о приходящих действиях при `nil` state.
- **Парсинг и инфраструктура**: вспомогательные парсеры и клиенты не размещаем в редьюсере. Выносите в отдельные структуры/сервисы (`TransmissionClient`, `TorrentDetailParser`) и инжектируйте через зависимости.
- **TorrentDetailParser (2025-11-02, RTC-53 follow-up)**: парсер формирует доменную модель `Torrent` (см. `Remission/Domain/Torrent.swift`) и возвращает её через dependency `@Dependency(\.torrentDetailParser)`. Начиная с RTC-54, все эффекты `TorrentDetailReducer` работают с доменными моделями напрямую — действие `.detailsLoaded` принимает `Torrent`, а ошибки парсинга конвертируются в `TorrentDetailParserError.mappingFailed(DomainMappingError)`. История скоростей по-прежнему обновляется в `State.apply(_:)`, тесты обновлены под новый контракт (`loadTorrentDetailsParserFailure`).
- **TransmissionDomainMapper (2025-11-03, RTC-54)**: добавлен централизованный маппер Transmission DTO → доменные модели (`Remission/Domain/TransmissionDomainMapper.swift`). Реализованы функции `mapTorrentList`, `mapTorrentDetails`, `mapSessionState`, `mapServerConfig`, покрытые happy/error-path тестами (`TransmissionDomainMapperTests`). Ошибки обобщены через `DomainMappingError` (missingField/invalidType/unsupportedStatus и др.) и переиспользуются парсером и фичами. Документация синхронизирована в `devdoc/TRANSMISSION_RPC_METHOD_MATRIX.md` с таблицей соответствия RPC полей доменным сущностям и стратегией совместимости версий. Допущение по полю `percentDone`: Transmission может вернуть долю (Double 0…1) или процент (Int 0…100); значения Int > 1 нормализуются делением на 100 — фиксируем это при интеграции новых версий RPC.
- **Доменный слой (2025-11-01, RTC-53)**: добавлен каталог `Remission/Domain` с базовыми моделями `Torrent`, `ServerConfig`, `SessionState`. `Torrent` содержит вложенные value-объекты для прогресса/скоростей/источников пиров, а также `Details` для файлов, трекеров и истории скоростей. `ServerConfig` теперь используется ServerList/ServerDetail редьюсерами, умеет собирать `TransmissionClientConfig` и предоставляет `credentialsKey` для Keychain. `SessionState` фиксирует объединённые данные `session-get`/`session-stats` — лимиты скоростей, очереди, throughput, lifetime stats. Для превью/тестов доступны статические фикстуры (`.previewDownloading`, `.previewLocalHTTP`, `.previewActive`). Документация синхронизирована в `devdoc/MODELS.md`.
- **UI-секции**: сложные SwiftUI-экраны разбиваем на под-компоненты (например, `Remission/Views/TorrentDetail/TorrentMainInfoView.swift`, `TorrentStatisticsView.swift`) и подключаем через `Views` модуль; основной `TorrentDetailView` выступает только как декларативный контейнер.
- **Документирование**: при добавлении новых шаблонов/паттернов обязательно обновляем этот раздел ссылками на источники из Context7.

## Веха 0: Подготовка окружения
- **Статус**: ✅ Закрыта (по состоянию на 2025-10-17)
- M0.1 Зафиксировать версии Xcode 15.0+ и Swift 6.0+, обновив раздел "Системные требования" в README и Environment & Requirements в документации.
- M0.2 Добавить конфигурации swift-format и swiftlint, согласованные с правилами команды. Команды:
  - Форматирование: `swift-format format --in-place --recursive --configuration .swift-format Remission RemissionTests RemissionUITests`
  - Проверка (lint): `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests`
  - SwiftLint: `swiftlint lint` (автоматически запускается в build phase)
- M0.3 Подключить swift-format и swiftlint к локальному hook pre-commit через `bash Scripts/prepare-hooks.sh`. Проверить, что hook работает с `git commit --allow-empty -m "Test"`.
- M0.4 Унифицировать build settings для всех целей (iOS, macOS, visionOS): Swift 6.0, Deployment Target 26.0, SUPPORTED_PLATFORMS, App Sandbox, Hardened Runtime.
- M0.5 Обновить AGENTS.md с разделом "Build Settings & Unified Configuration" и таблицей ключевых параметров.
- Проверка: выполнить `xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 12' build` и `xcodebuild -scheme Remission -sdk macosx build`. Оба должны завершиться с BUILD SUCCEEDED без новых предупреждений.

## Transmission RPC API контракт (исследование и спецификация)

**⚠️ Полная справка**: [`TRANSMISSION_RPC_REFERENCE.md`](TRANSMISSION_RPC_REFERENCE.md) содержит детальное описание всех методов, примеры, edge cases и integration patterns.

**Для исследования нового API используйте**: [`CONTEXT7_GUIDE.md`](CONTEXT7_GUIDE.md) (workflow, примеры, best practices).

### Актуальные источники документации
- **Официальная RPC спецификация GitHub** (AUTHORITATIVE): https://raw.githubusercontent.com/transmission/transmission/main/docs/rpc-spec.md — Определяет формат запросов/ответов, все методы, версионирование
- **Transmission GitHub Wiki**: https://github.com/transmission/transmission/wiki — Дополнительная информация, примеры CLI
- **Python transmission-rpc библиотека**: https://transmission-rpc.readthedocs.io (Trust Score 7.5) — Reference implementation для field names
- **Поддерживаемые версии Transmission**: 3.0+ (минимум), 4.0.6+ (рекомендуется). Проверка версии выполняется через `session-get` при рукопожатии.

### Основные RPC методы для MVP

Полная матрица методов, параметров и полей ответов перенесена в отдельный документ:

- См. файл: [TRANSMISSION_RPC_METHOD_MATRIX.md](TRANSMISSION_RPC_METHOD_MATRIX.md)

⚠️ **Основные методы для MVP**:
- `torrent-get` — получить список торрентов и их состояние (главный метод, используется часто)
- `torrent-add` — добавить торрент из файла или magnet-ссылки
- `torrent-start`, `torrent-stop`, `torrent-remove` — управление торрентами
- `session-get` — получить версию сервера и параметры сессии (используется при handshake)
- `session-set` — установить лимиты скоростей для сессии

⚠️ **Дополнительные методы для будущих фич**:
- `torrent-set` — установка приоритетов, лимитов для отдельных торрентов (версия 2.6+)
- `session-stats` — агрегированная статистика сессии (активные торренты, скорости). Версия 3.0+.
- `torrent-verify` — проверка целостности торрента (долгая операция, версия 3.1+)
- Оптимизация `torrent-get`: использовать параметр `ids` и выбирать только нужные `fields` для больших списков (>100 торрентов)

Детальное описание всех методов, параметров и edge cases — см. [TRANSMISSION_RPC_REFERENCE.md](TRANSMISSION_RPC_REFERENCE.md).

Ниже краткая ориентировочная сводка (high-level) основных методов MVP:

| Метод | Назначение | Параметры | Ответ | Примечания |
|-------|----------|----------|--------|-----------|
| `session-get` | Получить текущую сессию и версию | — | `rpc-version`, `rpc-version-semver`, `version` | Вызывается при handshake для проверки версии (минимум 3.0) |
| `session-set` | Задать параметры сессии | `speed-limit-up`, `speed-limit-down`, `speed-limit-up-enabled`, etc. | — | Используется для лимитов скоростей |
| `torrent-get` | Получить информацию о торрентах | `ids` (опционально), `fields` (массив нужных полей) | Массив торрентов с запрашиваемыми полями | Основной метод. Поля: `id`, `name`, `status`, `downloadDir`, `percentDone`, `rateDownload`, `rateUpload`, `peersConnected`, `files`, `trackers`, `trackerStats` и др. |
| `torrent-add` | Добавить новый торрент | `filename` или `metainfo` (base64), `download-dir`, `paused`, `labels` | Добавленный торрент или ошибка (например, дубликат) | `filename` может быть URL, magnet-ссылка или путь. Если `paused=true`, торрент запускается в режиме паузы. |
| `torrent-start` | Запустить торрент(ы) | `ids` | — | `ids` может быть: целое число, строка, массив |
| `torrent-stop` | Остановить торрент(ы) | `ids` | — | Торрент переходит в режим паузы |
| `torrent-remove` | Удалить торрент(ы) | `ids`, `delete-local-data` (опционально) | — | Если `delete-local-data=true`, удаляются файлы торрента |
| `torrent-verify` | Проверить целостность торрента | `ids` | — | Долгая операция, статус проверяется через poll |

### Аутентификация и рукопожатие

1. **Session ID получение**: При первом запросе возвращается HTTP 409 с заголовком `X-Transmission-Session-Id`. Этот ID должен быть сохранен и отправлен в последующих запросах через заголовок `X-Transmission-Session-Id`. ⚠️ **ВАЖНО**: При наличии нескольких серверов session-id ДОЛЖЕН быть привязан к хосту/порту (см. `devdoc/TRANSMISSION_RPC_REFERENCE.md`).
2. **Basic Auth**: Username и password отправляются в заголовке `Authorization: Basic <base64(username:password)>`.
3. **HTTP/HTTPS политика**: 
   - **HTTP по умолчанию** в MVP (99% домашних серверов крутятся в локальной сети без HTTPS)
   - **HTTPS** поддерживается опционально, требует явного выбора пользователя при добавлении сервера
   - При использовании HTTPS: проверка сертификатов + поддержка самоподписанных (с явным подтверждением)
   - Предупреждение о рисках при использовании HTTP в открытых сетях (см. PRD.md раздел "HTTP vs HTTPS политика")
4. **API клиентов**: `TransmissionClient.performHandshake()` выполняет полный цикл (409 → повтор → `session-get`) и возвращает `TransmissionHandshakeResult` с session-id, номером RPC и человекочитаемой версией. Метод автоматически бросает `APIError.versionUnsupported`, если `rpc-version < 14`.
5. **Потокобезопасное хранение session-id**: `TransmissionClient` использует актор `SessionStore` для сериализации чтения/записи `X-Transmission-Session-Id`. Это исключает `nonisolated(unsafe)` и ручные `NSLock`, а также позволяет пройти строгую проверку `Sendable`. Все повторные запросы (после HTTP 409) повторно собирают заголовки уже из акторного хранилища.

### JSON-RPC структура

⚠️ **ВАЖНО**: Transmission RPC использует собственный формат, НЕ JSON-RPC 2.0. Не путайте!

**Запрос** (пример `torrent-get`):
```json
{
  "method": "torrent-get",
  "arguments": {
    "ids": [1, 2],
    "fields": ["id", "name", "status", "percentDone"]
  },
  "tag": 1
}
```

**Ответ (успех)**:
```json
{
  "result": "success",
  "arguments": {
    "torrents": [
      {"id": 1, "name": "Ubuntu", "status": 4, "percentDone": 0.75}
    ]
  },
  "tag": 1
}
```

**Ответ (ошибка)**:
```json
{
  "result": "too many recent requests",
  "tag": 1
}
```

### Коды ошибок

**Подробное описание и примеры маппинга** см. в документе — **[`devdoc/MODELS.md`](MODELS.md) - раздел "5. APIError"**.

| Тип | Значение | Действие |
|-----|---------|---------|
| **HTTP 409** | Session ID invalid | Кешировать новый `X-Transmission-Session-Id` из заголовка, повторить запрос |
| **HTTP 401** | Auth failed | Проверить Basic Auth заголовок |
| **HTTP 400** | Bad request | Проверить формат JSON запроса |
| **result: "success"** | Успех | Обработать `arguments` |
| **result: <string>** | Ошибка | Показать `result` как error message (строка, не код) |

⚠️ **НЕ используйте JSON-RPC коды**: Transmission вернёт строку в `result`, а не числовой код вроде -32602!

## Модели Transmission RPC (DTO и APIError)

В проекте определены четыре основные модели для работы с Transmission RPC:

**📖 Полная документация с примерами**: [`devdoc/MODELS.md`](MODELS.md)

**Краткий обзор**:

| Модель | Назначение | Файл |
|--------|-----------|------|
| `TransmissionRequest` | Исходящий RPC запрос (method, arguments, tag) | `Remission/TransmissionRequest.swift` |
| `TransmissionResponse` | Входящий RPC ответ (result, arguments, tag) + вспомогательные свойства | `Remission/TransmissionResponse.swift` |
| `AnyCodable` | Type-erasure для гибкого парсинга JSON (null, bool, int, double, string, array, object) | `Remission/AnyCodable.swift` |
| `TransmissionTag` | Перечисление для тегов запросов (int или string) | `Remission/TransmissionTag.swift` |
| `APIError` | Перечисление всех ошибок при работе с API (networkUnavailable, unauthorized, sessionConflict, versionUnsupported, decodingFailed, unknown) | `Remission/APIError.swift` |

**Все модели**:
- ✅ Соответствуют `Codable` протоколу для сериализации/десериализации
- ✅ Помечены `Sendable` для безопасного использования в async/await контексте
- ✅ Содержат документирующие комментарии в исходном коде

**Документация включает**:
- Полные определения типов
- Практические примеры использования
- Примеры JSON запросов и ответов
- Матрицу маппинга ошибок
- Рекомендации по расширению моделей
- Best practices и замечания по безопасности

### Коды ошибок

## Модели Transmission RPC (DTO и APIError)

В проекте определены следующие типы для работы с Transmission RPC:

### 1. TransmissionRequest

Представляет исходящий RPC запрос. Структура содержит метод, параметры и опциональный тег для корреляции.

**Определение**:
```swift
public struct TransmissionRequest: Codable, Sendable {
    public let method: String              // Имя метода RPC
    public let arguments: AnyCodable?      // Параметры метода
    public let tag: TransmissionTag?       // Опциональный тег для корреляции
}
```

**Пример использования**:
```swift
// Получить список торрентов
let request = TransmissionRequest(
    method: "torrent-get",
    arguments: AnyCodable.object([
        "fields": .array([
            .string("id"),
            .string("name"),
            .string("status"),
            .string("percentDone"),
            .string("rateDownload"),
            .string("rateUpload")
        ]),
        "ids": .array([.int(1), .int(2)])
    ]),
    tag: .int(1)
)

// Установить лимиты скоростей
let setLimitsRequest = TransmissionRequest(
    method: "session-set",
    arguments: AnyCodable.object([
        "speed-limit-down": .int(1024),
        "speed-limit-up": .int(256),
        "speed-limit-down-enabled": .bool(true),
        "speed-limit-up-enabled": .bool(true)
    ]),
    tag: .int(2)
)
```

**JSON после сериализации**:
```json
{
  "method": "torrent-get",
  "arguments": {
    "fields": ["id", "name", "status", "percentDone", "rateDownload", "rateUpload"],
    "ids": [1, 2]
  },
  "tag": 1
}
```

### 2. TransmissionResponse

Представляет входящий RPC ответ от сервера. Содержит статус результата, данные ответа и тег для корреляции.

**Определение**:
```swift
public struct TransmissionResponse: Codable, Sendable {
    public let result: String         // "success" или сообщение об ошибке
    public let arguments: AnyCodable? // Данные ответа (структура зависит от метода)
    public let tag: TransmissionTag?  // Тег для корреляции с запросом
    
    // Вспомогательные свойства
    public var isSuccess: Bool { result == "success" }
    public var isError: Bool { !isSuccess }
    public var errorMessage: String? { isError ? result : nil }
}
```

**Примеры использования**:

**Успешный ответ** (torrent-get):
```json
{
  "result": "success",
  "arguments": {
    "torrents": [
      {
        "id": 1,
        "name": "Ubuntu 22.04 LTS",
        "status": 4,
        "percentDone": 0.75,
        "rateDownload": 2048000,
        "rateUpload": 512000,
        "peersConnected": 12
      },
      {
        "id": 2,
        "name": "Debian 12",
        "status": 0,
        "percentDone": 1.0,
        "rateDownload": 0,
        "rateUpload": 128000,
        "peersConnected": 3
      }
    ]
  },
  "tag": 1
}
```

**Ответ об ошибке**:
```json
{
  "result": "too many recent requests",
  "tag": 1
}
```

**Обработка в коде**:
```swift
let decoder = JSONDecoder()
let response = try decoder.decode(TransmissionResponse.self, from: data)

if response.isSuccess {
    // Обработать успешный ответ
    if let torrents = response.arguments?.object?["torrents"]?.array {
        // Распарсить список торрентов
    }
} else {
    // Обработать ошибку
    let errorMsg = response.errorMessage ?? "Unknown error"
    throw APIError.mapTransmissionError(errorMsg)
}
```

### 3. AnyCodable

Тип-erasure для представления любого JSON-совместимого значения. Используется для гибкого декодирования `arguments` поля, которое может содержать различные структуры данных.

**Определение**:
```swift
@frozen
public enum AnyCodable: Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])
}
```

**Примеры использования**:

```swift
// Создание значений
let nullValue = AnyCodable.null
let boolValue = AnyCodable.bool(true)
let intValue = AnyCodable.int(42)
let stringValue = AnyCodable.string("example")
let arrayValue = AnyCodable.array([.int(1), .int(2), .int(3)])

// Создание объекта
let objectValue = AnyCodable.object([
    "method": .string("torrent-get"),
    "arguments": .object([
        "ids": .array([.int(1), .int(2)])
    ]),
    "tag": .int(1)
])

// Доступ к значениям
if case .object(let dict) = response.arguments {
    if case .array(let torrents) = dict["torrents"] {
        for torrent in torrents {
            if case .object(let torrentDict) = torrent,
               case .int(let id) = torrentDict["id"],
               case .string(let name) = torrentDict["name"] {
                print("Torrent: \(id) - \(name)")
            }
        }
    }
}
```

**Достоинства**:
- Позволяет парсить JSON без знания точной структуры
- Поддерживает рекурсивные объекты и массивы
- Совместим с Swift Codable протоколом
- Thread-safe (Sendable)

### 4. TransmissionTag

Перечисление, которое представляет тег запроса/ответа. Transmission RPC поддерживает теги как целые числа, так и строки.

**Определение**:
```swift
@frozen
public enum TransmissionTag: Sendable {
    case int(Int)
    case string(String)
}
```

**Примеры использования**:

```swift
// Числовой тег
let numericTag = TransmissionTag.int(1)

// Строковый тег
let stringTag = TransmissionTag.string("request-123")

// Использование в запросе
let request = TransmissionRequest(
    method: "torrent-get",
    arguments: nil,
    tag: numericTag
)

// Соответствие в ответе
let response = try decoder.decode(TransmissionResponse.self, from: data)
if case .int(let tagValue) = response.tag {
    print("Response tag: \(tagValue)")
}
```

**Зачем нужно**:
- Позволяет корреллировать асинхронные запросы с их ответами
- Поддерживает оба формата тегов, используемые серверами
- Работает с параллельными запросами

## Transmission Mock Server Interface (RTC-28)

### Контекст и цели
- Нужна спецификация мок-сервера Transmission для тестов, поддерживающего последовательные сценарии и проверки (asserts), совместимого с текущим `TransmissionClient`.
- Решение должно моделировать handshake (`HTTP 409` → `X-Transmission-Session-Id`), ошибки и успешные ответы Transmission RPC, не нарушая разделение слоёв (Tests ↔︎ Network).

### Рассматривались варианты
- **Кастомный `URLProtocol`** — библиотеки вроде Mockingjay демонстрируют, как перехватывать HTTP-запросы и выдавать преднастроенные ответы/ошибки через DSL `stub(...)` ([Mockingjay README](https://github.com/kylef/mockingjay/blob/master/README.md)).
- **Локальный HTTP сервер** — лёгкие фреймворки (например, Hummingbird) позволяют поднять embedded сервер с роутами (`Router`, `app.runService()`) ([Hummingbird README](https://github.com/hummingbird-project/hummingbird/blob/main/README.md)).

### Решение
Выбираем `URLProtocol`-подход:
- Интегрируется в `URLSession`, поэтому весь стек `TransmissionClient` остаётся нетронутым.
- Легко моделирует handshake: первый шаг отдаёт `409` с session-id, следующий — ожидаемый JSON.
- Обеспечивает быстрые детерминированные тесты без сетевых сокетов, что критично для Swift Testing и CI.
- Embedded сервер оставляем на будущее (см. Веха 13) для end-to-end сценариев с реальным Transmission.

### Архитектурный эскиз
```
Test → TransmissionMockServer
     → TransmissionMockURLProtocol (intercepts URLSession)
     → TransmissionClient (боевой код)
```

- `TransmissionMockServer` управляет сценариями и предоставляет `URLSessionConfiguration` с зарегистрированным протоколом.
- `TransmissionMockURLProtocol` сопоставляет входящие запросы с шагами сценария, эмитит ответы и фиксирует обращения.
- Тесты конфигурируют сценарии декларативно — без if/else логики рядом с проверками.

### Предлагаемая API-поверхность
```swift
public struct TransmissionMockScenario: Sendable {
    public let name: String
    public let steps: [TransmissionMockStep]
    public init(name: String, steps: [TransmissionMockStep])
}

public struct TransmissionMockStep: Sendable {
    public let matcher: TransmissionMockMatcher
    public let response: TransmissionMockResponsePlan
    public let assertions: [TransmissionMockAssertion]
    public let repeats: Int?
    public init(
        matcher: TransmissionMockMatcher,
        response: TransmissionMockResponsePlan,
        assertions: [TransmissionMockAssertion] = [],
        repeats: Int? = nil
    )
}

public struct TransmissionMockMatcher: Sendable {
    public let description: String
    public let matches: @Sendable (TransmissionRequest, URLRequest) -> Bool
    public static func method(_ name: String) -> Self
    public static func custom(
        description: String,
        _ predicate: @escaping @Sendable (TransmissionRequest) -> Bool
    ) -> Self
}

public enum TransmissionMockResponsePlan: Sendable {
    case rpcSuccess(arguments: AnyCodable? = nil, tag: TransmissionTag? = nil)
    case rpcError(result: String, statusCode: Int = 200, headers: [String: String] = [:])
    case http(statusCode: Int, headers: [String: String], body: Data? = nil)
    case network(_ error: URLError)
    case handshake(sessionID: String, followUp: TransmissionMockResponsePlan)
    case custom(_ builder: @Sendable (TransmissionRequest, URLRequest) throws -> TransmissionMockResponsePlan)
}

public struct TransmissionMockAssertion: Sendable {
    public let description: String
    public let evaluate: @Sendable (TransmissionRequest, URLRequest) throws -> Void
    public init(
        _ description: String,
        evaluate: @escaping @Sendable (TransmissionRequest, URLRequest) throws -> Void
    )
}

public final class TransmissionMockServer: @unchecked Sendable {
    public init()
    public func register(scenario: TransmissionMockScenario)
    public func reset()
    public func makeEphemeralSessionConfiguration() -> URLSessionConfiguration
    public func assertAllScenariosFinished(file: StaticString = #filePath, line: UInt = #line)
}
```

Ключевые особенности:
- **Очередь шагов**. Шаги потребляются в порядке регистрации; `repeats` позволяет одной записью описать N одинаковых ответов (например, polling `torrent-get`).
- **Handshake как первый класс**. `.handshake` возвращает `409` с session-id и автоматически подставляет follow-up ответ.
- **Assertions** проверяют `arguments`/`headers` и предотвращают «тихие» изменения клиента.
- **Fail-fast**: отсутствие совпадения шага приводит к понятной ошибке теста.
- **Thread-safety**: очередь/лог защищены актором или serial queue внутри сервера.

### Mock Server для Transmission RPC тестов

**Статус**: Реализовано (RTC-29)  
**Расположение**: `RemissionTests/TransmissionMockServer.swift`

#### Архитектура
- `TransmissionMockServer` регистрирует сценарии и предоставляет `URLSessionConfiguration` с `TransmissionMockURLProtocol`.
- `TransmissionMockURLProtocol` перехватывает запросы клиента, выполнив handshake/ответ/ошибку.
- Потокобезопасность обеспечена `NSLock`, `activeServer` хранится с weak-ссылкой, чтобы исключить утечки памяти.

#### Поддерживаемые сценарии
- HTTP 409 + `X-Transmission-Session-Id` рукопожатие.
- Успешные RPC ответы с аргументами и тегами.
- Ошибки RPC (`result != success`) с кастомными заголовками/кодами.
- Вбрасывание сетевых ошибок (`URLError`) для проверки retry-логики.
- Повторяющиеся шаги (`repeats`) для polling-тестов.
- Кастомные матчеры и assertions для валидации аргументов/заголовков.

#### Использование в тестах
```swift
let server = TransmissionMockServer()
server.register(scenario: .init(
    name: "Session flow",
    steps: [
        .handshake(sessionID: "abc123", followUp: .rpcSuccess()),
        .rpcSuccess(method: "torrent-get", arguments: torrents)
    ]
))
let config = server.makeEphemeralSessionConfiguration()
let client = TransmissionClient(config: testConfig, session: URLSession(configuration: config))
let response = try await client.sessionGet()
try server.assertAllScenariosFinished()
```

### Хелперы для составления шагов
- `.handshake(sessionID:followUp:)` — быстрый способ описать 409 → повторный ответ для любого метода (по умолчанию `session-get`).
- `.rpcSuccess(method:arguments:tag:repeats:assertions:)` — шаблон для успешных RPC-ответов.
- `.rpcError(method:result:statusCode:headers:repeats:assertions:)` — декларативное описание ошибок Transmission.
- `.networkFailure(method:error:repeats:assertions:)` — инъекция `URLError` для проверки retry/обработки сетевых сбоев.

### Transmission Fixtures Catalog (RTC-30)

- **Расположение**: `RemissionTests/Fixtures`
  - `Transmission/Session` — session-get/session-stats ответы (совместимость RPC 3.0+, рукопожатие).
  - `Transmission/Torrents` — успехи для torrent-get/add/start/stop/remove.
  - `Transmission/Errors` — обобщённые error-case ответы (throttle, auth, invalid JSON).
- **Загрузчик**: `TransmissionFixtureName` + `TransmissionFixture` обеспечивают доступ к данным и декодирование в `TransmissionResponse`.
  - `TransmissionMockResponsePlan.fixture(_:)` строит сценарии мок-сервера напрямую из фикстур.
- **Тесты**: `RemissionTests/TransmissionFixturesTests.swift` выполняет smoke-проверки загрузки, декодирования и маппинга ошибок.
- **Покрываемые сценарии для RTC-31/RTC-32**:
  1. Успешный session-get с RPC 17 (минимум 14) и пример несовместимой версии (RPC 12).
  2. Happy-pathы torrent-get/add/start/stop/remove.
  3. Ошибки: rate limit, unauthorized, invalid JSON (→ `APIError.decodingFailed`).
  4. Некорректная структура `session-get` (`arguments` не объект) для smoke-проверки `decodingFailed`.
- **Правила обновления** описаны в `RemissionTests/Fixtures/README-fixtures.md` (структура, формат, smoke-tests).

### TransmissionClient error-path тесты (RTC-32)
- **Расположение**: `RemissionTests/TransmissionClientErrorScenariosTests.swift`.
- **Инструменты**: `TransmissionMockServer` + Point-Free Swift Testing.
- **Покрытие**:
  - 409 → повтор с ограничением по рукопожатию (генерирует `APIError.sessionConflict`).
  - Версия RPC < 14 (→ `APIError.versionUnsupported`), HTTP 500 (→ `.unknown`), невалидный JSON (→ `.decodingFailed`), `URLError(.cannotConnectToHost)` (→ `.networkUnavailable`).
  - Проверка безопасного логирования: `DefaultTransmissionLogger` инжектируется с кастомным sink и подтверждает, что Base64 credentials и session-id не попадают в логи.
- **Взаимосвязь**: тесты используют те же фикстуры и сценарии, что и happy-path набор (RTC-31), поэтому новые сценарии документированы в том же разделе и не дублируют прод-код.

Справочные материалы (Context7):
- `/pointfreeco/swift-composable-architecture` — статья *Testing TCA* (TestStore, фикстуры для зависимостей).
- `/swiftlang/swift-testing` — документация по Discoverable Test Content и структуре Swift Testing.
- `/websites/transmission-rpc_readthedocs_io` — актуальные примеры ответов Transmission RPC (session-get, torrent-*).

### Интеграция в тесты
```swift
let mockServer = TransmissionMockServer()
mockServer.register(scenario: .init(
    name: "Happy path: handshake → list",
    steps: [
        .init(
            matcher: .method("session-get"),
            response: .handshake(
                sessionID: "mock-session",
                followUp: .rpcSuccess(arguments: .object(["rpc-version": .int(20)]))
            )
        ),
        .init(
            matcher: .method("torrent-get"),
            response: .rpcSuccess(arguments: torrentsArguments)
        )
    ]
))

let session = URLSession(configuration: mockServer.makeEphemeralSessionConfiguration())
let client = TransmissionClient(config: testConfig, session: session)
// ... TestStore, reducers ...
mockServer.assertAllScenariosFinished()
```

- Тесты остаются в парадигме TCA/TestStore: внедряем клиента через `@Dependency(\.transmissionClient)` с кастомным `URLSession`.
- Assertions фиксируют, что аргументы `torrent-get`/`session-set` соответствуют ожиданиям.
- `reset()` вызывается в `tearDown` для очистки.

### Следующие шаги реализации
1. Реализовать описанные типы + `TransmissionMockURLProtocol` (регистрация в `URLSessionConfiguration.protocolClasses`).
2. Покрыть mock unit-тестами (success, error, repeats, handshake, race conditions).
3. Переписать существующие reducer-тесты, заменив ручные стабы на сценарии.
4. Документировать шаблоны сценариев (happy path, ошибки авторизации, повторное получение session-id) в README/Tests.

### 5. APIError

Перечисление ошибок для представления всех типов сбоев при работе с Transmission RPC.

**Определение**:
```swift
@frozen
public enum APIError: Error, Equatable {
    case networkUnavailable                      // Сеть недоступна
    case unauthorized                             // Auth failed (HTTP 401)
    case sessionConflict                          // HTTP 409 — нужен новый session-id
    case versionUnsupported(version: String)     // Версия Transmission < 3.0
    case decodingFailed(underlyingError: String) // Ошибка парсинга JSON
    case unknown(details: String)                 // Неизвестная ошибка
}
```

**Маппинг ошибок HTTP**:

| HTTP Code | APIError | Действие |
|-----------|----------|----------|
| 401 | `unauthorized` | Проверить Basic Auth заголовок, запросить пароль заново |
| 409 | `sessionConflict` | Кешировать новый `X-Transmission-Session-Id` из заголовка, повторить запрос |
| 400 | `unknown(details:)` | Проверить формат JSON запроса |
| Network error | `networkUnavailable` | Проверить соединение, использовать exponential backoff |

**Маппинг ошибок Transmission RPC** (строки в `result` поле):

```swift
// Версионные ошибки
if errorString.contains("version") {
    return .versionUnsupported(version: errorString)
}

// Auth ошибки
if errorString.contains("auth") || errorString.contains("unauthorized") {
    return .unauthorized
}

// Ошибки декодирования
if errorString.contains("invalid JSON") || errorString.contains("parse") {
    return .decodingFailed(underlyingError: errorString)
}

// Fallback
return .unknown(details: errorString)
```

**Примеры использования**:

```swift
do {
    let response = try makeRPCCall(request)
    
    if response.isError {
        let error = APIError.mapTransmissionError(response.result)
        throw error
    }
    
    // Обработать успешный ответ
} catch APIError.networkUnavailable {
    showAlert("No network connection. Please check your internet.")
} catch APIError.unauthorized {
    showAlert("Authentication failed. Please check your credentials.")
} catch APIError.sessionConflict {
    // Система должна автоматически восстановить session и повторить запрос
    refreshSessionAndRetry()
} catch APIError.versionUnsupported(let version) {
    showAlert("Transmission version \(version) is not supported. Please upgrade to 3.0+")
} catch APIError.decodingFailed(let error) {
    logger.error("Failed to decode response: \(error)")
    showAlert("Server returned invalid data")
} catch APIError.unknown(let details) {
    logger.error("Unknown error: \(details)")
    showAlert("An unexpected error occurred")
}
```

### Расширение моделей в будущем

**Добавление новых полей**:
- При появлении новых методов Transmission, добавить соответствующие Codable типы в отдельные файлы (`TorrentPayload.swift`, `SessionPayload.swift` и т.д.)
- Использовать `AnyCodable` для гибкости при добавлении новых полей
- Обновить `APIError` при появлении новых типов ошибок

**Версионирование**:
- При изменении структуры DTO, проверить совместимость с RPC версией (через `session-get`)
- Использовать `CodingKeys` для маппинга устаревших полей
- Документировать поддерживаемые версии в комментариях

**Пример добавления нового типа ответа**:

```swift
/// Расширение: поддержка torrent-verify status
public struct TorrentVerifyStatus: Codable, Sendable {
    public let id: Int
    public let verifyProgress: Double // 0.0 до 1.0
}

// Использование в arguments как часть AnyCodable
let verifyResponse = try decoder.decode(TransmissionResponse.self, from: data)
if let statusData = verifyResponse.arguments?.object?["status"] {
    // Парсить статус проверки
}
```

### Edge Cases и требования

1. **Timeout и retry**: Рекомендуемый timeout = 30 секунд. При сетевых ошибках использовать exponential backoff (1s, 2s, 4s, ..., max 60s).
2. **Пустые ответы**: Торрент может не содержать поле `files`, если их нет в списке. Проверять наличие перед использованием.
3. **Сериализация**: `ids` может быть integer, string (для hash), или array. Всегда использовать array для унификации.
4. **Версионирование**: RPC версия может измениться, поля добавляться/удаляться. Использовать `session-get` и `utils.get_torrent_arguments(rpc_version)` для динамического определения поддерживаемых полей.

### Ссылки для разработчиков

- **Мониторинг совместимости**: При подключении проверить `session-get` результат, убедиться что версия >= 3.0 или >= 4.0 согласно требованиям MVP.
- **Локальное тестирование**: Docker образ `transmissionbt/transmission:latest` или версии 4.0+ для CI.
- **Документация API**: https://github.com/transmission/transmission/wiki (основной источник). При изменении требований обновить ссылку и версионные требования в этой таблице.

---

## Веха 1: Основа Transmission RPC
- M1.1 Смоделировать ключевые конечные точки Transmission RPC и структуры полезной нагрузки. **Использовать контракт выше** и [`TRANSMISSION_RPC_REFERENCE.md`](TRANSMISSION_RPC_REFERENCE.md).
- M1.2 Реализовать кодирование и декодирование запросов и ответов с переводом ошибок в тип APIError. Обратите внимание: используется `method`/`arguments`/`tag` (не JSON-RPC 2.0 `jsonrpc`/`id`/`error`).
- M1.3 Добавить механизм рукопожатия для получения session-id и согласования версий клиента и сервера. Обработка HTTP 409 с заголовком `X-Transmission-Session-Id`. **Порт: 9091** (не 6969).
- M1.4 Подготовить мок-сервер для модульных тестов сетевого слоя (использование Swift Testing с @Test). Ссылка: https://raw.githubusercontent.com/transmission/transmission/main/docs/rpc-spec.md
- Проверка: покрыть тестами построение запросов и декодирование ответов на фиктивных данных с использованием Swift Testing фреймворка. Убедиться, что парсится формат с `"result": "success"` (не JSON-RPC ошибки).

## Веха 2: Безопасность и аутентификация
- M2.1 Реализовать подстановку заголовка Basic Auth в TransmissionClient согласно HTTPS требованиям.
- M2.2 Сохранить учетные данные через обертку Keychain (используя `kSecClass` для типа записи (kSecClassGenericPassword), `kSecAttrService` для идентификации сервиса (com.remission), `kSecAttrAccount` для username/email и `.accessibility(.whenUnlocked)` для безопасности) и написать для нее модульные тесты Swift Testing.
- M2.3 Предоставить безопасный API управления учетными данными для верхних слоев. НИКОГДА не логировать пароли — логировать только "Auth successful" или error codes.
- M2.4 Задокументировать требования к HTTPS/TLS, проверке сертификатов и обработке self-signed сертификатов (показать диалог пользователю).
- M2.5 Добавить требование HTTPS при подключении с предупреждением для HTTP соединений в Keychain раздел PRD.
- Проверка: модульные тесты Keychain с использованием Swift Testing (@Test) и smoke-тест подключения к локальному Transmission с авторизацией.

### HTTPS/TLS политика и обработка сертификатов (RTC-40)
- **Цели**: 
  - Гарантировать безопасное соединение при удалённом доступе и предоставить прозрачное предупреждение при использовании HTTP.
  - Обработать самоподписанные сертификаты без компрометации безопасности и без принудительного certificate pinning.
- **Основные принципы**:
  - По умолчанию `URLSession` выполняет проверку цепочки доверия сертификата. Соединения по HTTPS считаются успешными только при `SecTrustEvaluateWithError` == true.
  - HTTP разрешён для локальных сценариев, но всегда сопровождается предупреждением (см. PRD «HTTP vs HTTPS политика»); при удалённом доступе рекомендуем HTTPS.
- **ATS**:
  - Не использовать `NSAllowsArbitraryLoads`. Для локальных IP/доменов допускается точечное исключение в `NSExceptionDomains` с указанием минимальной версии TLS не ниже `TLSv1.2`.
  - Ссылки: `NSAppTransportSecurity` и настройка исключений документированы в Apple ATS руководстве.
- **Потоки подключения**:
  1. **Доверенный сертификат** — `URLSession` выполняет стандартную проверку, приложение продолжает подключение автоматически. UX: отображается статус «Защищенное подключение (HTTPS)». 
  2. **Самоподписанный сертификат** — `challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust`, `SecTrustEvaluateWithError` возвращает false, но `SecTrustCopyProperties` показывает отсутствие доверенного центра. Действия:
     - Отобразить диалог с деталями сервера (host, port, fingerprint SHA-256) и двумя опциями: «Доверять» и «Отмена». Добавить ссылку на UX требования в PRD.
     - При подтверждении создать `URLCredential(trust:serverTrust, persistence:.forSession)` и продолжить выполнение запроса. Сохранить выбор пользователя в защищённом хранилище:
       - ключ: `serverId = scheme://host:port`
       - данные: SHA-256 отпечаток цепочки и дата подтверждения. Хранилище: Keychain (`kSecClassGenericPassword`, service `com.remission.tls-exceptions`).
     - При последующих подключениях сверять новый отпечаток с сохранённым; несовпадение → запросить повторное подтверждение.
  3. **Проверка не пройдена / отказ** — если пользователь отменил диалог или доверенный сертификат не может быть подтверждён, завершить с ошибкой `ConnectionSecurityError`. UX: показать инструкцию о необходимости обновить сертификат. Логи: `logger.error("TLS validation failed for \(host):\(port) – reason: \(error)")` без включения сертификата/отпечатка.
- **Поток подтверждения (ASCII-диаграмма)**:
  ```text
  Пользователь ── запрос HTTPS ──▶ TransmissionClient
                   │
                   ├─ SecTrustEvaluateWithError == true ──▶ Успех (баннер «HTTPS защищён»)
                   │
                   └─ SecTrustEvaluateWithError == false
                          │
                          ▼
              Диалог «Сертификат не доверен»
                   ├─ Отмена ──▶ Ошибка `ConnectionSecurityError`
                   └─ Доверять ──▶ Расчёт SHA-256 отпечатка ──▶ Сохранение в Keychain
                                                            │
                                                            ▼
                                            Следующее подключение
                                                ├─ Отпечаток совпал ─▶ Успех
                                                └─ Отпечаток изменился ─▶ Новое подтверждение
  ```
- **Логирование и безопасность**:
  - Не логировать содержимое сертификатов или секреты. Разрешено фиксировать только факт доверия и дату (например: `logger.info("User trusted self-signed certificate for serverId=...")`).
  - Решения пользователя хранятся в Keychain и синхронизируются только на локальном устройстве (`kSecAttrSynchronizable = false`).
  - При сбросе сохранённого сервера удалять и исключение TLS.
- **Apple URLSessionDelegate**:
  ```swift
  func urlSession(
      _ session: URLSession,
      didReceive challenge: URLAuthenticationChallenge,
      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
      guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
      else {
          completionHandler(.performDefaultHandling, nil)
          return
      }

      let serverId = ServerID(
          host: challenge.protectionSpace.host,
          port: challenge.protectionSpace.port,
          isSecure: true
      )

      if trustStore.matchesCachedFingerprint(for: serverId, serverTrust: serverTrust) {
          completionHandler(.useCredential, URLCredential(trust: serverTrust))
          return
      }

      pendingTrustPrompt.send(.ask(userDecision: .init(serverId: serverId, trust: serverTrust)))
      completionHandler(.cancelAuthenticationChallenge, nil) // повторим запрос после решения пользователя
  }
  ```
- **SHA-256 fingerprinting**:
  ```swift
  func fingerprintSHA256(for trust: SecTrust) throws -> Data {
      guard let certificate = SecTrustGetCertificateAtIndex(trust, 0),
            let key = SecCertificateCopyKey(certificate),
            let representation = SecKeyCopyExternalRepresentation(key, nil) as Data?
      else {
          throw CertificateError.unableToExtractKey
      }

      return Data(SHA256.hash(data: representation))
  }
  ```
- **Рекомендации по UX**:
  - Диалог подтверждения должен содержать краткое объяснение рисков self-signed, кнопку для просмотра подробностей и ссылку на статью поддержки (подготовит UX).
  - Для HTTP-соединений отображать баннер-предупреждение при каждом подключении и возможность перейти к настройкам для включения HTTPS.
- **UISpec диалога подтверждения**:
  - Заголовок: «Ненадёжный сертификат».
  - Текст: предупреждение о рисках + блок с деталями (`Сервер`, `SHA-256 отпечаток`, подсказка для пользователя).

### Реализация доверия сертификатам (RTC-46)
- **Хранилище отпечатков**: `TransmissionTrustStore.swift` использует Keychain (`service = com.remission.transmission.trust`). Для тестов добавлен in-memory интерфейс, повторяющий поведение SecItemAdd/Update/Copy/Delete.
- **Проверка доверия**: `TransmissionTrustEvaluator.swift` инкапсулирует `SecTrustEvaluateWithError`, сравнение отпечатков и работу с пользователем. При обнаружении нового или изменённого отпечатка удаляет старое значение и эмитит challenge.
- **URLSessionDelegate**: `TransmissionSessionDelegate.swift` подключён в `TransmissionClient` (кастомная `URLSession(Configuration:delegate:)`). Делегат пробрасывает `serverTrust` в evaluator и обрабатывает результат (`useCredential`/`cancel`).
- **Промпты для UI**: `TransmissionTrustPromptCenter` публикует `AsyncStream<TransmissionTrustPrompt>` и предоставляет `makeHandler()` для регистрации в клиенте. `RemissionApp` связывает prompt-center с `TransmissionClient` через `setTrustDecisionHandler`.
- **Ошибки**: `APIError` дополнен `.tlsTrustDeclined` и `.tlsEvaluationFailed` с отображением в `TorrentDetailFeature.userFriendlyMessage`.
- **Тесты**:
  - `TransmissionTrustStoreTests` проверяет сохранение, обновление и удаление отпечатков.
  - `TransmissionTrustEvaluatorTests` покрывают доверенный сертификат (anchor), подтверждение self-signed, отказ пользователя и совпадение отпечатка (фикстура DER).
  - `TransmissionTrustPromptCenterTests` удостоверяются, что `AsyncStream` и резолвер корректно возобновляют продолжение.
  - Кнопки: primary `Доверять`, secondary `Отмена`, дополнительная ссылка `Подробнее…` с переходом к справке.
  - Реализация: `AlertState` в TCA с `@Presents`, локализации RU/EN, поддержка VoiceOver (accessibilityLabel/Hint).
- **Безопасная реализация**:
  - Реализовать обработку через `urlSession(_:didReceive:completionHandler:)` и вызывать `completionHandler(.useCredential, credential)` только после явного подтверждения.
  - Использовать `SecCertificateCopyKey` + `SecKeyCopyExternalRepresentation` для вычисления SHA-256 отпечатка. Хранить только хэш.
- **Справочные материалы**:
  - Apple: [URLSessionDelegate.urlSession(_:didReceive:completionHandler:)](https://developer.apple.com/documentation/foundation/urlsessiondelegate/1409308-urlsession)
  - Apple: [SecTrust API Overview](https://developer.apple.com/documentation/security/sectrust)
  - Apple: [Certificate, Key, and Trust Services](https://developer.apple.com/documentation/security/certificate_key_and_trust_services)
  - Apple: [Handling an authentication challenge](https://developer.apple.com/documentation/foundation/handling-an-authentication-challenge)
  - Apple: [Preventing insecure network connections](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)

### Basic Auth + HTTP 409 Handshake (RTC-37)
- TransmissionClient формирует заголовок `Authorization: Basic <base64(user:password)>` через `URLCredential(user:password:persistence:)`, что соответствует рекомендациям Apple (Context7: developer.apple.com → Handling an authentication challenge).
- Заголовки `Authorization` и `X-Transmission-Session-Id` выставляются централизованно в `applyAuthenticationHeaders(to:)`, поэтому повторный запрос после 409 использует те же credentials и свежий session-id без дублирования кода.
- Session-id хранится потокобезопасно (`NSLock` + `nonisolated` поле) и обновляется только при получении нового значения от сервера.
- Логирование (`DefaultTransmissionLogger`) маскирует и Base64, и session-id; добавлены тесты на отсутствие утечки секретов.
- Unit-тесты покрывают happy path генерации заголовка, ретрай после 409 с повторным заголовком и проверку маскировки логов (`TransmissionClientMethodsTests`, `TransmissionClientErrorScenariosTests`).

### Keychain Credentials Store (RTC-38)
- **Назначение**: безопасное хранение учетных данных Transmission в Keychain с доступом через `KeychainCredentialsDependency`.
- **API**: 
  - `save(_:)` — добавляет или обновляет запись `kSecClassGenericPassword` с service-id `com.remission.transmission`.
  - `load(key:)` — возвращает пароль и метаданные сервера либо `nil`, если запись отсутствует.
  - `delete(key:)` — удаляет запись; отсутствие элемента не считается ошибкой.
- **Ключи**:
  - `kSecAttrAccount = "\(username)/\(host):\(port)/\(scheme)"` (scheme = `http|https`) для гарантии уникальности.
  - `kSecAttrService = "com.remission.transmission"`.
  - `kSecAttrAccessible = kSecAttrAccessibleWhenUnlocked`.
  - `kSecAttrSynchronizable = false`, `kSecUseDataProtectionKeychain = true`.
  - Метаданные (`host`, `port`, `isSecure`, `username`) сериализуются в `kSecAttrGeneric` (JSON) для последующего восстановления ключа.
- **Ошибки**: `OSStatus` маппится в `KeychainCredentialsStoreError` (`.notFound`, `.unexpectedItemData`, `.unexpectedPasswordEncoding`, `.osStatus(OSStatus)`), сообщения отдаются через `SecCopyErrorMessageString`.
- **Зависимость**: `KeychainCredentialsDependency` предоставляет live/test значения через TCA `@DependencyClient`, что позволяет легко мокировать Keychain в фичах.
- **Тесты**: `KeychainCredentialsStoreTests` покрывают happy path (insert, update, load), error path (invalid payload, update failure) и delete-сценарии с моками `SecItem*`.
- **Справочные материалы**:
  - Apple Keychain Services — хранение и запрос generic password (`/websites/developer_apple`, разделы *Storing keys in the keychain*, *Adding a password to the keychain*, *kSecClassGenericPassword*).
  - Best practices wrapper (`/kishikawakatsumi/keychainaccess`) — примеры конфигурации service/account и отключения синхронизации.

### Credentials Repository + Audit Logging (RTC-39)
- **Цель**: предоставить верхним слоям единый stateless API (`CredentialsRepository`) с async-методами `save/load/delete`, исключающий прямой доступ к Keychain и инкапсулирующий маскирование логов.
- **Dependencies**:
  - `@Dependency(\.keychainCredentials)` — низкоуровневая Keychain-обёртка (RTC-38).
  - `@Dependency(\.credentialsAuditLogger)` — новый аудит-логгер с маскированием username (первые/последние символы) и отображением only host/port/scheme. Live-значение печатает безопасные сообщения, test/preview — `noop`.
  - Реализация опирается на Context7 материалы по TCA Dependencies (`/pointfreeco/swift-composable-architecture`, статьи *DependencyManagement*, *GettingStarted*) и best practices secure storage (`/kishikawakatsumi/keychainaccess`, разделы *Create Keychain Instances for Application Passwords*, *Configure Keychain Accessibility Levels*).
- **Поведение**:
  - Успешные операции логируются как `CredentialsAuditEvent.saveSucceeded/loadSucceeded/deleteSucceeded`.
  - Пропажи записей (`nil`) фиксируются как `loadMissing`, ошибки Keychain транслируются вверх, но дополнительно логируются как `.saveFailed/.loadFailed/.deleteFailed`.
  - Аудит-лог содержит только endpoint (`scheme://host:port`) и маскированный username (`a•••n`), пароли/полный username никогда не попадают в сообщение.
- **Тесты**: `CredentialsRepositoryTests` (Swift Testing) покрывают happy path сохранения, ошибку сохранения, отсутствие записи и ошибку удаления. Отдельные проверки гарантируют отсутствие сырых credentials в логах.
- **Интеграция в TCA**: `DependencyValues.credentialsRepository` доступен фичам, для TestStore достаточно переопределить `keychainCredentials` и `credentialsAuditLogger`, чтобы получить in-memory/mocked сценарии.

## Веха 3: Доменное ядро
- M3.1 Описать доменные модели Torrent, ServerConfig и SessionState.
- M3.2 Настроить преобразование DTO Transmission RPC в доменные модели с валидацией полей.
- M3.3 Определить протоколы репозиториев для торрентов, сессий и настроек.
- M3.4 Подготовить заглушки репозиториев для тестов UI и TCA.
- Проверка: модульные тесты репозиториев с моками TransmissionClient.

### Контракты репозиториев (RTC-55)
- **TorrentRepositoryProtocol / TorrentRepository** (`Remission/TorrentRepository.swift`) — API доменного слоя для списка и деталей торрентов. Поддерживает старт/стоп/удаление/верификацию, а также обновление лимитов скоростей (`TransferSettings`) и настроек файлов (`FileSelectionUpdate`). Live-реализация будет опираться на `TransmissionClientDependency` и `TransmissionDomainMapper` для преобразования ответов RPC.
- **SessionRepositoryProtocol / SessionRepository** (`Remission/SessionRepository.swift`) — отвечает за handshake, получение актуального `SessionState` и применение обновлений (`SessionUpdate`). Метод `checkCompatibility` инкапсулирует проверку версий RPC. Реализация планируется поверх `session-get`, `session-set` и `session-stats` Transmission.
- **UserPreferencesRepositoryProtocol / UserPreferencesRepository** (`Remission/UserPreferencesRepository.swift`) — централизованный доступ к `UserPreferences` (polling interval, автообновление, дефолтные лимиты скоростей). Предполагаемая живая реализация сохранит данные в `UserDefaults`/Keychain в зависимости от чувствительности, с поддержкой миграций.
- Все изменения polling/autoRefresh/limits идут через `UserPreferencesRepository` (без прямых обращений к `UserDefaults`). Для UI-тестов используйте `UI_TESTING_PREFERENCES_SUITE` + опционально `UI_TESTING_RESET_PREFERENCES=1`, чтобы сбросить snapshot перед первым запуском.
- Все структуры реализуют `DependencyKey`, предоставляют `previewValue`/`testValue` и `placeholder`/`unimplemented` конфигурации, что позволяет использовать репозитории в TCA-фичах и тестах без реальной инфраструктуры.

### Тестовые реализации (RTC-56)
- **InMemory хранилища** (`Remission/InMemoryRepositories.swift`) предоставляют `actor`-бэкенды для `TorrentRepository`, `SessionRepository`, `UserPreferencesRepository`. Каждое хранилище поддерживает:
  - настройку исходных доменных фикстур (`DomainFixtures` из `RemissionTests/Fixtures/Domain`);
  - маркировку операций как ошибочных (например, `markFailure(.fetchDetails)`) для проверки error-path сценариев;
  - потокобезопасные обновления состояния (включая изменение статуса торрента, обновление лимитов, модификацию файлов).
- `DependencyValues.preview` и `DependencyValues.test` теперь используют in-memory реализации, что устраняет `notConfigured` падения в SwiftUI previews и TestStore без дополнительной настройки.
- **Набор фикстур** (`RemissionTests/Fixtures/Domain/DomainFixtures.swift`) собирает типовые данные для торрентов, сессии и предпочтений. Служит единым источником данных для превью, тестов репозиториев и TCA сценариев.
- **Helper для кастомных репозиториев** (`RemissionTests/TorrentRepositoryTestHelpers.swift`) позволяет создавать `TorrentRepository.test(...)` с точечными переопределениями методов — удобно для имитации долгих запросов или выброса специфичных ошибок в отдельных тестах.
- **Примеры использования**:
  - `RemissionTests/InMemoryRepositoryTests.swift` — happy path + failure для каждого in-memory репозитория.
  - `RemissionTests/TorrentDetailFeatureTests.swift` — TestStore, полностью работающий через `@Dependency(\.torrentRepository)` (без прямого `TransmissionClientDependency`), охватывающий сценарии загрузки деталей, запуска торрента, переключения лимитов и установки приоритета.
- При написании новых TCA тестов рекомендуется:
  1. Создавать `InMemory...Store` с нужными фикстурами.
  2. Передавать `TorrentRepository.inMemory(store:)` (или аналог для сессий/настроек) через `withDependencies`.
  3. Для нестандартных сценариев использовать `TorrentRepository.test` и явно контролировать эффекты/ошибки.

## RTC-64: Server Persistence & Recovery

### Storage format и расположение
- Публичные параметры сервера (host/port/path/security/username) сохраняются в `servers.json` по пути `~/Library/Application Support/Remission/servers.json`.
- Формат — массив `StoredServerConfigRecord` с ISO8601 датами:
  ```json
  [
    {
      "id": "UUID",
      "name": "NAS",
      "host": "nas.local",
      "port": 9091,
      "path": "/transmission/rpc",
      "isSecure": true,
      "allowUntrustedCertificates": false,
      "username": "admin",
      "createdAt": "2025-11-10T10:00:00Z"
    }
  ]
  ```
- Пароли хранятся отдельно в Keychain под ключом `transmission-credentials-{host}:{port}:{username}`.

### Bootstrap и восстановление
- `AppBootstrap.makeInitialState(arguments:storageFileURL:)` синхронно читает snapshot через `ServerConfigStoragePaths.loadSnapshot`, мапит записи через `TransmissionDomainMapper` и заполняет `ServerListReducer.State` до запуска TCA окружения.
- При удачном восстановлении `serverList.shouldLoadServersFromRepository` переводится в `false`, чтобы избежать повторной загрузки тех же данных.
- `TransmissionClientBootstrap.makeConfig` использует тот же snapshot + Keychain для построения `TransmissionClientConfig` до показа UI.

### Keychain lifecycle
- Добавление сервера (онбординг или UI) → `CredentialsRepository.save` вызывается до `serverConfigRepository.upsert`.
- Удаление сервера (через `ServerListReducer` или `ServerDetailReducer`) всегда подтверждается пользователем и выполняет последовательность:
  1. Собирает `credentialsKey` у выбранного сервера и вызывает `credentialsRepository.delete`.
  2. Сбрасывает предупреждения HTTP через `HttpWarningPreferencesStore.reset` и отпечаток в `TransmissionTrustStore`.
  3. После успешной очистки секретов вызывает `serverConfigRepository.delete`.
- Такой порядок гарантирует, что Keychain и решения доверия не «подвисают» после удаления сервера и что UI/репозиторий остаются консистентными.

### Редактирование и безопасность серверов (RTC-65)
- Добавлен общий `ServerConnectionFormState` + `ServerConnectionFormFields`, которые переиспользуются онбордингом и редактором.
- `ServerEditorReducer` отвечает за валидацию, предупреждение при переключении на HTTP, сохранение изменений (включая Keychain) и уведомление `ServerDetailReducer` через delegate.
- `ServerDetailReducer` теперь открывает редактор (sheet), прокидывает delegate вверх в `AppReducer`, а также содержит отдельные действия:
  - «Сбросить доверие сертификату» — очищает только `TransmissionTrustStore`.
  - «Сбросить предупреждения HTTP» — очищает только `HttpWarningPreferencesStore`.
  - «Удалить сервер» — подтверждает, чистит Keychain/Trust/HTTP и уведомляет корневой Store.
- `ServerListView` отображает бейдж безопасности (HTTPS/HTTP), предоставляет swipe/context действия «Изменить» и «Удалить» и маршрутизирует все операции через Reducer + репозиторий.

### Покрытие тестами
- `RemissionTests/ServerConfigRepositoryTests.swift`
  - in-memory CRUD happy-path.
  - file-based happy-path (upsert → snapshot → delete).
  - failure-path (ошибка записи в недоступный файл → `ServerConfigRepositoryError.failedToPersist`).
- `AppBootstrapTests.loadsPersistedServersFromStorage` — создаёт временный `servers.json`, запускает `AppBootstrap.makeInitialState` и проверяет, что серверы подхватываются и `shouldLoadServersFromRepository` обнуляется.
- `ServerListFeatureTests.deleteRequiresConfirmationBeforeRemoving` проверяет, что swipe-delete показывает подтверждение, чистит Keychain и вызывает `serverConfigRepository.delete`.
- `ServerDetailFeatureTests` покрывают редактирование (delegate `.serverUpdated`) и оба сценария удаления (подтверждение/отмена + очистку секретов).

### Документация и операции
- README содержит раздел «Сохранение серверов и резервные копии» с инструкциями, как скопировать `servers.json` и экспортировать соответствующие записи Keychain.
- При релизах проверяем, что формат `StoredServerConfigRecord` обратнос совместим; изменения должны сопровождаться миграцией (см. `AppStateVersion`).

## Веха 4: Инфраструктура TCA
- M4.1 Подготовить общие утилиты (абстракции времени через swift-clocks, контейнер зависимостей через @Dependency, Environment setup).
- M4.2 Определить типы AppState (@ObservableState), AppAction и приватные Reducers с @Reducer. Документировать версионирование State структур для миграций.
- M4.3 Описать в документации принципы композиции редьюсеров и обработки эффектов через `.run { send in ... }` блоки. Все побочные эффекты должны быть инкапсулированы через Environment.
- M4.4 Настроить TestStore и вспомогательные методы для тестирования редьюсеров с использованием Swift Testing (@Test). Каждый редьюсер должен иметь хотя бы happy path и error path тесты.
- M4.5 Добавить примеры использования @Dependency для мокирования services и repositories в тестах.
- Проверка: модульные тесты базовых редьюсеров с использованием Swift Testing @Test и TestStore с mock зависимостями.

### Инфраструктура зависимостей и времени (RTC-57)
- **Цель**: выстроить единый слой зависимостей для TCA, чтобы все фичи получали Clock, UUID, логгеры и сетевые клиенты через `@Dependency`. Текущая реализация (`TransmissionClockDependency`, `TransmissionClientBootstrap`) фокусируется на Transmission и не покрывает остальные сервисы.
- **Работы**:
  - Вынести `TransmissionClockDependency` в нейтральный `AppClockDependency` (поддержка `ContinuousClock`/`TestClock`), обновить клиентов Transmission и будущих polling-задач.
  - Добавить DependencyClients для `UUIDGenerator`, `DateProvider`, `MainQueue` (используем `swift-clocks` и `DispatchQueue.main` через `clock.sleep`), чтобы исключить прямые вызовы `UUID()`/`Date()` из редьюсеров.
  - Сформировать `AppDependencies` фабрику, возвращающую `DependencyValues` для `Store(initialState:reducer:)` (см. `RemissionApp.swift`). Фабрика должна учитывать будущие хранилища (серверы, пользовательские настройки) и проксировать существующие live/test значения.
  - Подготовить `DependencyValues+App.swift` с convenience-методами для инициализации Store в превью/тестах (`DependencyValues.appDefault()`, `DependencyValues.appPreview()`).
- **Рефакторинг**: удалить прямые обращения к `TransmissionClockDependency` вне Transmission-кода, обновить иерархию файлов (`DependencyClients/AppClockDependency.swift` с live/test/preview значениями).
- **Артефакты**: новая документация в этом файле (раздел "AppDependencies"), диаграмма зависимостей (PlantUML/mermaid) опционально для PR.

#### Реализация (состояние после RTC-57)
- `DependencyClients/AppClockDependency.swift` — универсальный `AppClockDependency` c `ContinuousClock()` по умолчанию и helper `test(clock:)` для инъекции `TestClock` в Reducer тестах.
- `DependencyClients/UUIDGeneratorDependency.swift`, `DateProviderDependency.swift`, `MainQueueDependency.swift` — клиенты для генерации UUID, получения `Date` и выполнения операций на MainActor. Live реализации используют `UUID()`, `Date()` и `Task.sleep(for:)`/`MainActor.run`, тест/preview варианты возвращают плейсхолдеры без обращения к глобальному состоянию.
- `AppDependencies.swift`:
  - `AppDependencies.makeLive()` формирует полный `DependencyValues` набор для `RemissionApp`, включая вызов `TransmissionClientBootstrap` (получает `appClock` вместо старого `TransmissionClockDependency`).
  - `DependencyValues.appDefault()/appPreview()/appTest()` и `useAppDefaults()` обеспечивают единое заполнение clock/UUID/Date/MainQueue зависимостей для рабочих, превью и тестовых окружений.
- `RemissionApp` теперь инициализирует Store через `AppDependencies.makeLive()`, а `TransmissionClientBootstrap` использует `dependencies.appClock.clock()` при создании `TransmissionClient`.
- `TorrentDetailReducer` обновлён на `@Dependency(\.dateProvider)`; тесты `TorrentDetailFeatureTests` переключены на `dateProvider.now = { timestamp }`.

### Версионирование корневого состояния и навигации (RTC-58)
- **Цель**: зафиксировать контракт `AppReducer.State` для будущих миграций и десктоп/мобильной синхронизации.
- **Работы**:
  - Ввести `AppStateVersion` (enum) и хранить актуальную версию в `AppBootstrap.makeInitialState`. Версия используется для условной инициализации новых секций State.
  - Добавить `AppStateSchema.md` в `devdoc/` с описанием разделов состояния (serverList/path) и правилами эволюции.
  - Прописать процедуру миграции (как повышать версию, как обрабатывать старые persisted state при появлении хранения в iCloud/CoreData).
  - Обновить `AppFeatureTests` и превью `AppView` для проверки корректной инициализации при смене версии.
- **Рефакторинг**: выровнять навигационный стек `StackState` с версионированием (при несовпадении версии — очищать path в `AppBootstrap`).

#### Реализация (состояние после RTC-58)
- Добавлен `AppStateVersion` c кейсами `legacy` и `v1`; `AppReducer.State` теперь хранит версию и предоставляет явный инициализатор. `AppBootstrap.makeInitialState` принимает `targetVersion` и опциональное `existingState`, вызывая миграцию перед применением UI-фикстур.
- `AppBootstrap.migrate(_:to:)` сбрасывает `StackState` при несовпадении версий и служит расширяемой точкой для будущих преобразований.
- Создан `devdoc/AppStateSchema.md`, описывающий актуальный контракт состояния, навигационный стек и пошаговую процедуру повышения версии.
- `AppBootstrapTests` покрывают сценарии миграции legacy-state и проверяют присвоение текущей версии. Превью `AppView` используют обновлённый state builder (без дополнительной логики).

### Документация композиции редьюсеров и эффектов (RTC-59)
- **Цель**: зафиксировать в `plan.md` и `PRD.md` правила разделения редьюсеров, работы с `.run` и зависимости эффектов от окружения, чтобы новые фичи применяли единый подход.
- **Работы**:
  - Добавить подраздел «TCA Composition Guidelines» с конкретными примерами из `AppFeature.swift`/`ServerListReducer.swift`, объяснить, как использовать `Scope`, `forEach`, `Delegation` и `.ifLet` для presentation state.
  - Подготовить пример эффекта, который берёт `@Dependency(\.appClock)` и делает периодический запрос, фиксировать требования к отмене (`.cancellation(id:)`) и retry-логике.
  - Подготовить тестовую стратегию для эффектов с таймером (используя `TestClock` и `TestStore`) и описать, как проверять отмену цепочек.
  - Обновить шаблон для новых фич (`Templates/FeatureChecklist.md`) и quick-check лист в AGENTS, чтобы вся команда ссылалась на новый гайд.
  - Перекрестные ссылки: `CONTEXT7_GUIDE.md` (раздел по TCA), `SwiftUI + TCA Template`.
- **Артефакты**: новый подраздел документации, кодовые примеры (AppFeature.swift, ServerListFeature.swift), шаблон фичи, ссылка в AGENTS quick checklist.

#### Руководство по композиции
- **Составные редьюсеры**: корневой редьюсер (`AppFeature`) использует `Scope(state:action:)` для выделенных фич и `forEach(\.path, action: \.path)` для стековых навигационных сценариев, чтобы делегировать действия дочерним редьюсерам и делить `State`.
- **Presentation state**: чтобы не засорять `Reduce`, `@Presents` описывает опциональные блоки (alerts/sheets) и осуществляется через `.ifLet(\.$alert, action: \.alert)` (см. `ServerListReducer.Alert`). Каждая презентация должна иметь отдельный `PresentationAction`.
- **Делегирование**: дочерние reducers отправляют `delegate`-действия вверх, как в `ServerListReducer` (`.delegate(.serverSelected(server))`), а родитель обрабатывает их в `Reduce` и инжектирует через `Scope`/`forEach`.
- **Модули без состояния**: если View действительно не хранит состояние, допускается простая SwiftUI View, но документировать это отклонение.

#### Пример эффекта с `AppClockDependency`

```swift
@Dependency(\.appClock) var appClock
@Dependency(\.torrentRepository) var repository

private enum CancelID: Hashable {
    case polling
}

case startPolling
case pollingResponse(Result<[Torrent], TorrentRepository.Error>)

return .run { [repository, clock = appClock.clock()] send in
    while true {
        try await clock.sleep(for: .seconds(30))
        let torrents = try await repository.fetchList()
        await send(.pollingResponse(.success(torrents)))
    }
}
.cancellable(id: CancelID.polling, cancelInFlight: true)
```

Каждый `run`-эффект, который сам инициирует асинхронные операции, оборачивается в `.cancellable(id:, cancelInFlight:)` и сохраняет `CancelID` внутри reducer. Важно: `cancelInFlight` уничтожает предыдущие задачи при повторном диспатче (например, при смене фильтра).

#### Тестирование эффектов с таймером
- В `TestStore` замените зависимость: `store.dependencies.appClock = .test(clock: TestClock())`.
- После `store.send(.startPolling)` вызовите `await clock.advance(by: .seconds(30))`, затем `await store.receive(.pollingResponse(.success(...)))`.
- Убедитесь, что `.cancellation` вызывает `store.receive(.cancellation)` (или эквивалентное действие) при `clock.cancel()`/`store.send(.stopPolling)`; если используется `.cancellable`, проверяйте, что отмена выполняется до отправки новых `send`.

#### Чеклист и шаблон
- Новые фичи должны пройти `Templates/FeatureChecklist.md`, где отражены требования по композиции, `.ifLet`, `.run` и отменам.
- Quick checklist в `AGENTS.md` должен ссылаться на шаблон и гайд, чтобы любой разработчик мог быстро найти правила.

### Инфраструктура TestStore и вспомогательных утилит (RTC-60)
- **Цель**: унифицировать создание `TestStore` в Swift Testing, чтобы тесты редьюсеров использовали общие фикстуры и зависимости.
- **Работы**:
  - Создать `RemissionTests/Support/TestStoreFactory.swift` с фабриками `makeAppTestStore`, `makeServerListTestStore` (принимают optional state/action overrides).
  - Инкапсулировать настройку зависимостей (`appDependencies.testDefaults`) и поведение `exhaustivity`.
  - Переписать существующие тесты (`AppFeatureTests`, `ServerListFeatureTests`) на новые фабрики, убедиться в уменьшении boilerplate.
  - Добавить пример использования `TestClock`/`AsyncClock` в одном из тестов (подготовка к M6 polling).
- **Рефакторинг**: удалить дублирующийся код инициализации Store в тестах.

### Примеры и шаблоны мокирования зависимостей (RTC-61)
- **Цель**: показать, как использовать `@Dependency` и override в тестах/превью.
- **Работы**:
  - Подготовить `RemissionTests/Support/DependencyOverrides.swift` с extension `DependencyValues.appPreview()` и примерами `withDependencies`.
  - Добавить в `AppView`/`ServerListView` превью, демонстрирующие мок `CredentialsRepository`, `TransmissionClient`.
  - Обновить `RemissionTests/README.md` (если отсутствует — создать) с инструкциями по override зависимостей в Swift Testing.
  - Протестировать кейсы: happy path с `TransmissionClient.testValue`, error path через `XCTExpectFailure` или `#expect` для ошибки.
- **Артефакты**: документированные примеры override, ссылки из `plan.md` на новые файлы, обновление чек-листа для новых фич (см. раздел "Quick Checklist").

## Веха 5: Онбординг и управление серверами
### Функциональный объём
- M5.1 **OnboardingReducer**: отдельная TCA-фича с `@ObservableState`, `Action`, `Reducer` и `@Presents` для предупреждений HTTP и trust prompts. Состояние хранит форму (`ServerConnectionFormState`), статус проверки (`idle/testing/success/failed`) и контексты сохранения сервера.
- M5.2 **OnboardingView**: SwiftUI форма с `@Bindable` доступом к состоянию редьюсера. Поля: имя, host, port, path, transport (HTTP/HTTPS), allow untrusted, username/password. Кнопка «Проверить подключение» диспатчит `checkConnectionButtonTapped`, «Сохранить сервер» — `connectButtonTapped`.
- M5.3 **Валидация и предупреждения**: обязательный алерт при переходе на HTTP, trust prompt для self-signed сертификатов через `TransmissionTrustPromptCenter`. Ошибки отображаются в секции статуса.
- M5.4 **Сохранение серверов**: успешный онбординг добавляет запись в `ServerConfigRepository`, сохраняет пароль через `CredentialsRepository` и выставляет флаг `onboardingProgressRepository.setCompleted(true)`. ServerListReducer реагирует на `delegate(.didCreate)` и открывает детали сервера.
- M5.5 **Инфраструктура UI-тестов**: приложение читает аргумент `--ui-testing-scenario=onboarding-flow` и подставляет in-memory зависимости (репозитории, Keychain, HTTP warning store, ServerConnectionProbe). Это даёт детерминированный сценарий без файловой системы и Keychain.

### Тестирование и QA
- **Unit**: `RemissionTests/OnboardingFeatureTests.swift` (happy path — сохранение сервера и пароля; error path — таймаут проверки; HTTP предупреждение — отмена возвращает HTTPS). Используется `TestStore` + моковые зависимости.
- **UI**: `RemissionUITests/RemissionUITests.swift::testOnboardingFlowAddsServer` покрывает полный флоу: автозапуск онбординга, заполнение формы, обработка HTTP предупреждения, мок-проверка соединения, сохранение и переход в детали. Есть вспомогательные методы (`clearAndTypeText`, `waitUntil`, скриншоты предупреждений и trust prompt).
- **Документация**: `RemissionTests/README.md` обновлена разделом «Запуск тестов», описывающим новый сценарий и команды. В репозитории хранится `QA_REPORT_RTC66.md` (артефакт проверки вехи: описание сценариев, команды, ссылки на скриншоты/xcresult).

### Проверка готовности
- Запустить локально: `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests`, `swiftlint lint`, затем `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15,OS=26.0' -only-testing:RemissionUITests/RemissionUITests::testOnboardingFlowAddsServer -quiet`.
- Убедиться, что onboarding flow возможен без мануального ввода (тестовая форма) и сервер автоматически открывается в `ServerDetailView` после сохранения.
- QA-скрытие: приложить скриншоты HTTP предупреждения и trust prompt, сохранить лог прогона в Linear.

## Веха 6: Список торрентов

### TCA состояние, действия и зависимости
- `TorrentListReducer.State` включает:
  - `connectionEnvironment: ServerConnectionEnvironment?` — сервер-специфические зависимости (TransmissionClient, TorrentRepository, SessionRepository).
  - `phase: idle/loading/loaded/error`, `isRefreshing`, `isPollingEnabled`, `failedAttempts`, `pollingInterval`, `@Presents var alert`.
  - Коллекцию `items: IdentifiedArrayOf<TorrentListItem.State>`, вычисляемые `visibleItems` (фильтрируются по `searchQuery` и `Filter`, сортируются по `SortOrder`).
  - `searchQuery`, `Filter` (`all/downloading/seeding/errors`), `SortOrder` (`name/progress/downloadSpeed/eta`).
- `Action` покрывает жизненный цикл (`task`, `teardown`), пользовательские действия (`refreshRequested`, `searchQueryChanged`, `filterChanged`, `sortChanged`, `rowTapped`, `addTorrentButtonTapped`), таймер (`pollingTick`), ответы зависимостей (`userPreferencesResponse`, `torrentsResponse`), делегаты (`openTorrent`, `addTorrentRequested`) и `AlertAction`.
- `@Dependency`:
  - `appClock` — планирование polling/backoff.
  - `userPreferencesRepository` — загрузка polling interval и флага автообновления.
  - `torrentRepository` поступает из `connectionEnvironment.apply(to:)`.

### Потоки данных и server-scoped bootstrap
1. `ServerDetailReducer` создаёт `ServerConnectionEnvironment` через `serverConnectionEnvironmentFactory.make(server)` и проверяет рукопожатие с Transmission (`performHandshake`).
2. При успехе `ServerDetailReducer` присваивает окружение себе и вложенному `TorrentListReducer`, затем диспатчит `.torrentList(.task)`.
3. `TorrentListReducer.fetchTorrents` применяет `connectionEnvironment.apply(to: &DependencyValues)` перед вызовом `torrentRepository.fetchList()`.
4. Цепочка: **ServerDetailReducer → TorrentListReducer → TorrentRepository → TransmissionClientDependency → TransmissionClient**. Репозиторий использует `TransmissionDomainMapper` для преобразования RPC → `Torrent`.
5. При ошибке подключения `ServerDetailReducer` диспатчит `.torrentList(.teardown)` и сбрасывает состояние, чтобы предотвратить повторные запросы с устаревшим session-id.
6. `TorrentDetailReducer` получает то же `ServerConnectionEnvironment`, что и список: `ServerDetailReducer` вызывает `State.applyConnectionEnvironment(_:)` при открытии деталей и при обновлении соединения, поэтому дочерняя фича не создаёт новые Transmission-клиенты и использует общие `torrentRepository`/`sessionRepository`.

### Polling, backoff и минимальные RPC поля
- Значения по умолчанию: автообновление включено, интервал 5 секунд (`Duration.seconds(5)`), хранятся в `UserPreferencesRepository`.
- Цикл:
  - `task` → загрузка настроек (`loadPreferences`) → `fetchTorrents(trigger: .initial)`.
  - Успех: `phase = .loaded`, `failedAttempts = 0`, отмена alert, `merge(items:, with:)`, затем `schedulePolling(after: pollingInterval)`.
  - Ошибка: `failedAttempts += 1`, `alert = .networkError`, если список пуст — `phase = .error(message)`, далее `schedulePolling(after: backoffDelay(failures))`.
  - Backoff значения: `[1s, 2s, 4s, 8s, 16s, 30s]` (при большем числе ошибок остаётся на 30s). Manual refresh сбрасывает alert и принудительно ставит `isRefreshing = true`.
- `torrent-get` запрашивает поля из `TorrentListFields.summary`:
  - идентификаторы, имя, статус, `percentDone`, размеры (`totalSize`, `downloadedEver`, `uploadedEver`), скорости (`rateDownload`, `rateUpload`), ETA, лимиты, peers и ratio.
  - Данных достаточно для расчёта `TorrentListItem.Metrics` (progress, скорости, ETA). Mapper обрабатывает значения percentDone как долю (0...1) или проценты (>1) согласно `TransmissionDomainMapper`.

### UI/UX обязательства
- `TorrentListView` (`Remission/Views/TorrentList/TorrentListView.swift`) использует `visibleItems`, покрыт SwiftUI-превью с состояниями loading/empty/error и:
  - отображает прогресс (бар + проценты), черезцветные индикаторы скоростей (`speedSummary` с `↓`/`↑`), статус.
  - предоставляет `searchable(text: $store.searchQuery)` и segmented control с фильтрами; сортировка через `Picker`.
  - пустые состояния:
    - `phase == .loading` → skeleton placeholder.
    - `phase == .loaded && items.isEmpty` → экран «Нет торрентов» + CTA «Добавить торрент».
    - `phase == .error` → сообщение об ошибке и кнопка «Повторить».
- Пользовательское действие «Добавить торрент» пока диспатчит `.delegate(.addTorrentRequested)` и в деталях сервера отображается placeholder alert.

### Тестирование и QA
- Unit: `RemissionTests/TorrentListFeatureTests.swift` покрывает happy path (получение списка, сортировки, polling) и error path (backoff, alerts) через `TestStore` + `TestClock`.
- UI: `RemissionUITests/RemissionUITests.swift::testTorrentListSearchAndRefresh` (iOS). Использует launch-аргументы `--ui-testing-fixture=torrent-list-sample` + `--ui-testing-scenario=torrent-list-sample`; проверяет загрузку фикстурных торрентов, поиск, фильтры, скриншоты. На вехе RTC-77 тест входит в обязательный scope (не переносится на RTC-78).
- Dev tooling: `--ui-testing-fixture=torrent-list-sample` активирует серверную фикстуру при старте приложения (см. `AppBootstrap`). Инструкции и smoke-шаги описаны в `README.md`, `RemissionTests/README.md` и `devdoc/QA_REPORT_RTC70+.md`.

### Проверка готовности
- `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests`
- `swiftlint lint`
- `xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:RemissionTests/TorrentListFeatureTests`
- `xcodebuild test -scheme Remission -testPlan RemissionUITests -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:RemissionUITests/RemissionUITests/testTorrentListSearchAndRefresh`
- QA прогон по инструкции в `devdoc/QA_REPORT_RTC70+.md` с фиксацией скриншотов (`torrent_list_fixture`, `torrent_list_search_result`) и логов `xcodebuild`.

## Веха 7: Детали торрента
- M7.1 Создать TCA-состояние деталей (@ObservableState) с файлами, трекерами, пирами и историей скоростей. Использовать Identifiable для коллекций.
- M7.2 Получать детальные данные через @Dependency repository и отображать их в SwiftUI View с @Bindable для состояния.
- M7.3 Реализовать Actions и Effects для команд: "Запуск", "Пауза", "Удаление", "Проверка", "Изменение приоритета". Каждый Effect должен вызывать repository через @Dependency.
- M7.4 Спроектировать SwiftUI-представление разделов с учетом доступности и VoiceOver (accessibilityIdentifier, accessibilityLabel, accessibilityHint для каждого элемента).
- M7.5 Добавить обработку edge cases (нулевые значения, отсутствующие файлы) согласно PRD.
- Проверка: модульные тесты редьюсера команд с TestStore (happy path + error scenarios) и UI-тест перехода из списка в детали на симуляторе iPhone 12.

### RTC-86: Архитектурная проверка вехи 7 (2025-11-16)
- **TorrentDetailReducer/TorrentDetailView** подтверждены как соответствующие TCA: состояние оформлено через `@ObservableState`, побочные эффекты инкапсулированы в reducer, UI (`Remission/Views/TorrentDetail/*`) только читает Store и не содержит бизнес-логики.
- **Переиспользование окружения**: `ServerDetailReducer` пробрасывает один `ServerConnectionEnvironment` в список и детали (`applyConnectionEnvironment`), что исключает повторное рукопожатие и дублирование клиентов (RTC-84 выполнена).
- **Синхронизация состояний**: делегаты `.torrentUpdated/.torrentRemoved` и флаг `pendingListSync` гарантируют немедленное обновление списка после команд (RTC-85 выполнена, polling/backoff не ломается).
- **Тесты и артефакты**: прогнаны `swift-format lint --recursive --strict`, `swiftlint lint`, `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RemissionTests/TorrentDetailFeatureTests ...` (лог `build/rtc86-ios-selected.log`, xcresult `~/Library/Developer/Xcode/DerivedData/.../Test-Remission-2025.11.16_16-34-00-+0300.xcresult`). Полный `xcodebuild test` требует >10 минут, запуск оставлен для CI/ручного контроля.

### RTC-80: Контракт деталей торрента
- `Torrent.Details.downloadDirectory` — строка пути, может быть пустой если сервер не вернул `downloadDir`.
- `addedDate` — `Date?`; `nil`, когда Transmission ответил без поля `dateAdded` или передал `0`.
- `files`/`trackers`/`trackerStats` — массивы, по умолчанию пустые (маппер не возвращает `nil`). Экран обязан корректно отображать пустые состояния (списки скрываются, показывается stub).
- Файл (`Torrent.File`): `bytesCompleted ∈ [0, length]`, `priority` — целое из {-1, 0, 1}, `wanted` по умолчанию `true`. Если приоритет отсутствует, маппер проставляет `1` (Transmission default).
- Трекер (`Torrent.Tracker`): `tier ≥ 0`, `announce` строка; `id` берётся из `trackers[n].id` или `trackerId`, fallback — `tier`.
- Статистика трекера (`Torrent.TrackerStat`): `downloadCount`, `leecherCount`, `seederCount` ≥ 0. `lastAnnounceResult` — строка статуса (может быть пустой).
- История скоростей (`speedSamples`) пока заполняется клиентом (локальный стор), Transmission не присылает массив — допускаются пустые данные.
- Нулевые/отсутствующие значения из Transmission трактуются как "данные недоступны", маппер и UI не падают: вместо `nil` используются 0/`false`/пустые коллекции, `DomainMappingError` возникает только при структурных ошибках (тип/отсутствие ключа `torrents`).

## Веха 8: Добавление торрента
- M8.1 Реализовать обработчики импорта `.torrent` (FileImporter) и magnet-ссылок (Pasteboard/Share) в TCA действиях.
- M8.2 Добавить TCA-фичу диалога добавления торрента (@Reducer, @ObservableState) с параметрами (путь, старт в паузе, теги).
- M8.3 Интегрировать вызов `torrent-add` через @Dependency repository и обработку ответа Transmission в Effects.
- M8.4 Обновить состояние списка торрентов после успешного добавления через композицию редьюсеров.
- Проверка: модульные тесты редьюсера с TestStore и интеграционный тест с локальным Transmission.

### RTC-91: Архитектурная проверка вехи 8 (2025-11-21)
- **Структура**: UI — `Remission/Views/TorrentAdd`, фича — `Remission/Features/TorrentAdd` (папка переименована с `AddTorrent` под схему). При необходимости обновить группы в проекте.
- **Переиспользование окружения**: `AddTorrentReducer` применяет `ServerConnectionEnvironment` через `environment.apply(...)`; дополнительных рукопожатий/креденшлов не создаёт. Навигация и алерты используют `@Presents` и делегаты без утечек состояния.
- **Тесты**: Добавлены error-pathы для добавления торрента (sessionConflict, mapping error, отсутствие connectionEnvironment) и импортов (ошибка magnet, ошибка открытия/парсинга .torrent). Покрыто 14 тестов суммарно в `AddTorrentFeatureTests` и `ServerDetailImportTests`.
- **Запуск**: `xcodebuild test -scheme Remission -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RemissionTests/AddTorrentFeatureTests -only-testing:RemissionTests/ServerDetailImportTests` (лог: `~/Library/Developer/Xcode/DerivedData/Remission-hizssvkjniurwvggbezcsopugcdl/Logs/Test/Test-Remission-2025.11.21_02-46-56-+0300.xcresult`). Результат: PASS, 14 тестов.

## Веха 9: Настройки и предпочтения
- M9.1 Реализовать и интегрировать SettingsReducer/SettingsView в AppFeature через @Presents sheet (TCA, @ObservableState, effects через @Dependency).
- M9.2 Версионировать `UserPreferences` (поле `version`, `currentVersion`), готовить миграции; live/in-memory сторожи должны всегда писать актуальную версию.
- M9.3 Стабилизировать polling: гарантировать первичный fetch после коннекта (ServerDetail → TorrentList) и единый helper для рестарта polling при смене настроек.
- M9.4 UI/QA: добавить XCUITest для настроек (персистентность между запусками, smoke редактирования) на iOS и macOS; обеспечить accessibility identifiers.
- Проверка: unit-тесты Settings/TorrentList/ServerDetail reducers, UI-тесты Settings (персистентность + smoke), актуальные команды xcodebuild и ссылки на xcresult в отчёте.

## Веха 10: Логирование и телеметрия
- M10.1 Интегрировать `swift-log` (Swift.org official) с согласованными уровнями логирования (debug, info, warning, error) через @Dependency Logger.
- M10.2 Сохранять сетевые и RPC-ошибки с контекстной метаинформацией. **КРИТИЧЕСКИ**: никогда не логировать пароли, usernames, токены или sensitive данные.
- M10.3 Добавить опциональный переключатель отправки телеметрии (по умолчанию отключен) в настройках с явным согласием пользователя.
  - Использовать `TelemetryConsentDependency` для гейта телеметрических отправок:
    ```swift
    @Dependency(\.telemetryConsent) var telemetryConsent
    @Dependency(\.appLogger) var logger

    func send(event: TelemetryEvent) async {
        guard (try? await telemetryConsent.isTelemetryEnabled()) == true else {
            logger.debug("Telemetry disabled, skip \(event.name)")
            return
        }
        await emitter.send(event)
    }

    func observeConsentChanges() -> AsyncStream<Bool> {
        telemetryConsent.observeTelemetryEnabled()
    }
    ```
  - Миграции `UserPreferences` ставят `isTelemetryEnabled = false` по умолчанию; все отправки должны проверять флаг.
- M10.4 Подготовить гайд по чтению логов и диагностике для пользователей в документации — см. [LOGGING_GUIDE.md](LOGGING_GUIDE.md).
- M10.5 Добавить экран диагностики в UI для просмотра последних логов (для разработчиков и support).
- M12.3 Экран диагностики (Settings → «Диагностика»): поток логов из DiagnosticsReducer/View с фильтрацией по уровню и тексту, подсветкой офлайн/сетевых ошибок, копированием записи, ограничением последних N элементов (500 по умолчанию).
- Архитектура диагностики: кольцевой буфер (`DiagnosticsLogBuffer` actor) вместо `DispatchQueue` для гарантии последовательности и потокобезопасности; дихотомия `load + observe` нужна для моментального снапшота и потоковых обновлений; фильтрация выполняется в actor и при генерации UI, чтобы исключить гонки при смене фильтров.
- Проверка: модульные тесты форматирования логов с использованием Swift Testing @Test и ручная проверка поведения переключателя. Убедиться, что credentials никогда не логируются.

### QA справка по логам и телеметрии (RTC-101)
- Гайд: [LOGGING_GUIDE.md](LOGGING_GUIDE.md) (включение расширенного логирования, пути логов для iOS/macOS, правила безопасности, телеметрия off по умолчанию).
- Минимальный набор шагов: включить расширенное логирование только на время воспроизведения, собрать zip из каталога `Logs`, убедиться в отсутствии секретов, приложить к отчёту; переключатель телеметрии — Settings → «Отправлять анонимную телеметрию» (по умолчанию выключено).

## Веха 11: Локализация и доступность
- M11.1 Вынести пользовательские строки через String Catalog `Localizable.xcstrings` и добавить базовую локализацию на русском языке.
- M11.2 Подготовить англоязычную локализацию (en) и проверить плейсхолдеры.
- M11.3 Провести аудит экранов на VoiceOver (accessibilityIdentifier, accessibilityLabel, accessibilityHint), Dynamic Type и контрастность.
- M11.4 Настроить автоматические проверки отсутствующих строк в сборке через скрипты — выполнено: `Scripts/check-localizations.sh` + Xcode Run Script phase **Localizations Check** (падает сборка при пропущенных переводах или несоответствии плейсхолдеров).
- Проверка: предпросмотр локализаций в Xcode, UI-тест в EN-локали и аудит с VoiceOver.

## Веха 12: Устойчивость к офлайн-режиму и ошибкам
- M12.1 Реализовать поведение при потере сети в TCA Effects: кеш состояния и экспоненциальный повтор запросов.
- M12.2 Отображать понятные баннеры ошибок и дать возможность повторить действие через SwiftUI AlertState (TCA).
- M12.3 Добавить экран диагностики для последних ошибок и логов через TCA-фичу.
- M12.4 Согласовать политику хранения и очистки кеша в @Dependency services.
- Проверка: модульные тесты офлайн-сценариев с TestStore и UI-тест отображения баннеров.

## Веха 13: Интеграционные испытания Transmission
- M13.1 Подготовить docker-compose сценарий для локального запуска Transmission 3.0+ с известной конфигурацией (rpc-port, auth).
- M13.2 Добавить интеграционные тесты (Swift Testing @Test) для критических сценариев: подключение, добавление torrent, запуск, пауза, удаление. Проверка совместимости с RPC версией через `session-get`.
- M13.3 Автоматизировать поднятие и остановку Transmission через скрипт разработчика (bin/setup-docker.sh или аналогичный).
- M13.4 Обеспечить обработку edge cases: timeout, rate-limiting (429), несовместимые версии API, пустые ответы согласно PRD.
- M13.5 Сохранять логи и артефакты интеграционных тестов для анализа в CI.
- Проверка: успешный локальный прогон интеграционного сценария с сохраненными артефактами. Все критические пути должны пройти без ошибок.

## Веха 14: Готовность к релизу
- M14.1 Обновить документацию (README, CONTRIBUTING, AGENTS, PRD, plan.md) с актуальными процессами, требованиями Context7, ссылками на инструменты и примерами из актуальной версии.
- M14.2 Сформировать CHANGELOG с фиксацией выполненных требований PRD, версионированием и описанием миграций State структур.
- M14.3 Провести исследовательское тестирование билдов macOS и iOS с актуальными инструментами (swift-format, swiftlint, Xcode 15.0+, Swift 6.0).
- M14.4 Составить чек-лист для публикации (сертификаты, профили, метаданные App Store, локализация RU/EN, иконки, скриншоты).
- M14.5 Убедиться, что покрытие тестами >= 60% на ключевых компонентах (используя xcov или Xcode Code Coverage).
- M14.6 Запустить финальный набор тестов: unit (Swift Testing), integration (Transmission docker), UI (XCUITest) на iOS Simulator и macOS.
- Проверка: подтверждения от разработчиков, QA и PM. Успешная сборка архивов для публикации с прогоном всех тестов без ошибок и новых предупреждений.
