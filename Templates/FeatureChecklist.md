# Feature Checklist

Перед стартом любой новой TCA-фичи выполните базовую проверку архитектуры.

## Структура и композиция
- [ ] Прописан `@ObservableState State`, `enum Action` и `@Reducer`.
- [ ] Корневой редьюсер делегирует состояние через `Scope`/`forEach` и поддерживает делегатные действия (см. `AppFeature.swift`, `ServerListReducer.swift`).
- [ ] Презентации (`alerts`, `sheets`) реализованы через `@Presents` и оборачиваются в `.ifLet(state:action:)`.

## Эффекты и отмены
- [ ] Все `.run`-эффекты берут зависимости через `@Dependency` (например, `appClock`, `torrentRepository`) и описаны в `devdoc/plan.md` разделе «Документация композиции редьюсеров и эффектов (RTC-59)».
- [ ] Эффекты понимают `.cancellation(id:)` или `.cancellable`, и каждый поток/таймер имеет уникальный `CancelID`.
- [ ] В тестах используется `TestClock`/`TestStore` для проверки `sleep`, повторных `send` и отмены.

## Документация и коммуникация
- [ ] Ссылка на гайд RTC-59 добавлена в описание Linear-задачи/PR.
- [ ] AGENTS Quick Checklist обновлён и содержит ссылку на этот шаблон (`Templates/FeatureChecklist.md`).
- [ ] При необходимости добавлены примеры в `devdoc/plan.md` (ссылки на файлы с примером композиции и эффекта).
