# Спецификация: Startup Connection Onboarding (iOS/macOS 26)

**Дата:** 2026-05-21
**Статус:** Draft
**Автор:** Gemini CLI

## 1. Цель
Заменить текущий механизм «модального окна при старте» на современный, иммерсивный onboarding-процесс, использующий нативные компоненты iOS 26 (Liquid Glass) и macOS 26.

## 2. Архитектура

### 2.1. Принципы
- **Native-first**: Использование `ContentUnavailableView`, `NavigationStack`, `Form`.
- **Zero Custom UI**: Никаких кастомных анимаций или менеджеров окон.
- **Platform Specific Flow**: 
    - iOS: Navigation Push.
    - macOS: Inline Window Content.

### 2.2. Состояния (TCA)
- Удаление автоматического выставления `state.serverForm` в `ServerListReducer+Connection.swift`.
- Использование `path` в `AppReducer` для управления навигацией к форме настройки на iOS.

## 3. Дизайн

### 3.1. iOS (Liquid Glass)
- **Root**: `AppView` проверяет `store.serverList.servers.isEmpty`.
- **View**: Отображает `ContentUnavailableView` с системным логотипом.
- **Transition**: Кнопка «Add Server» вызывает `store.send(.serverList(.addButtonTapped))`, что приводит к навигационному переходу (push) к `ServerFormView`.

### 3.2. macOS
- **Root**: Окно приложения показывает форму добавления сервера прямо в центре, если список пуст.
- **View**: `ServerListView` адаптируется и показывает форму inline, без использования `sheet`.

## 4. План реализации (кратко)
1. TDD: Тест в `ServerListReducerTests`, проверяющий, что при пустом списке `serverForm` остается `nil`.
2. Refactor: Удаление логики авто-показа в `ServerListReducer+Connection.swift`.
3. UI: Обновление `AppView` для поддержки нативного onboarding-пути.
4. UI: Обновление `ServerListView` для inline-отображения на macOS.
5. Preview: Создание превью для iOS 26 и macOS 26.

## 5. Риски
- Совместимость с текущими тестами навигации (нужно обновить моки).
- Обработка состояния загрузки (чтобы onboarding не мигал при медленном чтении из БД).
