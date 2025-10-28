# План внедрения Remission

**Быстрые ссылки на документацию**:
- 📚 [CONTEXT7_GUIDE.md](CONTEXT7_GUIDE.md) — Как исследовать документацию через Context7
- 📖 [TRANSMISSION_RPC_REFERENCE.md](TRANSMISSION_RPC_REFERENCE.md) — Справочник по Transmission RPC API
 - 📑 [TRANSMISSION_RPC_METHOD_MATRIX.md](TRANSMISSION_RPC_METHOD_MATRIX.md) — Матрица методов/полей для MVP
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
     -destination 'platform=iOS Simulator,name=iPhone 15' \
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

### Модульность и декомпозиция TCA
- **Разделение слоёв**: UI (`Views`), бизнес-логика (`Features`/редьюсеры), модели (`Models`) и инфраструктура (`DependencyClients`) оформляются отдельными таргетами/файлами. Ссылайтесь на [SwiftUI+TCA Template](https://github.com/ethanhuang13/swiftui-tca-template) как эталон.
- **Структура зависимостей**: определения `@DependencyClient` и тестовых значений живут в `Remission/DependencyClients`, live-реализации и фабрики — в `Remission/DependencyClientLive`. Любые новые клиенты повторяют эту схему, чтобы тесты и прод-код использовали единый источник.
- **Компоновка редьюсеров**: долгие/многофункциональные редьюсеры делятся с помощью `Scope`, `.ifLet`, `Reducer.forEach`. Навигация оформляется через отдельные `Destination`/`Path` редьюсеры (см. [TCA TreeBasedNavigation](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TreeBasedNavigation.md)).
- **Парсинг и инфраструктура**: вспомогательные парсеры и клиенты не размещаем в редьюсере. Выносите в отдельные структуры/сервисы (`TransmissionClient`, `TorrentDetailParser`) и инжектируйте через зависимости.
- **TorrentDetailParser (2025-10-23)**: парсер вынесен в `Remission/TorrentDetailParser.swift` и предоставляет dependency `@Dependency(\.torrentDetailParser)`. Возвращается `TorrentDetailParsedSnapshot` — структура с опциональными scalar-полями (`name`, `status`, `uploadRatio` и т. д.) и коллекциями (`files`, `trackers`, `trackerStats`, `peersFrom`). Это позволяет редьюсеру применять только присутствующие значения через `state.apply(snapshot)` и избегать сброса предшествующих данных. Внутренние ошибки (`TorrentDetailParserError.missingTorrentData`) маппятся в `errorMessage` редьюсера, что покрыто тестом `detailsLoadedParserFailure`.
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
- **Правила обновления** описаны в `RemissionTests/Fixtures/README.md` (структура, формат, smoke-tests).

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

## Веха 3: Доменное ядро
- M3.1 Описать доменные модели Torrent, ServerConfig и SessionState.
- M3.2 Настроить преобразование DTO Transmission RPC в доменные модели с валидацией полей.
- M3.3 Определить протоколы репозиториев для торрентов, сессий и настроек.
- M3.4 Подготовить заглушки репозиториев для тестов UI и TCA.
- Проверка: модульные тесты репозиториев с моками TransmissionClient.

## Веха 4: Инфраструктура TCA
- M4.1 Подготовить общие утилиты (абстракции времени через swift-clocks, контейнер зависимостей через @Dependency, Environment setup).
- M4.2 Определить типы AppState (@ObservableState), AppAction и приватные Reducers с @Reducer. Документировать версионирование State структур для миграций.
- M4.3 Описать в документации принципы композиции редьюсеров и обработки эффектов через `.run { send in ... }` блоки. Все побочные эффекты должны быть инкапсулированы через Environment.
- M4.4 Настроить TestStore и вспомогательные методы для тестирования редьюсеров с использованием Swift Testing (@Test). Каждый редьюсер должен иметь хотя бы happy path и error path тесты.
- M4.5 Добавить примеры использования @Dependency для мокирования services и repositories в тестах.
- Проверка: модульные тесты базовых редьюсеров с использованием Swift Testing @Test и TestStore с mock зависимостями.

## Веха 5: Онбординг и управление серверами
- M5.1 Создать TCA-фичу онбординга (@Reducer с @ObservableState State, Action).
- M5.2 Реализовать SwiftUI-экраны ввода host, port, протокола и учетных данных используя @Bindable для состояния.
- M5.3 Добавить проверку соединения и отображение статуса пользователю через асинхронные эффекты в редьюсере.
- M5.4 Сохранить конфигурации серверов и реализовать редактирование и удаление.
- Проверка: сквозной UI-тест онбординга и модульные тесты редьюсера с TestStore.

## Веха 6: Список торрентов
- M6.1 Описать TCA-состояние списка (@ObservableState: элементы как IdentifiedArray, фильтры, сортировка, флаги загрузки) и действия через enum Action.
- M6.2 Реализовать вызовы `torrent-get` с настраиваемым набором полей через @Dependency repository. Обработка ошибок и exponential backoff через Effects.
- M6.3 Построить SwiftUI-список с индикаторами прогресса, скоростей и статуса. Использовать @Bindable для state.
- M6.4 Добавить поиск, элементы сортировки и жест pull-to-refresh, связав их с Actions в reducer.
- M6.5 Настроить периодический опрос через Task и swift-clocks для детерминированного тестирования с конфигурируемым интервалом.
- M6.6 Покрыть редьюсер тестами Swift Testing: happy path, error scenarios, retry logic с использованием TestStore.
- Проверка: модульные тесты редьюсера с TestStore (успех, ошибка, отмена) и UI-тест отображения списка на симуляторе iPhone 12.

## Веха 7: Детали торрента
- M7.1 Создать TCA-состояние деталей (@ObservableState) с файлами, трекерами, пирами и историей скоростей. Использовать Identifiable для коллекций.
- M7.2 Получать детальные данные через @Dependency repository и отображать их в SwiftUI View с @Bindable для состояния.
- M7.3 Реализовать Actions и Effects для команд: "Запуск", "Пауза", "Удаление", "Проверка", "Изменение приоритета". Каждый Effect должен вызывать repository через @Dependency.
- M7.4 Спроектировать SwiftUI-представление разделов с учетом доступности и VoiceOver (accessibilityIdentifier, accessibilityLabel, accessibilityHint для каждого элемента).
- M7.5 Добавить обработку edge cases (нулевые значения, отсутствующие файлы) согласно PRD.
- Проверка: модульные тесты редьюсера команд с TestStore (happy path + error scenarios) и UI-тест перехода из списка в детали на симуляторе iPhone 12.

## Веха 8: Добавление торрента
- M8.1 Реализовать обработчики импорта `.torrent` (FileImporter) и magnet-ссылок (Pasteboard/Share) в TCA действиях.
- M8.2 Добавить TCA-фичу диалога добавления торрента (@Reducer, @ObservableState) с параметрами (путь, старт в паузе, теги).
- M8.3 Интегрировать вызов `torrent-add` через @Dependency repository и обработку ответа Transmission в Effects.
- M8.4 Обновить состояние списка торрентов после успешного добавления через композицию редьюсеров.
- Проверка: модульные тесты редьюсера с TestStore и интеграционный тест с локальным Transmission.

## Веха 9: Настройки и предпочтения
- M9.1 Реализовать TCA-состояние настроек (@ObservableState) для интервала опроса, автообновления и лимитов по умолчанию.
- M9.2 Сохранить предпочтения в UserDefaults или выделенном хранилище через @Dependency.
- M9.3 Создать SwiftUI-контролы с группировкой настроек и описаниями, используя @Bindable.
- M9.4 Обновить редьюсеры зависимых фич для чтения выбранных настроек через @Dependency.
- Проверка: модульные тесты сохранения и чтения настроек с TestStore и UI-тест изменения значений с проверкой персистентности.

## Веха 10: Логирование и телеметрия
- M10.1 Интегрировать `swift-log` (Swift.org official) с согласованными уровнями логирования (debug, info, warning, error) через @Dependency Logger.
- M10.2 Сохранять сетевые и RPC-ошибки с контекстной метаинформацией. **КРИТИЧЕСКИ**: никогда не логировать пароли, usernames, токены или sensitive данные.
- M10.3 Добавить опциональный переключатель отправки телеметрии (по умолчанию отключен) в настройках с явным согласием пользователя.
- M10.4 Подготовить гайд по чтению логов и диагностике для пользователей в документации.
- M10.5 Добавить экран диагностики в UI для просмотра последних логов (для разработчиков и support).
- Проверка: модульные тесты форматирования логов с использованием Swift Testing @Test и ручная проверка поведения переключателя. Убедиться, что credentials никогда не логируются.

## Веха 11: Локализация и доступность
- M11.1 Вынести пользовательские строки через Localizable.strings и добавить базовую локализацию на русском языке.
- M11.2 Подготовить англоязычную локализацию (en) и проверить плейсхолдеры.
- M11.3 Провести аудит экранов на VoiceOver (accessibilityIdentifier, accessibilityLabel, accessibilityHint), Dynamic Type и контрастность.
- M11.4 Настроить автоматические проверки отсутствующих строк в сборке через скрипты.
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
