# Анализ дублирования кода и возможности рефакторинга (Часть 8)

Анализ проведен: Пятница, 23 января 2026 г.

Восьмой этап анализа сосредоточен на идиоматичности кода (Swift/TCA) и устранении семантического дублирования в ресурсах локализации.

## 1. Избыточный поиск индекса в IdentifiedArray — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Features/ServerList/ServerListFeature.swift`
- `Remission/App/AppFeature.swift`

**Решение:**
- Удален ручной поиск индексов через `index(id:)`.
- Внедрено идиоматичное использование сабскрипта: `state.servers[id: server.id] = server`.

## 2. Семантическое дублирование в Localizable.xcstrings — **ВЫПОЛНЕНО**
**Локация:** `Remission/Localizable.xcstrings`

**Решение:**
- Проведена консолидация строк во всем проекте.
- Ключи `onboarding.action.cancel`, `torrentAdd.action.cancel` и другие заменены на единый `common.cancel`.
- `AlertFactory` теперь использует `common.delete` и `common.cancel` по умолчанию.

## 3. Ручное слияние списков в TorrentList — **ВЫПОЛНЕНО**
**Локация:** `Remission/Features/TorrentList/TorrentListFeature+Helpers.swift`

**Решение:**
- Метод `merge` переписан с использованием функциональных возможностей `IdentifiedArray`.
- Добавлено автоматическое удаление отсутствующих элементов через `removeAll(where:)`.

## 4. Дублирование логики расчета StorageSummary — **ВЫПОЛНЕНО**
**Локация:** `Remission/Shared/StorageSummary.swift`

**Решение:**
- В структуру `StorageSummary` добавлен статический метод `calculate(torrents:session:updatedAt:)`.
- Из редьюсеров `ServerList` и `TorrentList` удалены локальные реализации этого расчета.