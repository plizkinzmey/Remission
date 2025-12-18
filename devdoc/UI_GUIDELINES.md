# Remission UI Guidelines (Glass + Glow)

Цель: единая “живущая” визуальная система (цвет, прозрачности, стекло/линза) для iOS + macOS с поддержкой светлой/тёмной темы.

## Принципы

- **Одна палитра, много прозрачностей**: вместо “радуги” используем 1 основной акцент + семантические цвета (success/warning/destructive), а глубину создаём уровнями прозрачности.
- **Фон задаёт настроение**: градиент + мягкие glow-пятна — главный источник “яркости”; компоненты лишь подчёркивают.
- **Стекло только там, где это усиливает UX**: небольшие интерактивные элементы (pills/chips/toolbars/actions) выигрывают от `glassEffect` сильнее, чем большие поверхности.
- **Читаемость важнее эффектов**: в светлой теме все эффекты менее агрессивные; тени/обводки слабее.

## Токены и код-стандарты

Единые токены находятся в:

- `Remission/Views/Shared/AppTheme.swift`
- `Remission/Views/Shared/AppBackgroundView.swift`
- `Remission/Views/Shared/AppChrome.swift`

Используйте только эти public-хелперы вью:

- `View.appRootChrome()` — общий фон + акцентный цвет.
- `View.appCardSurface(cornerRadius:)` — карточки/панели.
- `View.appPillSurface()` — pills/chips/toolbar capsules.

## Фон (Background)

- На корневых экранах используйте `appRootChrome()` и **не перекрывайте** фон непрозрачными `Color(.systemBackground)`/`windowBackgroundColor`.
- Для `List`/`Form`/`ScrollView` на iOS/macOS скрывайте системный фон:
  - `scrollContentBackground(.hidden)`
  - `listRowBackground(Color.clear)` (если нужен прозрачный ряд)

## Поверхности (Surfaces)

### Card (карточка)

Использование:

```swift
VStack { ... }
    .padding(12)
    .appCardSurface(cornerRadius: 14)
```

Назначение:

- карточки серверов
- connection/status блоки
- строки на macOS, если они не в `List`

### Pill (капсула)

Использование:

```swift
HStack { ... }
    .padding(.horizontal, 12)
    .frame(height: 34)
    .appPillSurface()
```

Назначение:

- toolbar controls (поиск/кнопки)
- actions pill (play/pause/verify/remove)
- фильтры/чипы статусов (если нужно)

## Glass / “Lens” эффект

Доступно на iOS/macOS 26+:

- `glassEffect(_:in:)`
- `glassEffectTransition(_:)`
- `GlassEffectContainer { ... }`

Рекомендации:

- `glassEffect` применяем **к форме** (capsule/rounded rect), а не к содержимому.
- `glassEffectTransition(.materialize)` используем для появления/исчезновения интерактивных “плашек” (например, actions pill).
- Для больших поверхностей (экран целиком, огромные карты) обычно достаточно `.regularMaterial` + stroke + тень.

## Цвет и контраст (Light/Dark)

- Все токены должны зависеть от `ColorScheme` (см. `AppTheme`).
- В светлой теме:
  - glow слабее
  - тени мягче
  - stroke темнее (чёрный с небольшой opacity), чтобы не “замыливать” края

## Do / Don’t

Do:

- использовать `appCardSurface`/`appPillSurface` вместо кастомных `.regularMaterial + stroke` в каждом экране
- держать радиусы и отступы консистентными (карточки 14, pills 34 по высоте)
- скрывать системные фоны у `List`/`Form`, если нужен общий градиент

Don’t:

- добавлять новые “случайные” цвета без токенов
- делать непрозрачные задники, убивающие фон
- применять стекло на большие области без необходимости (падает читаемость)

