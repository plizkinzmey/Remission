# Анализ дублирования кода и возможности рефакторинга (Часть 2)

Анализ проведен: Пятница, 23 января 2026 г.

После устранения основных архитектурных дубликатов, был проведен повторный анализ для выявления более тонких проблем, связанных с представлением данных и логикой UI.

## 1. Дублирование форматтеров (Скорость и ETA) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Features/TorrentList/TorrentListItem.swift`
- `Remission/Views/TorrentDetail/TorrentDetailFormatters.swift`
- `Remission/Shared/Formatters/TorrentDataFormatter.swift` (новый)

**Решение:**
- Создан унифицированный `TorrentDataFormatter`, который централизует логику форматирования байтов, скорости, ETA и прогресса.
- Все существующие компоненты переведены на использование этого форматера.

## 2. Ручное создание алертов подтверждения — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Features/ServerDetail/ServerDetailFeature.swift`
- `Remission/Features/ServerList/ServerListFeature.swift`
- `Remission/Shared/AlertFactory.swift` (новый)

**Решение:**
- Создана фабрика `AlertFactory` для генерации стандартных алертов и диалогов подтверждения (удаление, инфо-алерты).
- Удален повторяющийся код создания алертов в редьюсерах.

## 3. Монолитные View-файлы (TorrentRow) — **ВЫПОЛНЕНО**
**Локация:** `Remission/Views/TorrentList/TorrentListView.swift`
**Новая локация:** `Remission/Views/TorrentList/Cells/`

**Решение:**
- `TorrentRowView`, `TorrentRowBackgroundView` и `TorrentRowSkeletonView` вынесены в отдельные файлы в директории `Cells`.
- Основной файл списка стал чище и проще для навигации.

## 4. Дублирование логики форматирования размеров (Storage) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Views/Shared/StorageFormatters.swift`
- `Remission/Shared/Formatters/TorrentDataFormatter.swift`

**Решение:**
- Логика форматирования размеров консолидирована в `TorrentDataFormatter.bytes`. `StorageFormatters` теперь делегирует выполнение общему форматору.