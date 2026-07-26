# Remission: JSON-RPC 2.0 Fallback Tests (Stage 2)

Date: 2026-06-22
Branch: feature/stage-2-json-rpc-fallback-tests

## Что найдено в production-коде

### Архитектура RPC modes

`TransmissionClient` поддерживает три режима (`TransmissionRPCMode`):
- `.legacy` — Transmission RPC legacy envelope (`{"method": "...", "arguments": {...}, "tag": 1}`)
- `.jsonRpc2` — JSON-RPC 2.0 envelope (`{"jsonrpc": "2.0", "method": "...", "params": {...}, "id": 1}`)
- `.auto` — автоматический выбор режима

### Flow auto mode (`initialModesToTry()`)

```
config.rpcMode == .auto, нет resolved mode → [.legacy, .jsonRpc2]
config.rpcMode == .auto, есть resolved mode → [resolved]
config.rpcMode != .auto → [config.rpcMode]
```

**Ключевой момент**: в auto mode legacy пробуется ПЕРВЫМ, JSON-RPC 2.0 — вторым.

### Fallback logic (`sendRequestWithRetry()`)

Fallback от JSON-RPC 2.0 к legacy срабатывает при:
1. Текущий режим — `.jsonRpc2`
2. Есть ещё режимы для попытки (`modeIndex + 1 < modesToTry.count`)
3. Ошибка соответствует `fallbackReasonFromJSONRPC()`

`fallbackReasonFromJSONRPC()` определяет fallback при:
- `.decodingFailed` с сигналами: "missing result in json-rpc response", "unsupported jsonrpc version", "invalid json-rpc response"
- `.unknown` с "method not found" или "json-rpc"

### Обнаруженная проблема

**Fallback от JSON-RPC 2.0 к legacy НЕ работает в auto mode.**

Причина: в auto mode `modesToTry = [.legacy, .jsonRpc2]`. Когда `.jsonRpc2` находится на индексе 1 (последний), проверка `modeIndex + 1 < modesToTry.count` всегда `false` (2 < 2 = false).

Дополнительно: auto mode пробует legacy первым. Если legacy падает с ошибкой декодирования, fallback на JSON-RPC 2.0 не происходит, потому что проверка `mode == .jsonRpc2` не проходит (режим — `.legacy`).

Существующие тесты `TransmissionClientRPCModeTests` (`autoModeFallsBackAndCachesLegacy`, `autoModeDoesNotFallbackOnJSONRPCBusinessError`) **не проходят** из-за этой проблемы.

## Какие тесты добавлены

### New file: `TransmissionClientJSONRPCFallbackTests.swift`

| Test | What it verifies |
|---|---|
| `autoModeSendsLegacyFirst` | Auto mode отправляет legacy envelope первым, не JSON-RPC 2.0 |
| `missingResultTriggersFallbackReason` | Отсутствие result в JSON-RPC response детектируется как fallback reason |
| `unsupportedVersionTriggersFallbackReason` | Неподдерживаемая версия jsonrpc детектируется как fallback reason |
| `explicitJsonRpc2SendsCorrectEnvelope` | Явный JSON-RPC 2.0 режим отправляет правильный envelope |
| `explicitJsonRpc2NoFallbackOnBusinessError` | Явный JSON-RPC 2.0 не делает fallback при business error |
| `autoModePersistsLegacyMode` | Auto mode сохраняет legacy режим после успешного запроса |
| `explicitJsonRpc2DoesNotPersist` | Явный JSON-RPC 2.0 режим НЕ сохраняется в rpcModeStore (только auto) |
| `autoModeLegacyFailureThrowsWithoutFallback` | Auto mode: ошибка legacy бросается без fallback на JSON-RPC 2.0 |
| `sessionIDPreservedAcrossModeAttempts` | Session ID сохраняется при fallback между режимами |
| `jsonRpc2RequestBodyStructure` | JSON-RPC 2.0 request body содержит jsonrpc, snake_case method, params, id |
| `legacyRequestBodyStructure` | Legacy request body содержит method без jsonrpc поля |
| `missingResultDetected` | Fallback reason детектирует отсутствие result |
| `invalidShapeDetected` | Fallback reason детектирует невалидную форму JSON-RPC response |
| `businessErrorNotFallback` | Business error НЕ триггерит fallback reason |

## Какие сценарии покрыты

1. Auto mode ordering — legacy first
2. Fallback reason detection — 4 сигнала
3. Mode persistence — legacy и JSON-RPC 2.0
4. Session ID preservation across mode attempts
5. Request body structure — оба формата
6. Business error не триггерит fallback
7. Auto mode: legacy failure throws без fallback

## Какие сценарии не покрыты

| Scenario | Why not covered | What's needed |
|---|---|---|
| Actual fallback from JSON-RPC 2.0 to legacy | Broken in production code — `modeIndex + 1 < modesToTry.count` always false for last element | Fix `initialModesToTry()` to return `[.jsonRpc2, .legacy]` |
| Auto mode: JSON-RPC 2.0 failure → legacy fallback | Same root cause — auto mode tries legacy first, not JSON-RPC 2.0 | Same fix as above |
| Fallback + 409 handshake interaction | Requires mock that returns 409 during mode transition | Enhance MockURLProtocol for multi-phase scenarios |

## Почему не покрыты

1. **Actual fallback is broken** — production code имеет bug в `initialModesToTry()`: auto mode возвращает `[.legacy, .jsonRpc2]`, но fallback check `modeIndex + 1 < modesToTry.count` всегда false для последнего элемента. Тесты для fallback Cannot work until this is fixed.

2. **Auto mode tries legacy first** — даже если fallback check работал бы, auto mode сначала отправляет legacy. Если legacy падает с decoding error, это НЕ является fallback reason для JSON-RPC 2.0.

## Какие файлы изменены

| File | Change |
|---|---|
| `RemissionTests/TransmissionClientJSONRPCFallbackTests.swift` | New file — 14 tests |
| `Doc/TransmissionJSONRPCFallbackTests.md` | New file — this document |

## Результаты проверок

| Check | Result | Notes |
|---|---|---|
| Xcode build (macOS) | ✅ BUILD SUCCEEDED | 0 errors |
| New tests | ✅ 14/14 pass | macOS CLI, 0.021s |
| Existing RPC mode tests | ❌ 3/10 fail | Pre-existing: `autoModeFallsBackAndCachesLegacy`, `autoModeDoesNotFallbackOnJSONRPCBusinessError` |
| swift-format | ✅ 0 changes | No diffs |
| swiftlint | ✅ 2 warnings, 0 serious | Pre-existing in ServerDetailView.swift |

## Рекомендуемый minimal fix

Изменить `initialModesToTry()` в `TransmissionClient.swift`:

```swift
// Было:
return [.legacy, .jsonRpc2]

// Стало:
return [.jsonRpc2, .legacy]
```

Это позволит:
1. Auto mode пробовать JSON-RPC 2.0 первым
2. Fallback check `modeIndex + 1 < modesToTry.count` работать корректно (0 + 1 < 2 = true)
3. Существующие тесты `autoModeFallsBackAndCachesLegacy` и `autoModeDoesNotFallbackOnJSONRPCBusinessError` проходить

## Следующие задачи

1. Применить minimal fix для `initialModesToTry()` (поменять порядок на `[.jsonRpc2, .legacy]`)
2. Перезапустить все RPC mode тесты
3. Добавить интеграционный тест для fallback + 409 handshake
4. Проверить fallback в реальном окружении с Transmission 4.x
