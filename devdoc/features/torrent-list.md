# Torrent List

## Назначение
Экран списка торрентов для выбранного сервера: загрузка данных, polling, фильтры, поиск и команды (start/pause/verify/remove).

## Где смотреть в коде
- Reducer: `Remission/Features/TorrentList/TorrentListFeature.swift`
- Команды и загрузка: `Remission/Features/TorrentList/TorrentListReducer+Commands.swift`
- Хелперы и polling/backoff: `Remission/Features/TorrentList/TorrentListFeature+Helpers.swift`
- View: `Remission/Views/TorrentList/TorrentListView.swift`
- Toolbar (macOS): `Remission/Views/TorrentList/TorrentListView+Toolbar.swift`
- Тесты: `RemissionTests/TorrentListFeatureTests.swift`

## Ключевой пользовательский сценарий
1. Экран появляется.
2. Загружаются пользовательские настройки (polling interval, auto-refresh).
3. Выполняется загрузка торрентов.
4. При успехе запускается polling.
5. Пользователь применяет поиск/фильтры и отправляет команды.

## Что делает reducer
Reducer — это источник истины состояния экрана. Он:
- Грузит настройки и подписывается на их изменения (`.task`).
- Запускает ручной refresh (`.refreshRequested`).
- Обрабатывает команды и после них триггерит refresh (`.commandResponse` → `.commandRefreshRequested`).
- Переводит экран в offline при ошибках и планирует retry с backoff (`.torrentsResponse(.failure)`).

## Жизненный цикл загрузки и polling
- `.task` запускает:
  - `loadPreferences(serverID:)`
  - `observePreferences(serverID:)`
- После успешной загрузки торрентов:
  - состояние очищает ошибки,
  - `failedAttempts` сбрасывается в `0`,
  - планируется следующий polling через `schedulePolling(after:)`.
- При ошибке загрузки:
  - `failedAttempts += 1`,
  - экран переводится в offline,
  - если не достигнут лимит попыток, планируется retry через `backoffDelay(for:)`.

## Backoff и зачем он нужен
При повторных ошибках reducer не должен «долбить» сервер. Поэтому retry делается с задержкой:
- задержка растёт по экспоненте,
- есть верхний предел,
- это снижает нагрузку и повышает стабильность.

Реализация backoff:
- `backoffDelay(for:)` в `TorrentListFeature+Helpers.swift`
- таблица задержек в `Remission/Shared/BackoffStrategy.swift`

## Команды и удаление
Удаление — двухшаговый процесс:
1. `.removeTapped(id)` поднимает confirmation dialog.
2. `.removeConfirmation(.presented(.deleteWithData/.deleteTorrentOnly))`:
  - помечает торрент как «удаляется»,
  - вызывает `performCommand(.remove(...))`,
  - по успеху делает refresh.

Важно: команды выполняются через `connectionEnvironment.withDependencies { ... }`, а не напрямую через глобальные зависимости.

## Зависимости
Reducer напрямую использует:
- `appClock` — для polling и backoff.
- `userPreferencesRepository` — настройки polling/auto-refresh.
- `offlineCacheRepository` — offline snapshot.

Сетевые операции и команды идут через:
- `ServerConnectionEnvironment` → `withDependencies`
- внутри него: `torrentRepository`, `sessionRepository`

## Типичные ловушки при изменениях
- Если в тестах использовать `connectionEnvironment: .previewValue`, он может перетереть замоканные зависимости.
- Любые новые долгоживущие эффекты нужно корректно отменять через `CancelID`.
- Если меняется пользовательский сценарий (flow), нужно обновить `devdoc/PRD.md`.

