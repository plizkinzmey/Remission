# Анализ дублирования кода и возможности рефакторинга (Часть 3)

Анализ проведен: Пятница, 23 января 2026 г.

Третий этап анализа был сосредоточен на глубоких архитектурных повторах в логике представления (Views), реализации моков (InMemory Repositories) и системных сервисах (Logging).

## 1. Дублирование структуры секций в деталях торрента — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Views/TorrentDetail/TorrentDetailView+Sections.swift`
- `Remission/Views/TorrentDetail/TorrentDetailSection.swift` (новый)

**Решение:**
- Создан универсальный компонент `TorrentDetailSection`, объединяющий логику `DisclosureGroup`, отображение пустых состояний (`EmptyPlaceholderView`) и индикаторов загрузки.
- Секции Файлы, Трекеры и Пиры переведены на использование этого компонента. Из дочерних вьюх удалена избыточная логика контейнеров (`showsContainer`).

## 2. Повторяющаяся логика ошибок в InMemory репозиториях — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Repositories/InMemoryFailureTracker.swift` (новый)
- `Remission/Repositories/InMemoryTorrentRepository.swift`
- `Remission/Repositories/InMemorySessionRepository.swift`
- `Remission/Repositories/InMemoryUserPreferencesRepository.swift`

**Решение:**
- Создан общий актор `InMemoryFailureTracker`, который централизует отслеживание и симуляцию ошибок операций.
- Все InMemory репозитории переиспользовали этот трекер, что устранило идентичные блоки кода во внутренних сторах.

## 3. Разрозненная логика маскирования данных (Logging) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Shared/DataMasker.swift` (новый)
- `Remission/Logging/TransmissionLogger.swift`
- `Remission/Logging/CredentialsAuditLogger.swift`

**Решение:**
- Создана утилита `DataMasker` для централизованного маскирования паролей, токенов и заголовков аутентификации.
- Логгеры обновлены для использования этой утилиты, что гарантирует единый стандарт безопасности.

## 4. Дублирование стилей текста и чисел в SwiftUI — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Views/Shared/AppChrome.swift` (расширение)
- `Remission/Views/TorrentList/Cells/TorrentRowView.swift`
- `Remission/Views/TorrentDetail/TorrentFilesView.swift` и др.

**Решение:**
- В `View` добавлены расширения `.appCaption()` и `.appMonospacedDigit()`.
- Основные вьюхи обновлены для использования этих декларативных стилей вместо ручной настройки шрифтов и цветов.

## 5. Ручное создание алертов в AddTorrentFeature — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Shared/AlertFactory.swift` (расширен)
- `Remission/Features/TorrentAdd/AddTorrentReducer+Submit.swift`

**Решение:**
- `AlertFactory` расширен методами для специфичных алертов добавления торрентов (дубликаты, ошибки соединения).
- `AddTorrentReducer` переведен на использование фабрики, удалены локальные хелперы создания алертов.