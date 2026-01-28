# Pure & Mapper Tests

## Когда применять
- Утилиты без зависимостей (`BackoffStrategy`, форматтеры, нормализация путей).
- Маппинг RPC → доменная модель через `TransmissionDomainMapper`.

## Паттерн для «чистых» функций
Используй параметризованные тесты таблицей вход → ожидание.

```swift
import Testing
@testable import Remission

@Suite("Backoff Strategy Tests")
struct BackoffStrategyTests {
    @Test("Delay table", arguments: [
        (0, Duration.seconds(1)),
        (1, Duration.seconds(1)),
        (2, Duration.seconds(2)),
        (6, Duration.seconds(30)),
        (99, Duration.seconds(30)),
    ])
    func delayTable(input: (failures: Int, expected: Duration)) {
        #expect(BackoffStrategy.delay(for: input.failures) == input.expected)
    }
}
```

## Паттерн для мапперов
1. Подготовь фикстуру.
2. Вызови mapper.
3. Проверь критичные поля.
4. Добавь error-path (битые данные/неподдерживаемый формат).

## Что не делать
- Не разбирай `AnyCodable` в тестах фич напрямую: используй mapper.
- Не полагайся на «магические» значения времени — контролируй их явно.

