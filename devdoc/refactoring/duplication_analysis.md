# Анализ дублирования кода и возможности рефакторинга

Анализ проведен: Пятница, 23 января 2026 г.

В ходе анализа были выявлены следующие области со значительным дублированием кода или возможностями для архитектурного улучшения.

## 1. Шаблонный код RPC методов (Boilerplate) - **ВЫПОЛНЕНО**
**Локация:** `Remission/Network/Transmission/TransmissionClient+RPCMethods.swift`

**Проблема:**
Каждый метод Transmission RPC следовал идентичному шаблону.

**Решение:**
- Внедрен `RPCMethod` enum для безопасных имен методов.
- Добавлены helper-методы для `Dictionary` для упрощения создания аргументов.
- Методы переписаны с использованием нового API.

## 2. Дублирование логики соединения - **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Network/Transmission/ServerConnectionProbe.swift`
- `Remission/Network/Transmission/TransmissionConnectionTester.swift`

**Решение:**
- `TransmissionConnectionTester.swift` был идентифицирован как неиспользуемый (dead code) и удален.
- `ServerConnectionProbe.swift` остался единственным источником правды для проверки соединений.

## 3. Шаблонный код TCA (Настройка сервера) - **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Features/ServerEditor/ServerEditorFeature.swift`
- `Remission/Features/Onboarding/OnboardingFeature.swift`
- `Remission/Features/Shared/ServerConfiguration/` (новый компонент)

**Решение:**
- Создан общий `ServerConfigurationReducer`, который берет на себя логику проверки соединения, обработки self-signed сертификатов и валидации формы.
- `OnboardingReducer` и `ServerEditorReducer` переписаны с использованием этого общего компонента через `Scope`.
- Общие модели вынесены в `ServerConfigurationModels.swift`.

## 4. Фрагментация маппинга домена - **ВЫПОЛНЕНО**
**Локация:** `Remission/Domain/TransmissionDomainMapper*.swift` (несколько расширений)

**Решение:**
- Метод `decode` и вспомогательные методы для работы с типами (например, `int64Value`) перенесены в `+Shared.swift`.
- Устранено дублирование вспомогательной логики в `+Torrent.swift` и `+Session.swift`.

## 5. Тестовые фикстуры (Test Fixtures)
**Локации:**
- `Remission/Features/ServerEditor/ServerEditorFeature.swift`
- `Remission/Features/Onboarding/OnboardingFeature.swift`
- `Remission/Features/Settings/SettingsFeature.swift` (потенциально)

**Проблема:**
Несколько функциональных модулей (фич) включают настройку параметров сервера (хост, порт, авторизация, SSL). Логика для:
- Управления состоянием формы.
- Валидации ввода.
- Отрисовки (рендеринга) этих полей в интерфейсе.

вероятно, повторяется в этих фичах.

**Возможность рефакторинга:**
Выделить переиспользуемый TCA-компонент (например, `ServerConfigurationFormFeature`), который будет управлять состоянием и действиями для деталей сервера. Его можно будет встраивать в родительские фичи, такие как Onboarding или Editor.

## 4. Фрагментация маппинга домена
**Локация:** `Remission/Domain/TransmissionDomainMapper*.swift` (несколько расширений)

**Проблема:**
Логика `TransmissionDomainMapper` разделена на несколько файлов (`+Torrent`, `+Session`, `+ServerConfig`). Хотя разделение файлов полезно для организации, базовая логика преобразования примитивных типов JSON (например, необработанных битовых полей, временных меток Unix, целых чисел статуса) в безопасные типы Swift, скорее всего, повторяет ручные преобразования.

**Возможность рефакторинга:**
Централизовать общую логику преобразования значений (например, `convertDate`, `convertStatus`) в приватных помощниках или общей внутренней утилите внутри маппера, чтобы уменьшить многословность маппинга отдельных полей.

## 5. Тестовые фикстуры (Test Fixtures)
**Локация:** `RemissionTests/` (например, `TransmissionClientHappyPathFixturesTests`, `TransmissionFixturesTests`)

**Проблема:**
Тесты часто настраивают мок-ответы JSON от Transmission и состояния сервера. Этот код настройки, вероятно, копируется или слегка модифицируется в различных тестовых наборах.

**Возможность рефакторинга:**
Создать выделенную фабрику тестов `TransmissionTestFactory` или строитель фикстур `FixtureBuilder`, который будет генерировать корректные мок-данные с настраиваемыми параметрами, централизуя знания о том, как выглядит «валидный ответ».