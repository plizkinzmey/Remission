# Модели Transmission RPC (DTO и APIError)

В проекте определены следующие типы для работы с Transmission RPC. Все модели — `Codable` и `Sendable`, что позволяет безопасно использовать их в асинхронном контексте.

**Быстрые ссылки**:
- 📚 [Transmission RPC Reference](TRANSMISSION_RPC_REFERENCE.md) — Полный справочник API
- 📑 [Transmission RPC Method Matrix](TRANSMISSION_RPC_METHOD_MATRIX.md) — Таблица методов и полей
- 📋 [План разработки](plan.md) — Общая архитектура и этапы

---

## 1. TransmissionRequest

Представляет исходящий RPC запрос. Структура содержит метод, параметры и опциональный тег для корреляции.

### Определение

```swift
public struct TransmissionRequest: Codable, Sendable {
    public let method: String              // Имя метода RPC
    public let arguments: AnyCodable?      // Параметры метода
    public let tag: TransmissionTag?       // Опциональный тег для корреляции
}
```

**Файл**: `Remission/TransmissionRequest.swift`

### Примеры использования

#### Получить список торрентов

```swift
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
```

#### Установить лимиты скоростей

```swift
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

#### Добавить торрент

```swift
let addTorrentRequest = TransmissionRequest(
    method: "torrent-add",
    arguments: AnyCodable.object([
        "filename": .string("magnet:?xt=urn:btih:..."),
        "download-dir": .string("/downloads"),
        "paused": .bool(true)
    ]),
    tag: .int(3)
)
```

### JSON после сериализации

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

---

## 2. TransmissionResponse

Представляет входящий RPC ответ от сервера. Содержит статус результата, данные ответа и тег для корреляции.

### Определение

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

**Файл**: `Remission/TransmissionResponse.swift`

### Примеры ответов

#### Успешный ответ (torrent-get)

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

#### Ответ об ошибке

```json
{
  "result": "too many recent requests",
  "tag": 1
}
```

#### Успешный ответ без данных (torrent-start)

```json
{
  "result": "success",
  "tag": 2
}
```

### Обработка в коде

```swift
let decoder = JSONDecoder()
let response = try decoder.decode(TransmissionResponse.self, from: data)

if response.isSuccess {
    // Обработать успешный ответ
    if let torrents = response.arguments?.object?["torrents"]?.array {
        // Распарсить список торрентов
        for torrentData in torrents {
            if case .object(let torrentDict) = torrentData,
               case .int(let id) = torrentDict["id"],
               case .string(let name) = torrentDict["name"] {
                print("Torrent: \(id) - \(name)")
            }
        }
    }
} else {
    // Обработать ошибку
    let errorMsg = response.errorMessage ?? "Unknown error"
    throw APIError.mapTransmissionError(errorMsg)
}
```

### Вспомогательные методы

```swift
// Проверить успех
if response.isSuccess {
    // Процесс данные из response.arguments
}

// Получить сообщение об ошибке
if let error = response.errorMessage {
    print("Error: \(error)")
}

// Коррелировать с запросом по тегу
if case .int(let tagValue) = response.tag {
    // Найти соответствующий запрос по tagValue
}
```

---

## 3. AnyCodable

Тип-erasure для представления любого JSON-совместимого значения. Используется для гибкого декодирования `arguments` поля, которое может содержать различные структуры данных.

### Определение

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

**Файл**: `Remission/AnyCodable.swift`

### Примеры создания значений

```swift
// Простые значения
let nullValue = AnyCodable.null
let boolValue = AnyCodable.bool(true)
let intValue = AnyCodable.int(42)
let doubleValue = AnyCodable.double(3.14)
let stringValue = AnyCodable.string("example")

// Массивы
let arrayValue = AnyCodable.array([
    .int(1),
    .int(2),
    .int(3)
])

let mixedArray = AnyCodable.array([
    .string("name"),
    .int(42),
    .bool(true)
])

// Объекты
let objectValue = AnyCodable.object([
    "method": .string("torrent-get"),
    "tag": .int(1)
])

let nestedObject = AnyCodable.object([
    "arguments": .object([
        "ids": .array([.int(1), .int(2)]),
        "fields": .array([
            .string("id"),
            .string("name")
        ])
    ])
])
```

### Доступ к значениям

```swift
// Pattern matching для простых значений
if case .string(let value) = anyCodable {
    print("String: \(value)")
}

if case .int(let value) = anyCodable {
    print("Integer: \(value)")
}

// Работа с массивами
if case .array(let items) = anyCodable {
    for item in items {
        // Обработать каждый элемент
    }
}

// Работа с объектами
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

// Опциональный доступ через вспомогательные методы
// (если добавить их в расширение)
let name = response.arguments?.object?["name"]?.string
let speed = response.arguments?.object?["speed"]?.int
```

### Достоинства

- ✅ Позволяет парсить JSON без знания точной структуры на этапе компиляции
- ✅ Поддерживает рекурсивные объекты и массивы произвольной глубины
- ✅ Полностью совместим с Swift `Codable` протоколом
- ✅ Thread-safe благодаря `Sendable` conformance
- ✅ Нет необходимости в дополнительных зависимостях

### Когда использовать

- При парсинге Transmission RPC ответов с переменной структурой
- Когда структура JSON известна только во время выполнения
- Для хранения динамических данных в `arguments` поле
- При необходимости обрабатывать разные методы API с разными типами ответов

---

## 4. TransmissionTag

Перечисление, которое представляет тег запроса/ответа. Transmission RPC поддерживает теги как целые числа, так и строки.

### Определение

```swift
@frozen
public enum TransmissionTag: Sendable {
    case int(Int)
    case string(String)
}
```

**Файл**: `Remission/TransmissionTag.swift`

### Примеры использования

#### Создание тегов

```swift
// Числовой тег
let numericTag = TransmissionTag.int(1)

// Строковый тег
let stringTag = TransmissionTag.string("request-123")

// UUID строковый тег
let uuidTag = TransmissionTag.string(UUID().uuidString)
```

#### Использование в запросе

```swift
let request = TransmissionRequest(
    method: "torrent-get",
    arguments: nil,
    tag: .int(1)
)

let anotherRequest = TransmissionRequest(
    method: "session-get",
    arguments: nil,
    tag: .string("session-check-\(Date().timeIntervalSince1970)")
)
```

#### Соответствие в ответе

```swift
let response = try decoder.decode(TransmissionResponse.self, from: data)

if case .int(let tagValue) = response.tag {
    print("Numeric tag: \(tagValue)")
    // Найти соответствующий запрос в очереди по tagValue
} else if case .string(let tagValue) = response.tag {
    print("String tag: \(tagValue)")
    // Найти соответствующий запрос по string ID
}
```

#### Корреляция запросов и ответов

```swift
// Хранить запросы в очереди с их тегами
var pendingRequests: [String: TransmissionRequest] = [:]

func sendRequest(_ request: TransmissionRequest) throws {
    let tagKey: String
    if case .int(let value) = request.tag ?? .int(0) {
        tagKey = "req-\(value)"
    } else if case .string(let value) = request.tag ?? .string("") {
        tagKey = value
    } else {
        tagKey = UUID().uuidString
    }
    
    pendingRequests[tagKey] = request
    try sendToServer(request)
}

func handleResponse(_ response: TransmissionResponse) {
    let tagKey: String
    if let tag = response.tag {
        if case .int(let value) = tag {
            tagKey = "req-\(value)"
        } else if case .string(let value) = tag {
            tagKey = value
        } else {
            return
        }
    } else {
        return
    }
    
    if let originalRequest = pendingRequests.removeValue(forKey: tagKey) {
        // Обработать ответ, зная оригинальный запрос
        print("Response to \(originalRequest.method): \(response.result)")
    }
}
```

### Зачем нужны теги

- 🏷️ Позволяет коррелировать асинхронные запросы с их ответами
- 🔄 Поддерживает параллельные запросы к одному серверу
- 🛡️ Помогает идентифицировать ответ на конкретный метод
- 📊 Поддерживает оба формата тегов (числовые и строковые) из разных версий Transmission

### Примечание о сериализации

```json
// При использовании .int(1)
{"method": "torrent-get", "tag": 1}

// При использовании .string("req-1")
{"method": "torrent-get", "tag": "req-1"}

// В ответе сервер повторяет тот же тип
{"result": "success", "tag": 1}
или
{"result": "success", "tag": "req-1"}
```

---

## 5. APIError

Перечисление ошибок для представления всех типов сбоев при работе с Transmission RPC.

### Определение

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

**Файл**: `Remission/APIError.swift`

### Маппинг HTTP статус кодов

| HTTP Code | APIError | Действие |
|-----------|----------|----------|
| 401 | `unauthorized` | Проверить Basic Auth заголовок, запросить пароль заново |
| 409 | `sessionConflict` | Кешировать новый `X-Transmission-Session-Id` из заголовка, повторить запрос |
| 400 | `unknown(details:)` | Проверить формат JSON запроса |
| Other | `unknown(details:)` | Обработать как неизвестная ошибка |
| Network error | `networkUnavailable` | Проверить соединение, использовать exponential backoff |

### Маппинг ошибок Transmission RPC

Transmission RPC возвращает ошибки как строки в `result` поле:

```swift
// Версионные ошибки
if errorString.contains("version") || errorString.contains("rpc-version") {
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

### Примеры использования

#### Обработка в try-catch

```swift
do {
    let response = try makeRPCCall(request)
    
    if response.isError {
        let error = APIError.mapTransmissionError(response.result)
        throw error
    }
    
    // Обработать успешный ответ
    print("Success: \(response.arguments)")
    
} catch APIError.networkUnavailable {
    showAlert("No network connection. Please check your internet.")
    
} catch APIError.unauthorized {
    showAlert("Authentication failed. Please check your credentials.")
    // Запросить логин заново
    
} catch APIError.sessionConflict {
    // Система должна автоматически восстановить session и повторить запрос
    logger.info("Session conflict detected, refreshing session...")
    refreshSessionAndRetry()
    
} catch APIError.versionUnsupported(let version) {
    showAlert("Transmission version \(version) is not supported. Please upgrade to 3.0+")
    
} catch APIError.decodingFailed(let error) {
    logger.error("Failed to decode response: \(error)")
    showAlert("Server returned invalid data")
    
} catch APIError.unknown(let details) {
    logger.error("Unknown error: \(details)")
    showAlert("An unexpected error occurred: \(details)")
}
```

#### Использование с Result

```swift
func fetchTorrents(server: ServerConfig) async -> Result<[Torrent], APIError> {
    do {
        let request = TransmissionRequest(
            method: "torrent-get",
            arguments: /* ... */
        )
        let response = try await client.call(request)
        
        guard response.isSuccess else {
            let error = APIError.mapTransmissionError(response.result)
            return .failure(error)
        }
        
        let torrents = try parseTorrents(from: response.arguments)
        return .success(torrents)
        
    } catch let error as APIError {
        return .failure(error)
    } catch {
        return .failure(.unknown(details: error.localizedDescription))
    }
}
```

#### Восстановление от ошибок с retry

```swift
func callWithRetry(
    _ request: TransmissionRequest,
    maxAttempts: Int = 3
) async throws -> TransmissionResponse {
    var lastError: APIError?
    
    for attempt in 1...maxAttempts {
        do {
            return try await client.call(request)
        } catch APIError.sessionConflict {
            // Восстановить session и повторить
            try await refreshSession()
            if attempt < maxAttempts {
                continue
            }
        } catch APIError.networkUnavailable {
            // Exponential backoff
            let delay = UInt64((1 << (attempt - 1)) * 1_000_000_000) // 1s, 2s, 4s
            try await Task.sleep(nanoseconds: delay)
            if attempt < maxAttempts {
                continue
            }
        } catch {
            throw error
        }
    }
    
    throw lastError ?? APIError.unknown(details: "Max retries exceeded")
}
```

### Логирование ошибок

⚠️ **ВАЖНО**: Никогда не логируйте пароли, usernames, токены или другие sensitive данные!

```swift
// ❌ НЕПРАВИЛЬНО
logger.error("Auth failed for user: \(username) password: \(password)")

// ✅ ПРАВИЛЬНО
logger.error("Authentication failed (HTTP 401)")

// ✅ ПРАВИЛЬНО
logger.error("Session conflict detected, refreshing session...")

// ✅ ПРАВИЛЬНО
logger.debug("RPC call: \(request.method) with \(request.arguments?.description ?? "no args")")
```

---

## Расширение моделей в будущем

### Добавление новых полей к DTO

При появлении новых методов Transmission, добавить соответствующие `Codable` типы:

```swift
/// Расширение: поддержка torrent-verify status
public struct TorrentVerifyStatus: Codable, Sendable {
    public let id: Int
    public let verifyProgress: Double // 0.0 до 1.0
    
    enum CodingKeys: String, CodingKey {
        case id
        case verifyProgress = "verify-progress"
    }
}

// Использование в arguments как часть AnyCodable
let verifyResponse = try decoder.decode(TransmissionResponse.self, from: data)
if let statusData = verifyResponse.arguments?.object?["status"] {
    // Парсить статус проверки как AnyCodable
}
```

### Добавление поддержки новых типов ошибок

```swift
// Расширить APIError новым кейсом
extension APIError {
    // Добавить новый случай ошибки
    case rateLimitExceeded(retryAfter: Int?)
}

// Обновить маппинг
public nonisolated static func mapTransmissionError(_ errorString: String) -> APIError {
    let lowerErrorString = errorString.lowercased()
    
    // Добавить новую проверку
    if lowerErrorString.contains("too many") || lowerErrorString.contains("rate limit") {
        return .rateLimitExceeded(retryAfter: nil)
    }
    
    // ... существующие проверки
}
```

### Версионирование структур

При изменении структуры DTO:

1. Проверить совместимость с RPC версией через `session-get`
2. Использовать `CodingKeys` для маппинга устаревших полей
3. Документировать поддерживаемые версии в комментариях

```swift
public struct TorrentInfo: Codable, Sendable {
    /// Уникальный идентификатор торрента (доступен во всех версиях)
    public let id: Int
    
    /// Имя торрента (доступно во всех версиях)
    public let name: String
    
    /// Процент готовности (доступно в Transmission 2.0+)
    public let percentDone: Double
    
    /// Новое поле, добавленное в Transmission 4.0
    /// Может быть nil при подключении к старым версиям
    public let seedIdleMinutes: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case percentDone = "percent-done"
        case seedIdleMinutes = "seed-idle-minutes"
    }
}
```

---

## Примечания и best practices

### Безопасность

- 🔒 Никогда не логируйте пароли, usernames или токены
- 🔒 Используйте маскирование при логировании HTTP заголовков
- 🔒 Проверяйте сертификаты при использовании HTTPS
- 🔒 Храните session-id безопасно, не в UserDefaults

### Производительность

- ⚡ Используйте `AnyCodable` только где необходимо
- ⚡ Для часто используемых структур создавайте специализированные Codable типы
- ⚡ Кешируйте session-id для избежания лишних handshake запросов
- ⚡ Используйте `ids` параметр при torrent-get для большых списков

### Тестирование

- 🧪 Mock `AnyCodable` значения при unit тестировании
- 🧪 Тестируйте обработку всех кейсов `APIError`
- 🧪 Используйте Swift Testing фреймворк с `@Test` атрибутом
- 🧪 Проверяйте маппинг ошибок для каждого типа ошибки

### Совместимость

- 🔄 Поддерживайте Transmission 3.0+ как минимум
- 🔄 Проверяйте версию через `session-get` при подключении
- 🔄 Используйте динамическое определение поддерживаемых полей
- 🔄 Документируйте требования версии для каждого метода
