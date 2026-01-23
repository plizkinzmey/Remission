# Анализ дублирования кода и возможности рефакторинга (Часть 4)

Анализ проведен: Пятница, 23 января 2026 г.

Четвертый этап анализа выявил дублирование в инфраструктурных механизмах (повторные попытки, задержки) и в способах обработки ошибок между различными фичами.

## 1. Идентичная логика экспоненциальной задержки (Backoff) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Shared/BackoffStrategy.swift` (новый)
- `Remission/Features/TorrentList/TorrentListFeature+Helpers.swift`
- `Remission/Features/ServerDetail/ServerDetailFeature.swift`

**Решение:**
- Создана утилита `BackoffStrategy`, централизующая массив задержек `[1, 2, 4, 8, 16, 30]`.
- Дублирующиеся методы в фичах заменены на вызов общей стратегии.

## 2. Разрозненное преобразование ошибок в текст (Error Description) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Shared/ErrorPresenter.swift` (расширение)
- `Remission/Features/ServerList/ServerListFeature.swift`
- `Remission/Features/ServerDetail/ServerDetailFeature.swift`
- `Remission/Features/TorrentList/TorrentListFeature+Helpers.swift`

**Решение:**
- Добавлено расширение `Error.userFacingMessage`, которое единообразно извлекает описание ошибки из `LocalizedError` или `NSError`.
- Локальные методы `describe(_:)` во всех редьюсерах переведены на использование этого расширения.

## 3. Дублирование логики формирования URL и протоколов — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Domain/ServerConfig.swift`

**Решение:**
- Логика формирования `connectionFingerprint` вынесена напрямую в модель `ServerConfig`.
- Удалены избыточные расширения из файлов фич.

## 4. Шаблонный код в SwiftUI Previews
**Локации:** По всему проекту (`*View.swift`).

**Проблема:**
Настройка превью часто требует создания больших структур зависимостей через `AppDependencies.makePreview()`.

**Статус:** Решено оставить как есть для сохранения гибкости настройки каждого превью, так как объем дублирования не критичен по сравнению с инфраструктурным кодом.