# Remission Project Analysis

Документ фиксирует текущую картину проекта Remission, чтобы повторно не собирать контекст.

## 1. Краткое описание
- Remission — кроссплатформенный клиент (iOS + macOS) для управления Transmission через RPC.
- Цель MVP: подключение к одному/нескольким серверам, список и управление торрентами, добавление .torrent/magnet, безопасное хранение credentials в Keychain.
- Продукт ориентирован на тех. пользователей и владельцев NAS/серверов.

## 2. Ключевые требования (PRD)
- Быстрый UI при 200+ торрентах (цель < 200 ms LAN).
- Успешность команд > 98%.
- Покрытие тестами ключевых компонентов >= 60%.
- RU/EN локализации (RU по умолчанию).
- Только opt-in телеметрия.

## 3. Платформы и toolchain
- Xcode 15+ (README упоминает 26.0.1+, AGENTS.md — 15.0+).
- Swift 6.0+ (strict concurrency).
- Deployment targets: iOS 26.0+, macOS 26.0+, visionOS 26.0+.
- Форматирование: `swift-format`, стиль: `swiftlint`.

## 4. Архитектура и слои
- Основной паттерн: The Composable Architecture (TCA) для всех feature-модулей.
- Слои: UI (SwiftUI) → Presentation (TCA Reducers) → Domain → Network/Services → Persistence.
- Бизнес-логика не живет во View; побочные эффекты только через `.run` в Reducer.

### 4.1 Входные точки приложения
- `Remission/App/RemissionApp.swift`: `@main` entry point.
- `Remission/App/AppBootstrap.swift`: сборка начального состояния, миграция, фикстуры для UI-тестов.
- `Remission/App/AppDependencies.swift`: построение зависимостей для live/preview/test/UI-test окружений.
- `Remission/App/AppFeature.swift`: корневой TCA reducer (AppReducer).

### 4.2 Корневое состояние и навигация
- `AppReducer.State`: `serverList`, `path (StackState<ServerDetailReducer.State>)`, versioning.
- Документ контракта: `devdoc/AppStateSchema.md`.
- Навигация через `NavigationStack` и `StackState`.

## 5. Структура проекта

### 5.1 Основные директории
- `Remission/Features/`: TCA reducers (Onboarding, ServerList, ServerDetail, ServerEditor, TorrentList, TorrentDetail, TorrentAdd, Settings, Diagnostics).
- `Remission/Views/`: SwiftUI экраны и компоненты.
- `Remission/Domain/`: доменные модели + маппинг из RPC.
- `Remission/Network/Transmission/`: сетевой слой (Transmission RPC).
- `Remission/Repositories/`: репозитории (Torrent/Session/ServerConfig/UserPreferences/etc.).
- `Remission/Storage/`: Keychain и офлайн-снапшоты.
- `Remission/Security/`: TLS trust, credentials модели.
- `Remission/Logging/`: логирование RPC и аудита.
- `Remission/DependencyClients/` + `Remission/DependencyClientLive/`: DI слой.

### 5.2 Документация
- `devdoc/PRD.md`: требования и пользовательские сценарии.
- `devdoc/plan.md`: архитектурные решения и workflow.
- `devdoc/TRANSMISSION_RPC_REFERENCE.md`: RPC справочник.
- `devdoc/LOGGING_GUIDE.md`: логирование и диагностика.
- `devdoc/FACTORY_PATTERNS.md`: фабрики per-context окружений.
- `devdoc/CACHE_INVALIDATION_GUIDE.md`: офлайн кеш и инвалидация.

## 6. Domain модели и маппинг
- `TransmissionDomainMapper*`: все преобразования RPC → доменные модели.
- Доменные сущности: `ServerConfig`, `Torrent`, `SessionState`, `UserPreferences`, `DiagnosticsLogEntry`.
- Принцип: в фичах не разбирать `AnyCodable` вручную.

## 7. Network слой (Transmission RPC)
- Основные типы: `TransmissionClientProtocol`, `TransmissionClient`, `TransmissionRequest`, `TransmissionResponse`, `AnyCodable`.
- Handshake: HTTP 409 session-id, повтор запроса с `X-Transmission-Session-Id`.
- Проверка версии RPC: минимум v14 (Transmission 3.0+).
- Ретраи с exponential backoff, управление временем через `swift-clocks`.
- TLS trust: `TransmissionTrustEvaluator` + `TransmissionTrustPromptCenter` для self-signed.

## 8. Репозитории и хранилища
- Репозитории: `TorrentRepository`, `SessionRepository`, `ServerConfigRepository`, `CredentialsRepository`, `UserPreferencesRepository`, `OnboardingProgressRepository`.
- Storage:
  - `KeychainCredentialsStore` — хранение паролей.
  - `ServerSnapshotCache` — офлайн-снапшоты торрентов/сессии.
  - `HttpWarningPreferencesStore` — предупреждения по HTTP.

## 9. Безопасность
- Credentials только в Keychain, не логируются.
- HTTPS/TLS поддержка + обработка недоверенных сертификатов.
- Base64 credentials и session-id маскируются в логах.

## 10. Логи и диагностика
- `AppLogger` (swift-log) + `DefaultTransmissionLogger`.
- `DiagnosticsLogStore` — локальный буфер записей, отображение в UI (Diagnostics).
- Гайд: `devdoc/LOGGING_GUIDE.md`.

## 11. Офлайн кеш
- Ключ: `serverID + fingerprint + rpcVersion`.
- TTL 30 минут, лимит 5 МБ на сервер.
- Инвалидация: смена учётных данных, версия RPC, удаление сервера, ошибки чтения.
- Подробнее: `devdoc/CACHE_INVALIDATION_GUIDE.md`.

## 12. Локализация
- Единый источник: `Remission/Localizable.xcstrings`.
- Скрипт проверки: `Scripts/check-localizations.sh`.
- Build phase “Localizations Check” валит сборку при пропусках/плейсхолдерах.

## 13. Тесты
- Фреймворк: Swift Testing (`@Test`, `#expect`, `TestStore`).
- Unit: `RemissionTests/` (reducers, network, repositories, mappers).
- UI: `RemissionUITests/` (onboarding, список серверов, торренты, diagnostics).
- Фикстуры: `RemissionTests/Fixtures/Transmission` и `RemissionTests/Fixtures/Domain`.
- Пример рекомендаций: `RemissionTests/README.md`.

## 14. Скрипты и автоматизация
- `Scripts/prepare-hooks.sh` — pre-commit hook.
- `Scripts/check-localizations.sh` — проверка строк.
- `Scripts/setup-swiftlint.sh` — настройка линтера.
- `Scripts/increment_version.sh` и `Scripts/release_local.sh` — локальный релизный цикл.

## 15. CI/Build
- CI отключен, проверки выполняются локально.
- Базовые команды:
  - `swift-format lint --configuration .swift-format --recursive --strict`
  - `swiftlint lint`
  - `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e'`

## 16. Ключевые entry points по коду
- `Remission/App/RemissionApp.swift` — запуск, выбор зависимостей.
- `Remission/App/AppBootstrap.swift` — миграции состояния и фикстуры UI тестов.
- `Remission/App/AppFeature.swift` — root reducer.
- `Remission/Network/Transmission/TransmissionClient.swift` — RPC, handshake, retry.
- `Remission/Domain/TransmissionDomainMapper.swift` — маппинг RPC → domain.

## 17. Что важно помнить
- Все изменения пользовательских сценариев синхронизировать с `devdoc/PRD.md`.
- Любая новая библиотека/инструмент требует Context7 research (см. `devdoc/CONTEXT7_GUIDE.md`).
- TCA обязателен для feature state (исключение: тривиальные View без состояния).
- Для каждого reducer минимум 2 теста (happy + error).

## 18. Быстрые ссылки
- `devdoc/PRD.md`
- `devdoc/plan.md`
- `devdoc/TRANSMISSION_RPC_REFERENCE.md`
- `devdoc/LOGGING_GUIDE.md`
- `devdoc/AppStateSchema.md`
- `Remission/App/AppDependencies.swift`
- `Remission/App/AppBootstrap.swift`
- `Remission/App/AppFeature.swift`
