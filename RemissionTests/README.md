# RemissionTests

## Dependency overrides (How tests are wired)

В проекте тесты строятся вокруг TCA `TestStore` и централизованной настройки зависимостей через `swift-dependencies`.

Базовая точка входа для unit-тестов:
- `/Users/plizkinzmey/SRC/Remission/RemissionTests/Support/TestStoreFactory.swift`
  - `TestStoreFactory.makeTestStore(...)` по умолчанию устанавливает зависимости через `AppDependencies.makeTestDefaults()`,
    затем позволяет точечно переопределить нужное.

Пример для `TestStore`:

```swift
@MainActor
let store = TestStoreFactory.makeTestStore(
    initialState: AppReducer.State(),
    reducer: AppReducer()
) { dependencies in
    dependencies.transmissionClient = .placeholder
}
```

Для Preview обычно используется `AppDependencies.makePreview()` (см. превью в `AppView`).

## Запуск тестов

- `xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e'` — полный набор unit + UI тестов, включая сценарий онбординга.
- `xcodebuild test -scheme Remission -sdk macosx` — smoke для macOS-таргетов.
- Для точечной проверки редьюсера списка торрентов используйте
  `xcodebuild test -scheme Remission -destination 'platform=macOS,arch=arm64' -only-testing:RemissionTests/TorrentListFeatureTests`.
  Файл `TorrentListFeatureTests.swift` покрывает happy/error path, поиск/фильтры без сетевых запросов и ручной refresh с `TestClock`.

### Torrent List smoke-сценарий

- `xcodebuild test -scheme Remission -testPlan RemissionUITests -destination 'platform=iOS Simulator,name=iPhone 16e' -only-testing:RemissionUITests/RemissionUITests/testTorrentListSearchAndRefresh`
- Требуемые launch-аргументы:
  - `--ui-testing-fixture=torrent-list-sample`
  - `--ui-testing-scenario=torrent-list-sample`

Эти аргументы активируют in-memory `ServerConnectionEnvironment` с фикстурными торрентовыми данными (downloading/seeding/error) и гарантируют, что polling и поиск будут выполняться без реального Transmission.

Фикстурные данные преобразуются в доменные модели через `TransmissionDomainMapper`/fixtures-хелперы в `RemissionTests/Support/`.

UI-тест «Добавление сервера» использует аргумент `--ui-testing-scenario=onboarding-flow`, который приложение читает при старте. Этот аргумент включает in-memory реализации `ServerConfigRepository`, `CredentialsRepository`, `ServerConnectionProbe` и `OnboardingProgressRepository`, поэтому тест изолирован от Keychain и файловой системы. Для теста списка серверов доступен аргумент `--ui-testing-fixture=server-list-sample`. Скриншоты предупреждения HTTP и диалога доверия автоматически прикладываются к прогону (`onboarding_http_warning`, `onboarding_trust_prompt`). Для торрентов UI-тест прикладывает `torrent_list_fixture` и `torrent_list_search_result`.

## Troubleshooting

- **Stuck polling / stale данные в TorrentListFeatureTests** — убедитесь, что `ServerDetailReducer` диспатчит `.torrentList(.teardown)` перед заменой окружения. В тестах используйте `ServerConnectionEnvironment.testEnvironment(...)` и переинициализируйте состояние перед каждым `store.send(.task)`.
- **UI-тест torrent-list зависает на «Подключение»** — очистите аргументы схемы и снова добавьте `--ui-testing-fixture=torrent-list-sample`. Этот аргумент выключает реальный Transmission и подставляет предсказуемые данные. Также можно удалить приложение с симулятора (`xcrun simctl uninstall booted com.remission.app`) для сброса сохранённых серверов.
- **Мок `ServerConnectionEnvironment` не применяется** — убедитесь, что вы применяете server-scoped окружение к `DependencyValues` перед использованием репозиториев. Описание паттерна есть в `/Users/plizkinzmey/SRC/Remission/Doc/ProjectMap.md`.

## Справочные материалы

- [TCA Testing Guide](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/TestingTCA.md) — Best practices тестирования TCA reducers и effects
- [Swift Dependencies](https://github.com/pointfreeco/swift-dependencies) — Официальная документация по фреймворку Dependencies
- [AppDependencies.swift](../Remission/App/AppDependencies.swift) — Центральное место конфигурации зависимостей

## Фикстуры деталей торрента

- `DomainFixtures.torrentMetadataPending` — состояние торрента без метаданных (нулевые размеры, пустые файлы/трекеры) для проверки fallback UI и тестов `TorrentDetailFeature+LoadTests`. Используйте этот снапшот, если нужно воспроизвести edge-case «сервер ещё не вернул детали».

````
