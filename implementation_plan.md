# UI Recovery Implementation Plan

## Цель

Вернуть presentation-layer к последнему корректному состоянию `f057820` (релиз 0.12.3), не откатывая runtime/storage isolation, HTTP-warning, актуальную TCA-навигацию add-server и Transmission RPC-исправления, попавшие в v0.13.0.

## Границы

- Восстановить SwiftUI Views и удалённые shared components из `f057820`.
- Сохранить `AppRuntimeEnvironment`, текущий `AppReducer.Path`, HTTP alert binding и исправления macOS lifecycle window configurator.
- Сохранить локальную незакоммиченную правку `ServerConfigurationView.swift`.
- Не менять `Package.resolved`; `project.pbxproj` менять только если сборка докажет, что восстановленные source-файлы не подхватываются синхронизированной группой.

## Задачи

1. Восстановить UI-исходники к `f057820`, исключив `ServerConfigurationView.swift` и текущий `MacWindowTranslucency.swift`.
2. Вручную перенести нужные functional deltas в `AppView`, `ServerFormView` и `ServerConfigurationView`.
3. Запустить build/test; только при реальном compile failure точечно изменить project metadata.
4. Выполнить форматирование, линтинг, iOS/macOS tests и post-implementation review.

## Риски

- Нельзя вернуть вложенный `NavigationStack` для формы, открываемой через `AppReducer.Path` на iOS.
- Нельзя потерять HTTP confirmation alert или локальную пользовательскую правку кнопки подключения.

## Верификация

- `swift-format`, `swiftlint`, iOS tests на iPhone 12, macOS tests и `Scripts/validate-dead-code.sh`.
