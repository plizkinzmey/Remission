Это репозиторий минимального SwiftUI-приложения (macOS/iOS), созданного из шаблона. Цель этих инструкций — быстро ввести в работу AI-агентов, описав структуру проекта, соглашения и полезные команды.

- Ключевые факты
- Язык: Swift (SwiftUI). Проект использует Swift 6 — все изменения должны быть совместимы с Swift 6 и билдиться с соответствующим режимом компилятора.
- Точка входа приложения: `Remission/Remission/RemissionApp.swift` — `@main` App struct.
- Основной UI: `Remission/Remission/ContentView.swift` — упрощённый `View`, используемый в `WindowGroup`.
- Тесты: `Remission/RemissionTests/RemissionTests.swift` и UI-тесты в `Remission/RemissionUITests/`.
- В репозитории присутствует ` .github/copilot-instructions.md`; также добавлены `.gitignore` и `devdoc/PRD.md`. Этот файл служит главным источником инструкций для AI-агентов.

- Что менять и почему
- Небольшие изменения интерфейса/фич: редактируйте `ContentView.swift` и добавляйте новые Swift-файлы в папку `Remission/Remission/`.
- Жизненный цикл приложения/конфигурация: редактируйте `RemissionApp.swift` (он отвечает за корневой вид).
- Тесты размещаются в `RemissionTests/` (unit) и `RemissionUITests/` (UI). В тестах используется модуль `Testing` и атрибут `@Test` (см. `RemissionTests/RemissionTests.swift`).
- State management: проект использует единую стратегию — The Composable Architecture (TCA). Все feature-модули должны реализовываться через TCA (@ObservableState State, enum Action, Reducer). Не смешивать MVVM и TCA в одном модуле.

Сборка и тестирование (рабочие сценарии)
- Открыть в Xcode: двойной клик по `Remission.xcodeproj` и запуск схемы `Remission` в стандартном симуляторе.
- Сборка и тесты из терминала (xcodebuild / SwiftPM примеры):

```bash
xcodebuild -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14' build
xcodebuild test -scheme Remission -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14'
```

- Для быстрой компиляции отдельных Swift-файлов можно использовать SwiftPM из корня проекта:

```bash
swift build
```

Особенности и соглашения проекта
- Проект — минимальный шаблон: представления реализованы как SwiftUI `struct` (см. `ContentView.swift`). Вью очень компактны — предпочитайте создавать маленькие переиспользуемые `View`-компоненты в `Remission/Remission/`.
- Превью и быстрая итерация: используйте SwiftUI Preview (Preview area в `ContentView.swift`) для локальной проверки визуальных изменений.
- Тесты используют внешний модуль `Testing` и `@Test`. Добавляйте тесты в том же стиле.

Конкретные примеры
- Поменять стартовый экран: редактируйте `Remission/Remission/RemissionApp.swift` — сейчас в `WindowGroup` возвращается `ContentView()`.
- Добавить новый компонент: создайте `Remission/Remission/MyFeatureView.swift`:

```swift
struct MyFeatureView: View {
    var body: some View { Text("My feature") }
}
```

и подключите его в `RemissionApp` или в навигации.
- Добавить unit-тест: создайте файл в `Remission/RemissionTests/` и следуйте примеру в `RemissionTests/RemissionTests.swift`.

- Интеграции и внешние зависимости
- В репозитории нет настроенных внешних пакетов (минимальный шаблон). Все новые модули и зависимости следует подключать через Swift Package Manager (SPM). Рекомендуется создать локальные Swift Packages для крупных модулей (например, `Features/TorrentList`, `Services/TransmissionClient`, `Shared/Models`).

- Библиотека TCA: добавьте зависимость `https://github.com/pointfreeco/swift-composable-architecture` через SPM и используйте её как стандарт для state-management. Все feature-модули должны реализовываться как TCA reducers с @ObservableState, Action enum и Reducer body.

- Swift 6 toolchain: если необходим preview toolchain, добавьте шаг в CI для установки требуемого toolchain.

- Рекомендации для AI-агентов при правках
- Делайте маленькие атомарные коммиты — одна логическая правка (вью, редьюсер, тест).
- Используйте TCA для всех feature-модулей: State/Action/Environment/Reducer/View. Effects (сетевая логика) инкапсулируйте в Environment.
- Архитектура: разделение слоёв — UI (View) / Presentation (Reducer/ViewStore) / Domain/Services (Repositories, TransmissionClient) / Persistence (Keychain/CoreData).
- Не смешивать frontend-логику и backend-логику в одном файле или модуле. Сеть и persistence должны быть в `Services`/`Repositories`.
- Не перестраивайте структуру проекта без запроса — сохраняйте простую точку входа приложения. Если требуется рефакторинг — опишите мотивацию в сообщении коммита и создайте отдельный PR.
- При добавлении тестов следуйте использованию `Testing` и `@Test`; добавляйте unit-тесты для редьюсеров и эффектов.
- **КРИТИЧЕСКИ ВАЖНО**: Перед реализацией любого кода, конфигурации, зависимости или инструмента **обязательно обратитесь в Context7** для получения актуальной информации и документации. Никогда не полагайтесь на гипотезы или устаревшие знания. Используйте `mcp_context7_resolve-library-id` и `mcp_context7_get-library-docs` для получения последней информации. Только после изучения актуальной документации начинайте писать код.

CI и форматирование
- В CI требуется запускать сборку под Swift 6, `swift-format` и `swiftlint` (если используется). Форматирование и линтинг должны проходить в pre-commit или как обязательный шаг в CI.

Политика коммитов
- Все сообщения коммитов должны быть строго на русском языке. Это касается как короткой строки (summary), так и, при необходимости, описания (body). Примеры:
    - Правильно: `Добавить поддержку добавления magnet-ссылок` или `Реализовать TorrentList редьюсер`
    - Неправильно: `Add magnet support` или `Implement TorrentList reducer`

Если что-то непонятно
- Спросите владельца репозитория о таргете (iOS или macOS), устройстве/симуляторе для тестов и о допустимости добавления Swift Package зависимостей.

- Правило Context7 для AI-агентов
- **ОБЯЗАТЕЛЬНО** перед началом работы над любой задачей:
  1. Если задача требует конфигурации инструмента (swift-format, swiftlint, CocoaPods, SPM и т.д.) — обратитесь в Context7 для актуальной документации
  2. Если задача требует интеграции внешней библиотеки — обратитесь в Context7 для последней версии и API
  3. Если задача требует использования новых версий Swift, Xcode или платформ — проверьте Context7 для совместимости
  4. Используйте `mcp_context7_resolve-library-id` для поиска правильной библиотеки
  5. Используйте `mcp_context7_get-library-docs` для получения актуальной документации
- **Никогда** не полагайтесь на гипотезы, предположения или устаревшую информацию
- **Только после изучения актуальной информации** начинайте писать код или создавать конфигурации

Конец файла
