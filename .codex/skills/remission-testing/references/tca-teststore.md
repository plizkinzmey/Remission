# TCA TestStore (Remission)

## Базовый шаблон reducer-теста
```swift
import ComposableArchitecture
import Testing

@testable import Remission

@Suite("Feature Tests")
@MainActor
struct FeatureTests {
    @Test("Happy path")
    func happyPath() async {
        let clock = TestClock()
        let store = TestStoreFactory.makeTestStore(
            initialState: Feature.State(...)
        ) {
            Feature()
        } configure: {
            $0.appClock = .test(clock: clock)
        }

        await store.send(.task) {
            // state mutations
        }

        await store.receive(\.response.success) {
            // state mutations
        }

        await store.send(.teardown)
        await store.finish()
    }
}
```

## Поллинг, таймеры и backoff
1. Используй `TestClock`.
2. Сначала `await store.receive(...)` на ответ эффекта.
3. Затем `await clock.advance(by: ...)`.
4. Потом `await store.receive(.pollingTick)`.
5. В конце обязательно `await store.send(.teardown)`.

## Ожидание действий от эффектов
- Предпочитай `store.receive(...)` вместо «просто проверить state».
- Если эффект шлёт несколько действий, принимай их по порядку.

## Две обязательные ветки
Для каждого reducer минимум:
1. Happy path.
2. Error path (ошибка зависимости, offline, alert/banner).

