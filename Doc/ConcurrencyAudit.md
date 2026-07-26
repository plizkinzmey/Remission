# Remission: Concurrency Audit (Stage 0)

Date: 2026-06-22
Branch: feature/stage-0-concurrency-diagnostics

## Что включили

`SWIFT_STRICT_CONCURRENCY = targeted` для всех Debug-конфигураций:
- PBXProject "Remission" Debug
- PBXNativeTarget "Remission" Debug
- PBXNativeTarget "RemissionTests" Debug
- PBXNativeTarget "RemissionUITests" Debug

Release-конфигурации НЕ трогали.

## Что проверено

| Проверка | Результат | Примечание |
|---|---|---|
| macOS Debug build | ✅ BUILD SUCCEEDED | 0 concurrency warnings/errors |
| iOS Debug build | ❌ BUILD FAILED (окружение) | Ошибка не связана с изменениями, воспроизводится без них |
| swiftlint | ✅ Не применяется к .md | Ожидаемо — SwiftLint проверяет только .swift |
| swift-format | ❌ Не установлен | `brew install swift-format` не выполнен |

## macOS Build результат

```
export SWIFT_STRICT_CONCURRENCY\=targeted
** BUILD SUCCEEDED **
```

Сборка macOS Debug прошла без ошибок и без warnings, связанных с strict concurrency.

Ни одного `warning: ... Sendable`, `error: ... actor isolation`, `non-sendable` — проект компилируется чисто в данной конфигурации.

## iOS Build результат

```
error: unable to resolve module dependency: 'SwiftSyntaxBuilder'
error: unable to resolve module dependency: 'SwiftSyntaxMacros'
error: unable to resolve module dependency: 'SwiftCompilerPlugin'
** BUILD FAILED **
```

Ошибка воспроизводится и без наших изменений (`git stash` → тот же результат). Это известная проблема окружения: Xcode 17F42 + SPM-макросы (swift-composable-architecture, swift-dependencies, swift-case-paths) + iOS Simulator 26.5 SDK. Не связана с `SWIFT_STRICT_CONCURRENCY`.

**Рекомендация:** Проверить iOS build в Xcode IDE или на другой машине. macOS build подтверждает, что изменения не ломают компиляцию.

## Существующие @unchecked Sendable (инвентаризация)

Ниже — список всех `@unchecked Sendable` в проекте. Без дополнительных тестов (TSan, concurrent stress-tests) мы не можем гарантировать их безопасность окончательно. Однако анализ кода показывает, что каждый из них имеет документированный safety invariant.

| Файл | Тип | Предполагаемая защита | Потенциальный риск |
|---|---|---|---|
| `AppLogger.swift:18` | struct | swift-log Logger (контракт) | Зависит от контракта swift-log; без TSan-теста не гарантировано |
| `OnboardingProgressRepository.swift:64` | class | NSLock | Низкий — NSLock защищает Bool |
| `OnboardingProgressRepository.swift:85` | class | UserDefaults (thread-safe) | Низкий — UserDefaults thread-safe by contract |
| `HttpWarningPreferencesStore.swift:67` | class | NSLock | Низкий — NSLock защищает Bool |
| `HttpWarningPreferencesStore.swift:93` | class | UserDefaults (thread-safe) | Низкий |
| `DiagnosticsLogStoreDependency.swift:316` | class | UserDefaults (thread-safe) | Низкий |
| `UserPreferencesRepository+Live.swift:194` | class | UserDefaults (thread-safe) | Низкий |
| `TransmissionTrustStore.swift:228` | class | NSLock | Низкий — NSLock защищает dictionary |
| `TransmissionSessionDelegate.swift:3` | struct | Immutable SecTrust wrapper | Низкий — только read-only доступ |
| `TransmissionSessionDelegate.swift:10` | struct | One-shot completion wrapper | Низкий — вызывается ровно один раз |

**Важно:** Отсутствие ошибок при `SWIFT_STRICT_CONCURRENCY = targeted` означает, что компилятор не нашёл нарушений в текущем коде. Это НЕ означает, что все `@unchecked Sendable` абсолютно безопасны при любых сценариях конкурентного доступа. Для полной уверенности нужны TSan-тесты.

## Что исправлено

Ничего не исправлено — не было найдено проблем, требующих исправления на этом этапе.

## Что отложено

1. **AppLogger → actor** — потенциальная миграция на actor для полного устранения `@unchecked Sendable`. Требует проверки потокобезопасности swift-log Logger через TSan.
2. **NSLock stores → actor** — миграция OnboardingProgressMemoryStore и HttpWarningPreferencesMemoryStore на actor. Низкий приоритет, NSLock работает корректно.
3. **Complete concurrency** — включение `SWIFT_STRICT_CONCURRENCY = complete` вместо `targeted`. Требует инвентаризации зависимостей (swift-composable-architecture, swift-dependencies).
4. **Release strict concurrency** — включение для Release. Низкий приоритет, сначала стабилизация Debug.
5. **iOS build проверка** — требуется проверка в другой среде (Xcode IDE или другая машина).

## Риски

1. **iOS build не проверен** — ошибка окружения не позволяет подтвердить iOS-сборку. Рекомендуется проверить в Xcode IDE.
2. **AppLogger** — единственный `@unchecked Sendable`, который зависит от контракта внешней библиотеки. При обновлении swift-log может потребовать пересмотра.
3. **Complete concurrency** — при переходе на `complete` могут появиться ошибки в зависимостях (TCA, swift-dependencies). Требуется инвентаризация.
4. **Тесты через CLI** — в данной среде тесты не запускаются через `xcodebuild test`. Рекомендуется запускать через Xcode IDE.

## Следующие задачи

1. Проверить iOS build в Xcode IDE или другой среде.
2. Запустить тесты через Xcode IDE (Cmd+U) и убедиться, что все проходят.
3. Включить `SWIFT_STRICT_CONCURRENCY = targeted` для Release (после проверки Debug).
4. Исследовать переход на `complete` с инвентаризацией зависимостей.
