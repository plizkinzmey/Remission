# Руководство по инвалидации кеша офлайн-данных

Цель: описать, когда и как очищается/переинициализируется кеш офлайн-снимков, чтобы поведение было прозрачным для команды и диагностируемым.

## Ключи и хранение
- **Ключ**: `OfflineCacheKey(serverID, cacheFingerprint, rpcVersion?)`, где `cacheFingerprint = host:port:transport:username#credentialsFingerprint`.
- **credentialsFingerprint**: SHA-256 от `accountIdentifier:password`; для анонимных соединений — `anonymous`.
- **Размещение**: файловый кеш в `Application Support/Remission/Snapshots` (per server JSON, max 5 МБ), TTL 30 минут.
- **Содержимое**: снапшоты торрентов и сессии (`CachedSnapshot` с `updatedAt`).

## Точки инвалидации
- Смена учётных данных (новый пароль/логин) → новый fingerprint, старый кеш очищается при несоответствии ключа.
- Смена RPC-версии (handshake) → cacheKey обновляется; кеш с несовпадающей версией сбрасывается как miss.
- Удаление сервера → `offlineCacheRepository.clear(serverID)`.
- Ошибка несовместимости версии Transmission (`APIError.versionUnsupported`) → явная очистка.
- Ошибка чтения/десериализации файла → файл удаляется, ошибка логируется.
- Превышение лимита размера (5 МБ) при записи → кеш очищается и обновление не сохраняется.
- Истечение TTL (30 минут) → при чтении снапшот помечается устаревшим и удаляется.

## Использование кеша
- Чтение: при старте/офлайне `TorrentListReducer` и `SessionRepository` пробуют `load()` → hit → показываем данные офлайн.
- Запись: успешные `torrent-get`/`session-get` сохраняют снимки.
- Очистка: при удалении сервера, ошибке несовместимости версии или несоответствии ключа/версии.

## Диагностика
- Категория логов: `offline-cache` (hit/miss/expired/invalidated/store/clear/evict-size).
- Для UI-тестов и preview логирование отключено.

## Batch-инвалидация
- `OfflineCacheRepository.clearMultiple([UUID])` — массовая очистка кеша для списка серверов (использовать при массовом удалении или миграциях).

## Тестирование
- Unit: `OfflineCacheRepositoryTests` покрывает TTL и несовпадение RPC версии.
- Рекомендация: добавить сценарии на очистку при превышении размера и на batch-инвалидацию в случае массовых операций.
