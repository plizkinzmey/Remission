# QA Report — RTC-70+

Документ фиксирует smoke-сценарии QA для фич вехи M6 (список торрентов) и связанных улучшений. Все шаги воспроизводимы без дополнительных устных пояснений.

## Цели

- Подтвердить корректность `TorrentListReducer` (polling, поиск, фильтры, сортировки).
- Проверить UI-уровень (`TorrentListView`) на iOS Simulator с фикстурными данными.
- Убедиться, что документация и launch-аргументы позволяют QA/разработчикам локально воспроизвести результаты.

## Подготовка окружения

1. Установить инструменты качества: `brew install swift-format swiftlint xcbeautify`.
2. Синхронизировать зависимости Xcode, убедиться, что выбран `Xcode 15+/Swift 6`.
3. Очистить предыдущие установки приложения (опционально): `xcrun simctl uninstall booted com.remission.app`.
4. Собрать фикстурные данные: никаких дополнительных действий не требуется — `--ui-testing-fixture=torrent-list-sample` создаёт in-memory `TorrentRepository` и окружение.

## Команды проверки

```bash
# 1. Unit (редьюсер списка торрентов)
xcodebuild test \
  -scheme Remission \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RemissionTests/TorrentListFeatureTests \
  | xcbeautify

# 2. UI smoke списка торрентов (фикстура torrent-list)
xcodebuild test \
  -scheme Remission \
  -testPlan RemissionUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:RemissionUITests/RemissionUITests/testTorrentListSearchAndRefresh \
  | tee build/torrent-list-ui.log | xcbeautify
```

> **Важно:** перед запуском UI-теста убедитесь, что в схеме или Runner'е установлены launch-аргументы `--ui-testing-fixture=torrent-list-sample --ui-testing-scenario=torrent-list-sample`. В CLI можно использовать `xcodebuild test ... -test-arguments "<args>"` или предварительно отредактировать схему.

## Smoke-сценарий: список торрентов

| Шаг | Действие | Ожидаемый результат |
| --- | --- | --- |
| 1 | Запустить приложение с аргументами `--ui-testing-fixture=torrent-list-sample --ui-testing-scenario=torrent-list-sample` | В списке серверов отображается элемент `torrent_list_fixture_server` |
| 2 | Открыть сервер | Раздел «Торренты» появляется в течение 2 секунд; три торрента видимы: «Ubuntu 25.04 Desktop», «Fedora 41 Workstation», «Arch Linux Snapshot» |
| 3 | Проверить статусы | `Ubuntu` — статус Downloading, прогресс ~75%; `Fedora` — Seeding, прогресс 100%; `Arch` — Ошибка/Paused (status=isolated) |
| 4 | Проверить скорости | Каждый ряд отображает `speedSummary` с `↓` и `↑`. Для Ubuntu присутствует `↓ 12.4 MB/s` (значение из фикстуры), остальные — `0 KB/s` |
| 5 | Выполнить поиск `Fedora` | В списке остаётся только «Fedora 41 Workstation», остальные элементы скрыты (появляется пустой state внутри `.visibleItems`) |
| 6 | Очистить поиск, потянуть refresh | Стейт `isRefreshing` показывает прогресс; после ответа данные не меняются, `failedAttempts = 0` |
| 7 | Принудительно завершить `TransmissionClient` (опционально) | Через debug menu `Network` → `Simulate Failure` → получить `alert` «Не удалось обновить список торрентов», после backoff повторная попытка выполняется через 1-2 секунды |

## Логи и артефакты

- Скриншоты: `torrent_list_fixture.png`, `torrent_list_search_result.png` (автогенерация UI-теста).
- Лог `build/torrent-list-ui.log` прикладывается к Linear тикету (RTC-73).
- В случае падений — приложить `build/TestResults/Remission.xcresult`.

## Связанные файлы

- `Remission/Features/TorrentList/TorrentListFeature.swift`
- `Remission/Views/TorrentList/TorrentListView.swift`
- `Remission/TorrentRepository.swift` + `Remission/Domain/TorrentListFields.swift`
- `RemissionUITests/RemissionUITests.swift::testTorrentListSearchAndRefresh`
- Документация: `devdoc/plan.md` (раздел «Веха 6») и `devdoc/PRD.md` (раздел «Список торрентов»), `README.md` (тесты + troubleshooting), `RemissionTests/README.md`
