Это репозиторий минимального SwiftUI-приложения (macOS/iOS), созданного из шаблона. Цель этих инструкций — быстро ввести в работу AI-агентов, описав структуру проекта, соглашения и полезные команды.

Ключевые факты
- Язык: Swift (SwiftUI)
- Точка входа приложения: `Remission/Remission/RemissionApp.swift` — `@main` App struct.
- Основной UI: `Remission/Remission/ContentView.swift` — упрощённый `View`, используемый в `WindowGroup`.
- Тесты: `Remission/RemissionTests/RemissionTests.swift` и UI-тесты в `Remission/RemissionUITests/`.
- В репозитории не было `.github` или README — этот файл служит главным источником инструкций для агентов.

Что менять и почему
- Небольшие изменения интерфейса/фич: редактируйте `ContentView.swift` и добавляйте новые Swift-файлы в папку `Remission/Remission/`.
- Жизненный цикл приложения/конфигурация: редактируйте `RemissionApp.swift` (он отвечает за корневой вид).
- Тесты размещаются в `RemissionTests/` (unit) и `RemissionUITests/` (UI). В тестах используется модуль `Testing` и атрибут `@Test` (см. `RemissionTests/RemissionTests.swift`).

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

Интеграции и внешние зависимости
- В репозитории нет настроенных внешних пакетов (минимальный шаблон). Если нужно добавить зависимости — предпочтительнее использовать Swift Package через Xcode или обновить настройки пакетов проекта.

Рекомендации для AI-агентов при правках
- Делайте маленькие атомарные коммиты — одна логическая правка (вью, view model, тест).
- Не перестраивайте структуру проекта без запроса — сохраняйте простую точку входа приложения. Если требуется рефакторинг — опишите мотивацию в сообщении коммита.
- При добавлении тестов следуйте использованию `Testing` и `@Test`, включите хотя бы одно простое утверждение.

Политика коммитов
- Все сообщения коммитов должны быть строго на русском языке. Это касается как короткой строки (summary), так и, при необходимости, описания (body). Примеры:
    - Правильно: `Добавить экран настроек` или `Исправить баг с отображением Preview`
    - Неправильно: `Add settings screen` или `Fix preview bug`

Если что-то непонятно
- Спросите владельца репозитория о таргете (iOS или macOS), устройстве/симуляторе для тестов и о допустимости добавления Swift Package зависимостей.

Конец файла
