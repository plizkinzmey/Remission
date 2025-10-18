Это репозиторий клиента Remission для удалённого управления Transmission. Документ помогает AI-агентам быстро разобраться в архитектуре SwiftUI/TCA, принятых соглашениях и обязательных шагах перед коммитами.

- Ключевые факты
- Язык: Swift (SwiftUI). Проект использует Swift 6 — все изменения должны быть совместимы с Swift 6 и билдиться с соответствующим режимом компилятора.
- Точка входа приложения: `Remission/RemissionApp.swift` — `@main` App struct.
- Основной UI: `Remission/ContentView.swift` — корневой `View`, используемый в `WindowGroup`.
- Тесты: `RemissionTests/RemissionTests.swift` и UI-тесты в `RemissionUITests/`.
- В репозитории присутствует ` .github/copilot-instructions.md`; также добавлены `.gitignore` и `devdoc/PRD.md`. Этот файл служит главным источником инструкций для AI-агентов.

- Что менять и почему
- Небольшие изменения интерфейса/фич: редактируйте `ContentView.swift` и добавляйте новые Swift-файлы в папку `Remission/`.
- Жизненный цикл приложения/конфигурация: редактируйте `RemissionApp.swift` (он отвечает за корневой вид).
- Тесты размещаются в `RemissionTests/` (unit) и `RemissionUITests/` (UI). В тестах используется модуль `Testing` и атрибут `@Test` (см. `RemissionTests/RemissionTests.swift`).
- State management: проект использует единую стратегию — The Composable Architecture (TCA). Все feature-модули должны реализовываться через TCA (@ObservableState State, enum Action, Reducer). Не смешивать MVVM и TCA в одном модуле.
- Network layer: TransmissionClient реализует Transmission RPC вызовы (собственный протокол, не JSON-RPC 2.0). Обработка аутентификации (Basic Auth + HTTP 409 handshake для session-id). Справочник: `devdoc/TRANSMISSION_RPC_REFERENCE.md`.

Сборка и тестирование (рабочие сценарии)
- Открыть в Xcode: двойной клик по `Remission.xcodeproj` и запуск схемы `Remission` в стандартном симуляторе.
- Сборка и тесты из терминала:

```bash
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14' build
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14'
```

- Сборка проекта через SwiftPM не поддерживается (проект не оформлен как Swift Package); используйте Xcode или `xcodebuild`.

Особенности и соглашения проекта
- Приложение использует модульную структуру поверх SwiftUI `struct`. Старайтесь выносить повторно используемые компоненты в отдельные `View` в `Remission/`, чтобы поддерживать читаемость.
- Превью и быстрая итерация: используйте SwiftUI Preview (Preview area в `ContentView.swift`) для локальной проверки визуальных изменений.
- Тесты используют внешний модуль `Testing` и `@Test`. Добавляйте тесты в том же стиле.

Быстрый старт (First-Time Setup)
- **Установить инструменты:**
  - swift-format 602.0.0+: входит в состав Xcode 15.0+, или установить отдельно через Homebrew
  - SwiftLint 0.61.0+: `brew install swiftlint`

- **Установить pre-commit hook для автоматических проверок:**
  ```bash
  bash Scripts/prepare-hooks.sh
  ```

- **Проверить, что hook работает:**
  ```bash
  git commit --allow-empty -m "Test commit"
  ```
  Вывод должен показать, что swift-format и swiftlint пройдены ✅

Конкретные примеры
- Поменять стартовый экран: редактируйте `Remission/RemissionApp.swift` — сейчас в `WindowGroup` возвращается `ContentView()`.
- Добавить новый компонент: создайте `Remission/MyFeatureView.swift`:

```swift
struct MyFeatureView: View {
    var body: some View { Text("My feature") }
}
```

и подключите его в `RemissionApp` или в навигации.
- Добавить unit-тест: создайте файл в `RemissionTests/` и следуйте примеру в `RemissionTests/RemissionTests.swift`.

- Интеграции и внешние зависимости
- Внешние зависимости подключаются через Swift Package Manager. При добавлении новых пакетов фиксируйте изменения в PR и отражайте обновлённую структуру в `devdoc/plan.md`. Для крупных модулей рассматривайте вынос в локальные Swift Packages (`Features/TorrentList`, `Services/TransmissionClient`, `Shared/Models`).

- Библиотека TCA: добавьте зависимость `https://github.com/pointfreeco/swift-composable-architecture` через SPM и используйте её как стандарт для state-management. Все feature-модули должны реализовываться как TCA reducers с @ObservableState, Action enum и Reducer body.

- Swift 6 toolchain: если необходим preview toolchain, добавьте шаг в CI для установки требуемого toolchain.

## Важно про Transmission RPC

- **Собственный формат** (не JSON-RPC 2.0): используются `method`, `arguments`, `tag` в запросе; ответ содержит `result: "success"` или строку-ошибку
- **HTTP 409 handshake**: обязателен при первом подключении для получения `X-Transmission-Session-Id`
- **Basic Auth + Session ID**: оба обязательны в заголовках
- **Версионирование**: поддержка минимум Transmission 3.0+ (рекомендуется 4.0+)
- **Безопасность**: НИКОГДА не логировать пароли, session-id или чувствительные данные
- **Справочник**: `devdoc/TRANSMISSION_RPC_REFERENCE.md` и `devdoc/TRANSMISSION_RPC_METHOD_MATRIX.md`

- Рекомендации для AI-агентов при правках:
- Делайте маленькие атомарные коммиты — одна логическая правка (вью, редьюсер, тест).
- Используйте TCA для всех feature-модулей: State/Action/Environment/Reducer/View. Effects (сетевая логика) инкапсулируйте в Environment.
- Архитектура: разделение слоёв — UI (View) / Presentation (Reducer/ViewStore) / Domain/Services (Repositories, TransmissionClient) / Persistence (Keychain/CoreData).
- Не смешивать frontend-логику и backend-логику в одном файле или модуле. Сеть и persistence должны быть в `Services`/`Repositories`.
- Не перестраивайте структуру проекта без запроса — сохраняйте простую точку входа приложения. Если требуется рефакторинг — опишите мотивацию в сообщении коммита и создайте отдельный PR.
- При добавлении тестов следуйте использованию `Testing` и `@Test`; добавляйте unit-тесты для редьюсеров и эффектов.

## CI и форматирование
- В CI требуется запускать сборку под Swift 6, `swift-format` и `swiftlint`. Форматирование и линтинг должны проходить в pre-commit или как обязательный шаг в CI.
- **swift-format** (Apple) интегрирован в pre-commit hook. Локально запустите `swift-format lint --configuration .swift-format --recursive --strict Remission RemissionTests RemissionUITests` для проверки. Для применения исправлений: `swift-format format --in-place --configuration .swift-format --recursive Remission RemissionTests RemissionUITests`. Конфигурация в `.swift-format` (JSON).
- **SwiftLint** интегрирован в Xcode build phase и запускается автоматически при сборке. Локально запустите `swiftlint lint` для проверки. Конфигурация в `.swiftlint.yml` (см. документ `devdoc/SWIFTLINT.md`).
- **Pre-commit hooks**: используйте `bash Scripts/prepare-hooks.sh` для установки автоматических проверок перед коммитом. Hook запускает swift-format lint --strict и SwiftLint и блокирует коммит при ошибках. См. `CONTRIBUTING.md` для полной информации.

Политика коммитов
- Все сообщения коммитов должны быть строго на русском языке. Это касается как короткой строки (summary), так и, при необходимости, описания (body). Примеры:
    - Правильно: `Добавить поддержку добавления magnet-ссылок` или `Реализовать TorrentList редьюсер`
    - Неправильно: `Add magnet support` или `Implement TorrentList reducer`

Если что-то непонятно
- Спросите владельца репозитория о таргете (iOS или macOS), устройстве/симуляторе для тестов и о допустимости добавления Swift Package зависимостей.

## Environment & Requirements

- **Xcode:** 15.0 или выше
- **Swift:** 6.0+
- **iOS deployment target:** 26.0+
- **macOS deployment target:** 26.0+
- **visionOS deployment target:** 26.0+
- **Обязательные инструменты:** swift-format 602.0.0+, SwiftLint 0.61.0+

Конец файла
