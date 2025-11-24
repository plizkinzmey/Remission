# Transmission RPC Fixtures

Эта папка содержит JSON-фикстуры ответов Transmission RPC, которые используются
в Swift Testing сценариях (RTC-31, RTC-32) и при настройке `TransmissionMockServer`.
Файлы повторяют реальные ответы daemon'a и помогают тестам оставаться
детерминированными без обращения к живому Transmission.

## Структура

```
RemissionTests/Fixtures/
├── Transmission/
│   ├── Session/        # Ответы session-get/session-stats
│   ├── Torrents/       # Ответы torrent-get/add/start/stop/remove/set/verify
│   └── Errors/         # Общие error-case ответы (rate limit, auth, invalid JSON)
└── README.md
```

- Название файла построено по шаблону `<method>.<scenario>.json`.
- При необходимости дополнительной группировки используйте поддиректории.

## Правила обновления

1. **Источник истины** — официальные спецификации и выдержки из
   `devdoc/TRANSMISSION_RPC_REFERENCE.md`. Перед добавлением новых данных
   убедитесь, что структура полей совпадает с контрактом.
2. **Не обрезайте поля, которые покрываются тестами.** Если поле
   используется в `TorrentDetailParser` или будущих проверках — сохраните его.
3. **Секреты не храним.** Используйте вымышленные значения (`hashString`,
   `downloadDir` и т.д.).
4. После добавления фикстуры выполните smoke-тесты загрузки:

   ```bash
   xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e'
   ```

5. При расширении набора обязательно обновите список в `TransmissionFixtureName`
   (см. `TransmissionFixture.swift`) и добавьте покрывающий тест в
   `TransmissionFixturesTests`.

## Быстрый старт в тестах

```swift
let response = try TransmissionFixture.response(.sessionGetSuccessRPC17)
```

- Для мок-сервера: `TransmissionMockResponsePlan.fixture(.torrentGetSingleActive)`.
- Для негативных сценариев используйте `TransmissionFixture.data` и проверяйте
  обработку ошибок вручную.

## Checklist перед PR

- [ ] Файл попал в правильную папку и название отражает сценарий.
- [ ] README обновления не требуются (или обновлены).
- [ ] Добавлены smoke-тесты или обновлены существующие.
- [ ] В Linear комментарии указаны ссылки на источники и новую фикстуру.
