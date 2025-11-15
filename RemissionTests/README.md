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
- Для точечной проверки редьюсера списка торрентов используйте
  `xcodebuild test -scheme Remission -destination 'platform=macOS,arch=arm64' -only-testing:RemissionTests/TorrentListFeatureTests`.
  Файл `TorrentListFeatureTests.swift` покрывает happy/error path, поиск/фильтры без сетевых запросов и ручной refresh с `TestClock`.

### Torrent List smoke-сценарий

- `xcodebuild test -scheme Remission -testPlan RemissionUITests -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:RemissionUITests/RemissionUITests/testTorrentListSearchAndRefresh`
- Требуемые launch-аргументы:
  - `--ui-testing-fixture=torrent-list-sample`
  - `--ui-testing-scenario=torrent-list-sample`

Эти аргументы активируют in-memory `ServerConnectionEnvironment` с фикстурными торрентовыми данными (downloading/seeding/error) и гарантируют, что polling и поиск будут выполняться без реального Transmission.

Фикстурные данные описаны в `RemissionTests/Fixtures/Transmission/Torrents/torrent-list-sample.json` и преобразуются в доменные модели через `TorrentFixture`. Один и тот же набор используется и в unit-тестах (`TorrentListFeatureTests`), и в UI-сценарии, что делает результаты воспроизводимыми.

UI-тест «Добавление сервера» использует аргумент `--ui-testing-scenario=onboarding-flow`, который приложение читает при старте. Этот аргумент включает in-memory реализации `ServerConfigRepository`, `CredentialsRepository`, `ServerConnectionProbe` и `OnboardingProgressRepository`, поэтому тест изолирован от Keychain и файловой системы. Для теста списка серверов доступен аргумент `--ui-testing-fixture=server-list-sample`. Скриншоты предупреждения HTTP и диалога доверия автоматически прикладываются к прогону (`onboarding_http_warning`, `onboarding_trust_prompt`). Для торрентов UI-тест прикладывает `torrent_list_fixture` и `torrent_list_search_result`.

## Troubleshooting

- **Stuck polling / stale данные в TorrentListFeatureTests** — убедитесь, что `ServerDetailReducer` диспатчит `.torrentList(.teardown)` перед заменой окружения. В тестах используйте `ServerConnectionEnvironment.testEnvironment(...)` и переинициализируйте состояние перед каждым `store.send(.task)`.
- **UI-тест torrent-list зависает на «Подключение»** — очистите аргументы схемы и снова добавьте `--ui-testing-fixture=torrent-list-sample`. Этот аргумент выключает реальный Transmission и подставляет предсказуемые данные. Также можно удалить приложение с симулятора (`xcrun simctl uninstall booted com.remission.app`) для сброса сохранённых серверов.
- **Мок `ServerConnectionEnvironment` не применяется** — убедитесь, что вызываете `environment.apply(to: &dependencies)` внутри эффекта перед чтением `torrentRepository`. Это требование описано в `devdoc/plan.md` (Веха 6).

## Справочные материалы

- [Context7 Guide](../devdoc/CONTEXT7_GUIDE.md) — Как исследовать документацию новых библиотек
- [TCA Testing Guide](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TestingTCA.md) — Best practices тестирования TCA reducers и effects
- [Swift Dependencies](https://github.com/pointfreeco/swift-dependencies) — Официальная документация по фреймворку Dependencies
- [AppDependencies.swift](../Remission/AppDependencies.swift) — Центральное место конфигурации зависимостей

## Фикстуры деталей торрента

- `DomainFixtures.torrentMetadataPending` — состояние торрента без метаданных (нулевые размеры, пустые файлы/трекеры) для проверки fallback UI и тестов `TorrentDetailFeature+LoadTests`. Используйте этот снапшот, если нужно воспроизвести edge-case «сервер ещё не вернул детали».

````
