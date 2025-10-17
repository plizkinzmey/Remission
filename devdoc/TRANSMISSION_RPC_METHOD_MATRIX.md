# Transmission RPC — Матрица методов и полей (MVP)

Этот документ фиксирует матрицу основных методов Transmission RPC, их параметры запроса, поля ответа и примечания. Используется как основной справочник при реализации клиента и тестов.

Важные оговорки:
- Формат Transmission RPC — собственный, НЕ JSON-RPC 2.0. Поля: method, arguments, tag. Ответ: result ("success" или строка-ошибка), arguments, tag.
- Минимальная поддерживаемая версия Transmission: 3.0. Рекомендуется: 4.0+.
- Аутентификация: Basic Auth + X-Transmission-Session-Id (409 → повтор с новым session-id).
- Полный справочник и контекст см. в `devdoc/TRANSMISSION_RPC_REFERENCE.md`.

## Таблица методов

| Method | Request Fields (обязательные/опциональные) | Response Fields | Notes |
|---|---|---|---|
| session-get | — | arguments: session object (version, rpc-version, rpc-version-minimum, download-dir, speed-limit-*, alt-speed-*, blocklist-*) | Вызывать в рукопожатии для проверки версии и базовой конфигурации.
| session-set | settings object: speed-limit-up (opt), speed-limit-up-enabled (opt), speed-limit-down (opt), speed-limit-down-enabled (opt), download-dir (opt), alt-speed-*, blocklist-enabled и др. | — | Изменяет параметры сессии. Передавать только те ключи, которые нужно изменить.
| torrent-get | arguments: fields [string] (req — для оптимизации), ids (opt: number | string(hash) | [..]) | arguments: torrents [object] (только запрошенные поля), removed [id]? | Главный метод списка. Рекомендуется минимальный набор полей для UI-первого экрана.
| torrent-add | filename (URL / magnet) ИЛИ metainfo (base64) (req), download-dir (opt), paused (opt), labels (opt) | arguments: { "torrent-added": {id, name, hashString} } ИЛИ { "torrent-duplicate": {id, name, hashString} } | Если торрент уже существует, возвращается torrent-duplicate.
| torrent-start | ids (req) | — | Запускает один или несколько торрентов.
| torrent-stop | ids (req) | — | Останавливает один или несколько торрентов.
| torrent-remove | ids (req), delete-local-data (opt, bool) | — | При delete-local-data=true удаляются данные с диска.
| torrent-verify | ids (req) | — | Запускает проверку файлов. Долгая операция; статус читать через torrent-get.

## Рекомендуемые поля

### Для списка (torrent-get → fields)

Минимум для UI (список):
- id (Int), name (String), status (Int 0-7), percentDone (Double 0.0-1.0)
- rateDownload (Int, bytes/sec), rateUpload (Int, bytes/sec)
- uploadRatio (Double), peersConnected (Int)
- downloadDir (String)

Детали (при открытии карточки):
- totalSize, downloadedEver, uploadedEver, eta
- files (Array), trackers (Array), trackerStats (Array)

### Для session-get (versioning/handshake)
- version (String, например "4.0.6")
- rpc-version (Int), rpc-version-minimum (Int)
- download-dir, speed-limit-*

## Примеры запросов/ответов

### session-get

Запрос:
```json
{
  "method": "session-get",
  "arguments": {},
  "tag": 1
}
```

Ответ (успех):
```json
{
  "result": "success",
  "arguments": {
    "version": "4.0.6",
    "rpc-version": 17,
    "rpc-version-minimum": 14,
    "download-dir": "/downloads",
    "speed-limit-down-enabled": false,
    "speed-limit-up-enabled": false
  },
  "tag": 1
}
```

### session-set

Запрос (включить лимиты):
```json
{
  "method": "session-set",
  "arguments": {
    "speed-limit-down-enabled": true,
    "speed-limit-down": 1024,
    "speed-limit-up-enabled": true,
    "speed-limit-up": 256
  },
  "tag": 2
}
```

Ответ (успех):
```json
{ "result": "success", "tag": 2 }
```

### torrent-get

Запрос (минимальные поля для списка):
```json
{
  "method": "torrent-get",
  "arguments": {
    "fields": [
      "id", "name", "status", "percentDone",
      "rateDownload", "rateUpload", "uploadRatio",
      "peersConnected", "downloadDir"
    ]
  },
  "tag": 3
}
```

Ответ (успех, один элемент):
```json
{
  "result": "success",
  "arguments": {
    "torrents": [
      {
        "id": 1,
        "name": "Ubuntu",
        "status": 4,
        "percentDone": 0.75,
        "rateDownload": 102400,
        "rateUpload": 5120,
        "uploadRatio": 1.2,
        "peersConnected": 12,
        "downloadDir": "/downloads"
      }
    ]
  },
  "tag": 3
}
```

### torrent-add

Запрос (magnet):
```json
{
  "method": "torrent-add",
  "arguments": {
    "filename": "magnet:?xt=urn:btih:...",
    "download-dir": "/downloads",
    "paused": false
  },
  "tag": 4
}
```

Ответ (добавлен):
```json
{
  "result": "success",
  "arguments": {
    "torrent-added": { "id": 2, "name": "Some Torrent", "hashString": "abcd..." }
  },
  "tag": 4
}
```

Ответ (дубликат):
```json
{
  "result": "success",
  "arguments": {
    "torrent-duplicate": { "id": 1, "name": "Ubuntu", "hashString": "ef12..." }
  },
  "tag": 4
}
```

### torrent-start

Запрос:
```json
{ "method": "torrent-start", "arguments": { "ids": [1,2,3] }, "tag": 5 }
```
Ответ:
```json
{ "result": "success", "tag": 5 }
```

### torrent-stop

Запрос:
```json
{ "method": "torrent-stop", "arguments": { "ids": [1,2,3] }, "tag": 6 }
```
Ответ:
```json
{ "result": "success", "tag": 6 }
```

### torrent-remove

Запрос (с удалением данных):
```json
{
  "method": "torrent-remove",
  "arguments": { "ids": [2], "delete-local-data": true },
  "tag": 7
}
```
Ответ:
```json
{ "result": "success", "tag": 7 }
```

### torrent-verify

Запрос:
```json
{ "method": "torrent-verify", "arguments": { "ids": [1] }, "tag": 8 }
```
Ответ:
```json
{ "result": "success", "tag": 8 }
```

## Версионность и зависимости

- Все методы в таблице доступны начиная с Transmission 3.0. 
- Набор поддерживаемых полей для torrent-get может зависеть от rpc-version. При несовместимых версиях — деградируйте до меньшего набора полей.
- Рекомендуется вызывать session-get при первом подключении и кэшировать версию/параметры.

## Edge cases

- HTTP 409 (Session ID): кешируйте новый X-Transmission-Session-Id и повторяйте исходный запрос.
- Ошибки как строки: result != "success" содержит строку-описание. Отображайте пользователю безопасное сообщение.
- Большие списки: ограничивайте fields и используйте периодический опрос с backoff.

## Ссылки
- Основной справочник: `devdoc/TRANSMISSION_RPC_REFERENCE.md`
- Контракт/план: `devdoc/plan.md` (раздел "Transmission RPC API контракт")
