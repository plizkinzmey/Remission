# RemissionTests

## Dependency overrides

`RemissionTests/Support/DependencyOverrides.swift` собирает шаблоны переопределения зависимостей и используется в Swift Testing и SwiftUI Preview.

- `DependencyValues.previewDependenciesWithMocks()` подставляет безопасные моки `CredentialsRepository` и `TransmissionClient` для Preview/UITests.
- `DependencyValues.testDependenciesWithOverrides { ... }` строит набор зависимостей для TestStore и позволяет в один вызов переопределить нужные значения.

Пример для `TestStore`:

```swift
let store = TestStoreFactory.makeAppTestStore(configure: { dependencies in
    dependencies = .testDependenciesWithOverrides {
        $0.transmissionClient = .previewMock(sessionGet: {
            TransmissionResponse(result: "stub")
        })
    }
})
```

Пример для Preview/Store:

```swift
Store(initialState: state) {
    Reducer()
} withDependencies: {
    $0 = .previewDependenciesWithMocks()
}
```

Чтобы добавлять моковые реализации для других зависимостей, редактируйте `configure` и переопределяйте нужные ключи (например, `credentialsRepository`, `appClock`, `repository`).

## Запуск тестов

- `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 15'` — полный набор unit + UI тестов, включая сценарий онбординга.
- `xcodebuild test -scheme Remission -sdk macosx` — smoke для macOS-таргетов.

UI-тест «Добавление сервера» использует аргумент `--ui-testing-scenario=onboarding-flow`, который приложение читает при старте. Этот аргумент включает in-memory реализации `ServerConfigRepository`, `CredentialsRepository`, `ServerConnectionProbe` и `OnboardingProgressRepository`, поэтому тест изолирован от Keychain и файловой системы. Для теста списка серверов по-прежнему доступен аргумент `--ui-testing-fixture=server-list-sample`. Скриншоты предупреждения HTTP и диалога доверия автоматически прикладываются к прогону (`onboarding_http_warning`, `onboarding_trust_prompt`).

## Справочные материалы

- [Context7 Guide](../devdoc/CONTEXT7_GUIDE.md) — Как исследовать документацию новых библиотек
- [TCA Testing Guide](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TestingTCA.md) — Best practices тестирования TCA reducers и effects
- [Swift Dependencies](https://github.com/pointfreeco/swift-dependencies) — Официальная документация по фреймворку Dependencies
- [AppDependencies.swift](../Remission/AppDependencies.swift) — Центральное место конфигурации зависимостей

````
