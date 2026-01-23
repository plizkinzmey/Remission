# Анализ дублирования кода и возможности рефакторинга (Часть 5)

Анализ проведен: Пятница, 23 января 2026 г.

Пятый этап анализа был сфокусирован на архитектурной чистоте инициализации сетевых компонентов и устранении размытой ответственности в логике добавления торрентов.

## 1. Дублирование конфигурации TransmissionClient — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Network/Transmission/TransmissionClient.swift` (новый метод)
- `Remission/Network/Transmission/ServerConnectionProbe.swift`
- `Remission/App/ServerConnectionEnvironment.swift`

**Решение:**
- В `TransmissionClient` добавлен статический метод-фабрика `.live(config:clock:appLogger:category:)`.
- Вся логика настройки контекста логирования, создания `DefaultTransmissionLogger` и инъекции зависимостей теперь сосредоточена в одном методе.
- Места вызова обновлены для использования этой фабрики.

## 2. Размытие ответственности в AddTorrent (Source vs Feature) — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Features/TorrentAdd/AddTorrentFeature.swift`
- `Remission/Views/TorrentAdd/AddTorrentSourceView.swift`

**Решение:**
- Удален избыточный `AddTorrentSourceReducer`. Вся логика выбора источника (включая вставку из буфера обмена) перенесена в `AddTorrentReducer`.
- `AddTorrentSourceView` переведена на использование основного стора добавления торрентов.
- Устранено дублирование стейтов и экшенов для выбора файлов и magnet-ссылок.

## 3. Дублирование логики нормализации путей — **ВЫПОЛНЕНО**
**Локации:**
- `Remission/Shared/TransmissionPathNormalization.swift` (новая утилита)
- `Remission/Features/TorrentAdd/AddTorrentReducer+Submit.swift`

**Решение:**
- Логика объединения базовой директории загрузки и пользовательского пути вынесена в отдельную утилиту `TransmissionPathNormalization`.
- Это гарантирует корректную работу со слешами и абсолютными/относительными путями во всем приложении.

## 4. Разрозненные паттерны компоновки экранов (UI Layout)
**Локации:** По всему проекту.

**Статус:** Оставлено для будущих улучшений. Основные инфраструктурные дубликаты устранены, вьюхи стали чище за счет выноса `TorrentRowView` и унификации секций в деталях.