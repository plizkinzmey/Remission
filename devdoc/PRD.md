# PRD: Remission — клиент удалённого управления Transmission (macOS / iOS)

Дата: 2025-10-17

Краткое описание
-----------------
Remission — кроссплатформенное клиентское приложение для macOS и iOS для удалённого управления демоном Transmission (Transmission RPC). Цель — предоставить удобный, быстрый и безопасный интерфейс для мониторинга и управления торрентами на удалённом хосте.

Цели проекта
-----------
- MVP: обеспечить надёжное подключение к Transmission, просмотр списка торрентов, управление (start/pause/remove), добавление торрентов через файл и magnet, базовая аутентификация.
- Обеспечить безопасное хранение учётных данных (Keychain) и защищённое соединение (HTTPS/TLS при поддержке сервера).
- Создать архитектуру, удобную для тестирования и расширения (MVVM, слоёная сеть/домен/пersistence).

Аудитория и кейсы использования
-------------------------------
- Домашние пользователи, управляющие Transmission на NAS/Server.
- Администраторы/техпользователи, которым нужен быстрый доступ и контроль за загрузками с iPhone/iPad/Mac.

Ключевые метрики успеха (KPI)
-----------------------------
- Время отклика UI при сетевом доступе < 200 ms в локальной сети.
- Успех выполнения команд (start/stop/add) > 98% в рабочем окружении.
- Покрытие тестами ключевых компонентов >= 60% для MVP (unit + integration).

Функциональные требования
-------------------------
1. Подключение и конфигурация
   - Добавление сервера Transmission: host, порт, proto (http/https), basic auth (username/password).
   - Проверка соединения и отображение статуса (online/offline).
   - Опция сохранения учётных данных в Keychain.

2. Список торрентов
   - Отображение списка торрентов с полями: id, name, status, progress (%), downloadRate, uploadRate, peers.
   - Сортировка и фильтрация (по статусу, по имени, по прогрессу).
   - Поиск по имени торрента.
   - Обновление в реальном времени: polling (настраиваемый интервал) или push (если сервер/прокси поддерживает).

3. Детали торрента
   - Страница с детальной информацией: список файлов, трекеры, peers, история скорости, путь загрузки.
   - Кнопки действий: Start, Pause, Remove, Verify (recheck), Set Priority.

4. Добавление торрентов
   - Добавление через .torrent файл (из Files/Share) и через magnet-ссылку.
   - Диалог с параметрами добавления (папка загрузки, start-paused, лейблы/теги — опционально).

5. Настройки
   - Конфигурация polling-interval, автоматическое обновление при запуске, лимиты скорости по-умолчанию.
   - Управление сохранёнными серверами (add/edit/remove).

6. Логи и телеметрия
   - Локальное логирование сетевых ошибок и операций (для отладки). Логи не отправляются без согласия пользователя.

Нефункциональные требования
---------------------------
- Производительность: UI должен оставаться отзывчивым при работе с 200+ торрентов (lazy loading, pagination при необходимости).
- Безопасность: все учётные данные хранятся в Keychain; при использовании HTTPS — проверка сертификатов; при Basic Auth — хранение безопасным способом.
- Тестируемость: бизнес-логика отделена от UI (MVVM), сетевой слой имеет интерфейсы для мокирования.
- Локализация: поддержка RU/EN (MVP — RU по умолчанию, EN как опция).
- Доступность: базовая поддержка VoiceOver/Accessibility для важнейших экранов.

Архитектура и дизайн системы
----------------------------
Общая идея: модульное, тестируемое приложение с разделением на слои.

Слои:
- UI (SwiftUI) — платформа-специфичные экраны для iOS и macOS, преимущественно переиспользуемые View-компоненты.
- Presentation (ViewModels) — MVVM: ViewModel содержит состояние и команды, обращается к сервисам бизнес-логики.
- Domain / Services
  - TransmissionClient (Network layer): реализует JSON-RPC вызовы к Transmission (torrent-get, torrent-add, torrent-start/stop, torrent-remove, session-get/set).
  - AuthService: управление учётными данными (Keychain), проверка соединения.
  - SyncService: polling scheduler и механизм обновления состояния; опционально WebSocket/proxy integration если требуется push.
- Persistence
  - Cache: лёгкий кеш (файловая база или SQLite/CoreData) для состояния при оффлайне.

Правила проектирования кода и модульности (важно)
-----------------------------------------------
Чтобы избежать смешения ответственностей, больших файлов и дублирования, применяем строгие соглашения по проектированию и структуре кода. Ниже — конкретные рекомендации, которые обязательно соблюдать:

1) Разделение по ответственности
   - UI (SwiftUI Views): только отображение и минимальная трансформация данных для показа. Никаких сетевых вызовов или долгих вычислений в `View`.
   - Presentation (ViewModels / Presenters / Store): содержит презентационную логику, форматирование данных, реакции на пользовательские действия и вызовы сервисов; не содержит сетевого/постоянного хранения.
   - Domain / Interactors: бизнес-логика, правила валидации, оркестрация нескольких сервисов. Interactors получают данные из репозиториев и обновляют состояние через ViewModel/AppState.
   - Data / Repositories / Services: сетевой клиент (`TransmissionClient`), persistence (Keychain, CoreData/SQLite), mappers. Эти компоненты реализуют CRUD и не содержат бизнес-логики.

2) Модульность и структура каталогов
   - Организация по фичам (feature-based): каждый крупный фичевый модуль в поддиректории `Sources/Features/<FeatureName>/` или в Swift Package: `Features/TransmissionList`, `Features/TorrentDetail`, `Features/AddTorrent`.
   - Общие компоненты (UI/Utils/Models) в `Sources/Shared/` или `Modules/Shared`: `Shared/Views`, `Shared/Models`, `Shared/Services`.
   - Для крупных систем — используем локальные Swift Packages (см. пример TCA-template): `Models`, `Features`, `Views`, `DependencyClients`.

3) Размеры файлов и методов
   - Цель: избегать файлов > 500 строк; если файл растёт — выделять логические части в новые файлы (например: `TorrentListView.swift`, `TorrentListView+Row.swift`, `TorrentListViewModel.swift`).
   - ViewModels должны оставаться компактными (обычно < 300 строк). Сложная логика выносится в Interactors/Services.

4) Повторное использование и отсутствие дублирования
   - Вынести общий UI (строки, иконки, загрузчики, кнопки) в переиспользуемые `View`-компоненты.
   - Общую бизнес-логику и mapping-профили выносить в `Services`/`Mappers` и покрывать тестами.

5) Внедрение зависимостей
   - Использовать DI через конструкторы и протоколы (protocol-oriented DI). Избегать глобальных singletons, кроме `App`-контекста.
   - В CI/тестах предоставлять mock-реализации через протоколы (например, `TransmissionClientProtocol`).

6) State management — обязательный выбор (TCA)
    - Решение: единый подход ко всему проекту — The Composable Architecture (TCA, pointfreeco). Мы не смешиваем MVVM и TCA в одном проекте: весь state-management реализуется через TCA.
    - Обоснование:
       - TCA обеспечивает строгую изоляцию состояния, ясные контракты (State, Action, Environment, Reducer), что уменьшает риск смешения ответственности.
       - Отличная тестируемость: редьюсеры и эффекты легко мокируются и покрываются unit-тестами.
       - Модульность: каждая фича — независимый модуль с собственным стейтом и редьюсером; удобно реиспользовать и интегрировать через композицию редьюсеров.
       - Консистентность: единый паттерн по всему проекту исключает «винегрет» архитектуры.
    - Исключение: только для очень тривиальных вспомогательных Views (например, декоративная обёртка без состояния) допускается простая SwiftUI view без TCA store, но не более того.

Рекомендации по внедрению TCA
--------------------------------
- Добавление зависимости: подключаем `composable-architecture` через Swift Package Manager в `Package.swift` или через Xcode.
- Структура фичи (рекомендуемая):
   - `Features/TorrentList/State.swift` — модель состояния `struct TorrentListState`.
   - `Features/TorrentList/Action.swift` — `enum TorrentListAction`.
   - `Features/TorrentList/Environment.swift` — зависимости (клиент, scheduler, etc.).
   - `Features/TorrentList/Reducer.swift` — `let torrentListReducer = Reducer<TorrentListState, TorrentListAction, TorrentListEnvironment>`.
   - `Features/TorrentList/View.swift` — `TorrentListView` использующий `Store<TorrentListState, TorrentListAction>` и `WithViewStore`.
   - `Features/TorrentList/Tests/` — unit tests для редьюсера и эффектов.

Пример минимального редьюсера и View (упрощённо):

```swift
// State.swift
struct TorrentListState: Equatable {
   var torrents: [Torrent] = []
   var isLoading: Bool = false
}

// Action.swift
enum TorrentListAction: Equatable {
   case onAppear
   case refresh
   case torrentsResponse(Result<[Torrent], APIError>)
}

// Environment.swift
struct TorrentListEnvironment {
   var mainQueue: AnySchedulerOf<DispatchQueue>
   var repository: TorrentRepositoryProtocol
}

// Reducer.swift
let torrentListReducer = Reducer<TorrentListState, TorrentListAction, TorrentListEnvironment> { state, action, env in
   switch action {
   case .onAppear, .refresh:
      state.isLoading = true
      return env.repository.fetchTorrents()
         .receive(on: env.mainQueue)
         .catchToEffect(TorrentListAction.torrentsResponse)

   case let .torrentsResponse(.success(torrents)):
      state.isLoading = false
      state.torrents = torrents
      return .none
   case .torrentsResponse(.failure):
      state.isLoading = false
      return .none
   }
}

// View.swift
struct TorrentListView: View {
   let store: Store<TorrentListState, TorrentListAction>

   var body: some View {
      WithViewStore(self.store) { viewStore in
         List(viewStore.torrents) { t in
            Text(t.name)
         }
         .onAppear { viewStore.send(.onAppear) }
         .refreshable { viewStore.send(.refresh) }
      }
   }
}
```

Требования и правила при использовании TCA
-----------------------------------------
- Каждый feature-модуль обязателен иметь тесты для редьюсера (хотя бы happy path и error path).
- Effects (сетевая логика) должны инкапсулироваться в Environment как функции, чтобы их можно было мокировать в тестах.
- Store и Reducer — основа, все побочные эффекты идут через Effect/Environment.
- Не помещать сложную бизнес-логику в View — View только подписывается на Store и диспатчит Action.

Миграция и поэтапное внедрение
--------------------------------
- Начать с ядра: реализовать TransmissionClientProtocol и базовые репозитории.
- Выделить 1–2 фичи (например, TorrentList и TorrentDetail) и реализовать их целиком через TCA, чтобы установить шаблон.
- После валидации шаблона перевести оставшиеся модули по аналогии.

Причины выбора TCA вместо смешивания MVVM
-------------------------------------------
- Единообразие API и контрактов снижает когнитивную нагрузку при ревью и поддержке.
- TCA предоставляет готовые инструменты для тестирования, композиции и изоляции эффектов, что критично для сетевого клиента и сложной синхронизации состояния.

7) Тестируемость
   - Каждый слой имеет свои unit-тесты: ViewModel/Interactor/Repository.
   - Network layer тестируется с мок-сервером или с mock-обёртками URLSession.
   - UI тесты для критических flow (onboarding, add torrent, main list actions).

8) Code review / CI правила
   - Включить `swift-format` и `swiftlint` в pre-commit и CI.
   - Требовать прогона тестов и линтинга перед merge.
   - Проверять коммиты на смысловую связанность (один коммит — одна логическая правка).

9) Документация внутри кода
   - Писать короткие комментарии для public/protocol API; документировать контракты сервисов и предположения (preconditions).

10) Примеры паттернов (конкретно)
   - Repository pattern:

```swift
protocol TorrentRepository {
    func fetchTorrents() async throws -> [Torrent]
}

final class TransmissionRepository: TorrentRepository {
    private let client: TransmissionClientProtocol
    func fetchTorrents() async throws -> [Torrent] {
        let resp = try await client.torrentGet(fields: [...])
        return resp.map { Torrent(mapFrom: $0) }
    }
}
```

   - Interactor usage in ViewModel:

```swift
final class TorrentListViewModel: ObservableObject {
    @Published var items: [TorrentViewModel] = []
    private let interactor: TorrentListInteractor

    func refresh() {
        Task {
            let domain = try await interactor.loadTorrents()
            self.items = domain.map(TorrentViewModel.init)
        }
    }
}
```

11) Ошибки проектирования, которых нужно избегать
   - Не выполнять сетевые запросы прямо в `View`.
   - Не смешивать persistence/serialization в ViewModels.
   - Не клонировать код: повторяющийся код должен переехать в helper/extension/shared component.

Ресурсы и примеры
------------------
- Clean Architecture SwiftUI example: `nalexn/clean-architecture-swiftui` (см. рекомендации Context7).
- Modular TCA template: `ethanhuang13/swiftui-tca-template` — хорошая отправная точка для организации пакетов и модулей.

Включение этих правил в PRD и в гайдлайны разработки позволит избежать «винегрета» кода и получить модульный, поддерживаемый проект.

Технологические решения
----------------------
- Язык/фреймворки: Swift + SwiftUI; архитектура MVVM; модуль бизнес-логики оформлен как Swift Package для повторного использования.
- Network: URLSession-based client, JSON parsing через Codable; обёртка для retry/backoff.
- Storage: Keychain для секретов; UserDefaults/Files/CoreData для пользовательских настроек и кеша (выбрать CoreData при необходимости сложной модели).
- Dependency management: по возможности минимально — использовать встроенные фреймворки; при добавлении сторонних либ — через Swift Package Manager.
- Тесты: XCTest для unit и интеграционных тестов; XCUITest для UI.
- CI: GitHub Actions — сборка, unit-тесты, линтинг (swiftlint если добавим), запуск UI-тестов на симуляторе.

Swift 6 — требования и лучшие практики
-------------------------------------
Поскольку проект разрабатывается на Swift 6, важно заранее зафиксировать требования и инструменты для корректной миграции и использования новых возможностей языка:

- Язык и режим компилятора
   - В Xcode указать Swift Language Version = 6 (или эквивалентный флаг для SwiftPM/Xcode build settings).
   - Для SwiftPM/cli-команд можно указывать:

```bash
swift build -Xswiftc -swift-version 6
```

- Миграционные флаги
   - При переносе/миграции включайте рекомендуемые флаги миграции для новых языковых фич, чтобы получить автоматические fix-it подсказки. Примеры:

```bash
-enable-upcoming-feature ExistentialAny:migrate
-enable-upcoming-feature NonisolatedNonsendingByDefault:migrate
```

   - Эти флаги помогут автоматически добавить `any` для экзистенциальных типов и корректно обработать изменения связаные с отправляемостью/несенабельностью (Sendable).

- Парадигмы и безопасность конкуренции
   - Используйте современные конструкции concurrency (async/await, Task, actors) и явно отмечайте типы как `Sendable` там, где требуется.
   - Обращайте внимание на атрибуты `@MainActor` и `@preconcurrency` в публичных API (SwiftUI/Frameworks), это поможет избежать race conditions.
   - Для тестов используйте абстракцию времени (`swift-clocks`) для детерминированного тестирования асинхронного поведения.

- Инструменты форматирования и линтинга
   - Форматирование: `swift-format` (run as pre-commit or CI step):

```bash
swift-format -i <paths>
```

   - Статический анализ/стиль: `swiftlint` — настроить правила и запускать в CI.

- Рекомендуемые библиотеки экосистемы
   - Логирование: `swift-log` (apple/swift-log) для унифицированного логирования.
   - Утилиты коллекций: `swift-collections` (apple/swift-collections) при необходимости эффективных структур данных.
   - Часы/тестируемость времени: `swift-clocks` (pointfreeco/swift-clocks) для тестов и таймеров.
   - Форматирование и миграция: использовать встроенные средства миграции Swift (APIDiff migrator) и `swift-format`.

- CI/релизные проверки
   - В CI добавить шаги: установка Swift toolchain (если нужен Swift 6 preview), swift-format, swiftlint, сборка с флагом swift-version, unit tests, integration tests (docker-compose Transmission).

- Обратите внимание при проектировании API
   - Возможны изменения в сигнатурах, требованиях протоколов и ownership-модели — проектировать внутренние API с учётом устойчивости к будущим изменениям (использование протоколов/абстракций, адаптеров версии API Transmission).

Включение этих пунктов в процесс разработки и CI значительно снизит риски, связанные с переходом на Swift 6 и использованием новых языковых возможностей.

Интеграция с Transmission RPC
------------------------------
1. Протокол: JSON-RPC поверх HTTP(S). Примеры методов:
   - `torrent-get` — получить список/поля торрентов
   - `torrent-start` / `torrent-start-now` — запуск
   - `torrent-stop` — пауза
   - `torrent-add` — добавление .torrent или magnet
   - `torrent-remove` — удаление
   - `session-get` / `session-set` — параметры сессии

2. Поля модели (пример mapping):
   - id (id)
   - name (name)
   - status (status)
   - progress (percentDone)
   - downloadRate / uploadRate (rateDownload, rateUpload)
   - peers (peersConnected)

3. Авторизация: Transmission обычно использует Basic Auth. Клиент должен поддерживать хранение и отправку Basic заголовков, а также поддерживать TLS.

4. Обработка ошибок:
   - Регистрировать и отображать сетевые/RPC-ошибки в UI с понятными сообщениями.
   - Механизмы retry с экспоненциальной задержкой для transient ошибок.
   - В случае несовместимости версии — показать предупреждение и предложить проверить версию сервера.

UX и пользовательские потоки
---------------------------
1. Onboarding: первая настройка сервера — шаги: ввести host, port, выбор HTTP/HTTPS, логин/пароль, тест соединения. Опция сохранить пароль в Keychain.

2. Главный экран: список торрентов с поиском, фильтрами и кнопками быстрого управления (play/pause/remove). Интерактивные элементы показывают прогресс и скорости.

3. Экран торрента: подробности, список файлов с возможностью приоритизации, трекеры, peers, лог активности.

4. Добавление торрента: диалог/экран для выбора .torrent или вставки magnet; опции (папка загрузки, start-paused).

Команда и роли
--------------
- Product Owner / PM — требования, приоритизация.
- iOS/macOS разработчик(s) — реализация UI и логики.
- Backend/Integration (по необходимости) — тестовый образ Transmission/CI интеграция.
- QA — авто/ручные тесты.
- Designer — базовый UX и иконки.

Дорожная карта (высокоуровнево)
-----------------------------
- Sprint 0 (2 недели): проектная установка, CI, базовая архитектура, простая UI-тележка, implement TransmissionClient skeleton.
- MVP (4-6 недель): подключение к серверу, список торрентов, управление (start/pause/remove), добавление torrent, сохранение сервера, Keychain.
- v1 (2–3 месяца): realtime updates (polling/optimization), caching, UI polish, basic settings, localization RU/EN.
- v2: advanced features (scheduling, bandwidth scheduling, analytics), improved offline support, plugins.

Критерии приёмки
-----------------
- Успешное подключение и проверяемые команды к Transmission в тестовом окружении.
- UI корректно отображает список и детали для 50+ торрентов.
- Unit-тесты покрывают сетевой слой и ViewModel для ключевых сценариев.
- Документация: README/CONTRIBUTING и `.github/copilot-instructions.md` обновлены.

Риски и меры по снижению
-----------------------
- Несовместимость с разными версиями Transmission — добавить handshake/версионную проверку и сообщать пользователю о возможных ограничениях.
- Хранение паролей — использовать Keychain и минимизировать экспорт логов с секретами.
- Нестабильная сеть — implement retry/backoff и кеширование состояния для оффлайн-режима.

План тестирования
-----------------
- Unit tests: TransmissionClient (моки), ViewModels.
- Integration tests: поднять локальный экземпляр Transmission (Docker) в CI и прогонять основные сценарии (connect/add/start/stop/remove).
- UI tests: XCUITest для основных пользовательских потоков (onboarding, add torrent, main list actions).

Документы и артефакты
---------------------
- `devdoc/PRD.md` (этот документ)
- `README.md` — руководство по сборке и запуску
- `CONTRIBUTING.md` — правила коммитов (см. `.github/copilot-instructions.md` — коммиты на русском)
- Тестовые сценарии и скрипты для поднятия тестовой среды Transmission (Docker-compose) — добавить в `devops/` при необходимости.

Открытые вопросы
----------------
- Поддерживаемые версии Transmission (минимальная версия) — требуется уточнение.
- Нужна ли поддержка прокси/WebSocket-based push уведомлений — определить в зависимости от требований к realtime.
- Требования к аналитике/telemetry и пользовательскому телеметриям (GDPR/consent) — нужно решение.

Следующие шаги
----------------
1. Уточнить поддерживаемую версию Transmission и требования к TLS.
2. Согласовать минимально необходимый набор полей в `torrent-get` (для оптимизации payload).
3. Создать тикеты/epics в трекере: Network client, Auth, Main List UI, Torrent Detail, Add Torrent flow, Persistence, CI.
4. Подготовить dev окружение: docker-compose с Transmission для интеграционных тестов.

Конец документа
