# Feature Checklist

Перед стартом любой новой TCA-фичи выполните базовую проверку архитектуры.

## Структура и композиция
- [ ] Прописан `@ObservableState State`, `enum Action` и `@Reducer`.
- [ ] Корневой редьюсер делегирует состояние через `Scope`/`forEach` и поддерживает делегатные действия (см. `AppFeature.swift`, `ServerListReducer.swift`).
- [ ] Презентации (`alerts`, `sheets`) реализованы через `@Presents` и оборачиваются в `.ifLet(state:action:)`.

## Эффекты и отмены
- [ ] Все `.run`-эффекты берут зависимости через `@Dependency` (например, `appClock`, `torrentRepository`).
- [ ] Эффекты понимают `.cancellation(id:)` или `.cancellable`, и каждый поток/таймер имеет уникальный `CancelID`.
- [ ] В тестах используется `TestClock`/`TestStore` для проверки `sleep`, повторных `send` и отмены.

## Документация и коммуникация
- [ ] При необходимости обновлены документы:
  - `/Users/plizkinzmey/SRC/Remission/AGENTS.md`
  - `/Users/plizkinzmey/SRC/Remission/Doc/ProjectMap.md`
- [ ] В описание PR/задачи добавлены ссылки на ключевые файлы (reducers/views) и тесты.
