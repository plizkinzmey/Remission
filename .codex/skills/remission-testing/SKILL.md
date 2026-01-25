---
name: remission-testing
description: "Писать и чинить тесты в проекте Remission (Swift Testing + TCA TestStore + зависимости через ServerConnectionEnvironment). Используй при любых изменениях reducer/эффектов/поллинга/ретраев, при падениях xcodebuild test, и когда нужно поднять покрытие последовательно файл за файлом."
---

# Remission Testing

## Цель
Быстро добавлять надёжные тесты без ломания DI, поллинга и долгоживущих эффектов.

## Рабочий цикл
1. Найди ближайшие существующие тесты для фичи и повтори стиль.
2. Для reducer-логики используй `TestStoreFactory.makeTestStore`.
3. Для времени используй `TestClock` через `dependencies.appClock = .test(clock:)`.
4. Всегда заверши долгоживущие эффекты действием `.teardown` (или эквивалентом).
5. Прогони `xcodebuild test -scheme Remission -configuration Debug -destination 'platform=macOS,arch=arm64' | xcbeautify`.

## Критичное правило про зависимости
Если в состоянии есть `connectionEnvironment`, он может перетереть замоканные зависимости.

Правильно:
- Создай `ServerConfig(id: ...)` с нужным `serverID`.
- Собери кастомный `TorrentRepository.testValue`/`SessionRepository.testValue`.
- Передай их через `ServerConnectionEnvironment.testEnvironment(...)`.
- Установи `connectionEnvironment: environment` в initialState.

Неправильно:
- Мокать `dependencies.torrentRepository`, но использовать `connectionEnvironment: .previewValue`.

## Что читать дальше
- TCA reducer tests: `references/tca-teststore.md`
- Простые/утилитарные тесты: `references/pure-and-mapper-tests.md`
