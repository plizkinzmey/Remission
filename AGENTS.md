# Remission Agent Handbook

## Product Overview
- Remission - кроссплатформенный клиент (iOS + macOS) для удалённого управления Transmission через RPC, ориентированный на быстрый контроль и мониторинг торрентов.
- MVP обеспечивает подключение к одному или нескольким серверам, просмотр и управление торрентами, добавление .torrent/magnet, безопасное хранение учётных данных в Keychain.
- Основные пользователи - домашние администраторы NAS/серверов и технические пользователи, которым нужен мобильный и десктопный доступ.
- Любое изменение пользовательских сценариев синхронизируйте с `devdoc/PRD.md`; PRD остаётся источником истины по функционалу.

## Functional Scope (MVP->v1)
- **Подключение и конфигурация**: настройка host/port/proto, Basic Auth, проверка статуса соединения, управление сохранёнными серверами, обязательная запись секретов в Keychain.
- **Список торрентов**: отображение идентификатора, статуса, прогресса, скоростей и peers; поиск, сортировки, фильтры; обновление по настраиваемому polling-интервалу.
- **Детали торрента**: файлы, трекеры, peers, история скоростей, путь загрузки; действия Start/Pause/Remove/Verify/Set Priority.
- **Добавление торрентов**: импорт .torrent из Files/Share, обработка magnet-ссылок, выбор каталога, запуск в паузе, опциональные теги.
- **Настройки**: polling interval, автообновление при старте, лимиты скоростей, локализации RU/EN (RU по умолчанию), управление сохранёнными серверами.
- **Логи и телеметрия**: локальное логирование сетевых ошибок; внешняя отправка метрик только по явному согласию пользователя.
- **Нефункциональные цели**: отзывчивость UI при 200+ торрентах (<200 мс в LAN), успех команд >98%, тестовое покрытие ключевых компонентов >=60%.

## Architecture & Patterns
- Базовая архитектура: **TCA (The Composable Architecture)** для всех feature-модулей + слои network/domain/persistence; бизнес-логика не живёт во View.
- **The Composable Architecture (TCA)** для feature-модулей: обязательный паттерн для управления состоянием (исключение: только тривиальные View без состояния).
  - Структура: `@ObservableState struct State`, `enum Action`, `Reducer` с `var body`, store инициализируется с `Store(initialState:, reducer:)`.
  - State sharing: используйте `@Presents` для опциональных состояний (sheets, alerts) и `IdentifiedArrayOf` для коллекций.
  - Effects: все побочные эффекты инкапсулируются через `.run { send in ... }` блоки в reducer.
  - Navigation: используйте SwiftUI's `NavigationStack` с TCA state-driven подходом.
  - Тестирование: используйте `TestStore` для exhaustive тестирования reducers и effects (все mutations и side effects проверяются).
- Для каждого TCA reducer минимум два теста (happy path + error path); эффекты мокируются через зависимости в Environment.
- `TransmissionClientProtocol` реализует JSON-RPC поверх HTTP(S); репозитории превращают сырой RPC в доменные модели.
- Используем async/await, Task, actors; помечаем публичные API @MainActor/@Sendable при необходимости; для детерминированных тестов времени применяем `swift-clocks`.

## Project Layout & Toolchain
- `Remission/` - SwiftUI entry point (`RemissionApp.swift`), основные экраны, ресурсы (`Assets.xcassets`).
- `RemissionTests/` - Тесты на Swift Testing фреймворке; именуйте файлы в паре с production-модулями.
- `RemissionUITests/` - XCUITest сценарии и smoke-проверки.
- `devdoc/PRD.md` - PRD, обязательное обновление при функциональных изменениях.
- Стартовые команды:
  - `open Remission.xcodeproj` - запуск Xcode (схема `Remission`).
  - `xcodebuild -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15' build` - CLI-сборка.
  - `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15'` - unit + UI тесты; запускайте перед любым PR.
- Воспользуйтесь SwiftUI previews (`ContentView.swift`) для быстрой итерации UI.
- Форматирование и стиль: `swift-format` (обязательно в pre-commit/CI) и `swiftlint`. Следуйте Swift 6 API Design Guidelines (4 пробела, PascalCase типов, camelCase членов, noun-based протоколы).
- Извлекайте переиспользуемые SwiftUI компоненты в отдельные файлы после ~150 строк; ассеты именуем в snake_case (`icon_start`).

## Security, Reliability & Performance
- Все учётные данные сохраняем через Keychain; исключаем утечки секретов в логи.
- Поддерживаем HTTPS/TLS и проверяем сертификаты, если сервер предоставляет.
- Basic Auth отправляем безопасно и храним минимально необходимый набор.
- Сетевые ошибки логируем, показываем понятные сообщения, реализуем retry c экспоненциальной задержкой и обработку несовместимости версий Transmission.
- UI должен оставаться responsive при потоках >200 торрентов: используйте lazy-loading/pagination и оптимизируйте запросы (`torrent-get` с выбранными полями).

## Testing & QA
- **Фреймворк тестирования**: Swift Testing (встроенный модуль) с атрибутом `@Test` — современная альтернатива XCTest.
  - Структура: `@Test` вместо `test*` методов, `@Suite` для группировки, `#expect` и `#require` для проверок.
  - Параметризованные тесты поддерживают аргументы, что снижает дублирование кода.
  - Conditional traits (`@Test(.enabled(if:))`, `@Suite(.serialized)`) управляют выполнением тестов.
- Unit-тесты: сетевой слой, репозитории, ViewModel/Reducer. Тесты TCA используют зависимостей-моки и `TestStore`.
- Integration: поднятие Transmission через Docker-compose в CI, прогон сценариев connect/add/start/stop/remove.
- UI: XCUITest для onboarding, списка и добавления торрента (Given/When/Then комментарии).
- Цель покрытия >=60% на ключевых компонентах; отчёты прикладываем к PR.

## CI, Tooling & Releases
- CI pipeline: swift-format, swiftlint, build, unit/UI тесты, интеграционные сценарии (Transmission docker). Рассмотрите статический анализ Swift 6 preview, если требуется.
- **swift-format** (Apple): конфигурация хранится в `.swift-format` в корне репозитория. Перед коммитом запустите `swift-format format --in-place --configuration .swift-format --recursive Remission RemissionTests RemissionUITests` для форматирования всех файлов. Для проверки (lint в strict mode): `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests`.
- **SwiftLint**: инструмент для проверки стиля кода Swift (версия 0.61.0+). Конфигурация в `.swiftlint.yml` в корне репозитория. 
  - Интегрирован в Xcode build phase (Run Script) и запускается автоматически при сборке.
  - Локально: `swiftlint lint` для проверки, `swiftlint --fix` для автоисправлений.
  - На Apple Silicon (M1/M2/M3) скрипт автоматически добавляет `/opt/homebrew/bin` в PATH.
  - Полная документация: `devdoc/SWIFTLINT.md`
- **Pre-commit hooks**: используйте `bash Scripts/prepare-hooks.sh` для установки git hook'а, который автоматически проверяет код перед коммитом. Hook запускает swift-format lint --strict и SwiftLint. См. `CONTRIBUTING.md` для деталей.
- Перед релизом проверяйте миграции API Transmission, избегайте жёстких зависимостей от конкретной версии; добавьте handshake/compatibility checks.
- Документируйте публичные API и контракты краткими комментариями; избегайте дублирования бизнес-логики между слоями.

## Workflow & Collaboration
- **КРИТИЧЕСКИ ВАЖНО**: Перед реализацией любого кода, конфигурации или инструмента **обязательно обратитесь в Context7** для получения актуальной информации и документации. Никогда не полагайтесь на гипотезы или устаревшие знания. Используйте `mcp_context7_resolve-library-id` и `mcp_context7_get-library-docs` для получения последней информации.
- Коммит-месседжи: лаконичные императивы на русском (`Добавить поддержку удаленного подключения`), одна логическая правка на коммит.
- PR содержат описание изменений, ссылки на PRD/тикеты, доказательство прогона тестов (лог или скрин).
- Поддерживайте синхронизацию документации: изменения функционала -> обновления `devdoc/PRD.md`, релевантные README/CONTRIBUTING правки.
- Перед мерджем убедитесь, что новая функциональность покрыта тестами и проверена локально (`xcodebuild test ...`).

## Environment & Requirements

- **Xcode:** 15.0 или выше
- **Swift:** 6.0+
- **iOS deployment target:** 26.0+
- **macOS deployment target:** 26.0+
- **visionOS deployment target:** 26.0+
- **Обязательные инструменты:** swift-format 602.0.0+, SwiftLint 0.61.0+

## Git & Branching

- **Branch naming:** `feature/RTC-N-краткое-описание`, `fix/RTC-N-краткое-описание`, `docs/RTC-N-краткое-описание`
- **Commits:** все сообщения на русском, одна логическая правка на коммит
- **Подпись коммитов:** рекомендуется `git commit -S` (GPG signing), но не обязательна
- **Pull Requests:** все изменения через PRs с обязательным ревью перед merge

## Common Pitfalls & How to Avoid

1. **Смешение TCA и @State/@StateObject в одной View**
   - ❌ Неправильно: `@State var torrents = []` + TCA Store одновременно
   - ✅ Правильно: всё состояние идёт через Store и `@Bindable`

2. **Сохранение секретов в лог**
   - ❌ Неправильно: `print("Transmission auth: \(username):\(password)")`
   - ✅ Правильно: логировать только "Auth successful" или error codes

3. **Прямые network calls в View**
   - ❌ Неправильно: `URLSession.shared.dataTask(...).resume()` в `body { }`
   - ✅ Правильно: в Reducer effect через `.run { send in ... }`

4. **Забывают тесты для редьюсеров**
   - ❌ Новая фича без TestStore
   - ✅ Минимум: happy path + 1 error path тест

5. **Модифицируют State напрямую вне Reducer**
   - ❌ Неправильно: `store.state.torrents.append(newTorrent)`
   - ✅ Правильно: `store.send(.addTorrent(newTorrent))` через Action → Reducer

## CI Pipeline

Полный конфиг CI см. в `.github/workflows/`.

**Обязательные checks перед merge:**
- ✅ `swift-format lint --configuration .swift-format --recursive --strict`
- ✅ `swiftlint lint`
- ✅ `xcodebuild build`
- ✅ `xcodebuild test` (unit + UI)
- ✅ Покрытие тестами >= 60% на ключевых компонентах

Локально запустите перед push:
```bash
bash Scripts/prepare-hooks.sh  # установить pre-commit hook
git commit -m "Your message"    # hook автоматически проверит код
```
