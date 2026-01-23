# Анализ дублирования кода и возможности рефакторинга (Часть 7)

Анализ проведен: Пятница, 23 января 2026 г.

Седьмой этап анализа был сфокусирован на элементах дизайн-системы и устранении избыточных состояний в процессе инициализации приложения.

## 1. Дублирование визуальных компонентов тегов (Pills) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Shared/AppTagView.swift` (новый)
- `Remission/Views/TorrentList/Cells/TorrentRowView.swift`

**Решение:**
- Создан универсальный компонент `AppTagView` для отображения плашек (тегов, статусов, категорий).
- `TorrentRowView` переведен на использование этого компонента, удален локальный хелпер `pillLabel`.

## 2. Разрозненные константы дизайна (Spacing/Radius) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Views/Shared/AppTheme.swift` (расширен)
- `Remission/Views/Shared/AppChrome.swift`

**Решение:**
- В `AppTheme` добавлены перечисления `Radius` (card, modal, pill) и `Spacing` (small, standard, large, section).
- Модификатор `appCardSurface` обновлен для использования `AppTheme.Radius.card` по умолчанию.

## 3. Дублирование флагов состояния загрузки (Bootstrapping) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/App/AppFeature.swift`
- `Remission/Features/ServerList/ServerListFeature.swift`
- `Remission/App/AppBootstrap.swift`

**Решение:**
- Удалены избыточные флаги `hasLoadedServersOnce` и `shouldLoadServersFromRepository`.
- Внедрен флаг `isPreloaded` в `ServerListReducer.State`, который устанавливается фикстурами в `AppBootstrap`.
- Логика `.task` в `ServerListReducer` упрощена: загрузка из репозитория происходит только если данные не были предзагружены.
- Удален метод `markServersAsLoaded` из `AppBootstrap`, так как он вмешивался в ответственности редьюсеров.

## 4. Консистентный бойлерплейт в репозиториях
**Статус:** Оставлено как стандарт проекта. Текущая архитектура на основе замыканий (closure-based structs) признана оптимальной для обеспечения тестируемости и гибкости.