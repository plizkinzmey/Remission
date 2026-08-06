# Remission: План рефакторинга и правила качества кода

*Версия: 1.0 | Дата: 2025 | Статус: Активный (для новых PR обязательно к соблюдению)*

---

## 🎯 Цель

Привести кодовую базу к состоянию, где:
- Конкурентность строгая и безопасная (Swift 6 complete)
- Никакого файла > 300 строк, никакого редьюсера > 50 actions
- UI-тесты покрывают критические пользовательские сценарии
- CI гоняет iOS + macOS, быстрые проверки < 10 мин

---

## 📋 План рефакторинга (последовательный, поэтапный)

### Фаза 0: Подготовка (0–1 день) — **БЕЗ ИЗМЕНЕНИЙ КОДА**
- [ ] Зафиксировать текущие метрики: `wc -l` по файлам, кол-во `@unchecked Sendable`, размер редьюсеров
- [ ] Добавить в CI job `metrics-check` (см. «Правила» ниже)
- [ ] Обновить `Doc/EngineeringAudit.md` — убрать устаревшее «нет SWIFT_STRICT_CONCURRENCY»
- [ ] Согласовать с командой: пороговые значения (см. правила)

### Фаза 1: Конкурентность — безопасность памяти (P0) — **1–2 дня**

| Задача | Файлы | Ожидаемый результат |
|--------|-------|---------------------|
| 1.1 Создать `ActorBasedStore` (один общий utility) | `Remission/Storage/ActorBasedStore.swift` (NEW) | Единая реализация thread-safe UserDefaults storage |
| 1.2 Мигрировать `OnboardingProgressRepository` | `OnboardingProgressRepository.swift` | Убрать 2 `@unchecked Sendable` + `NSLock` |
| 1.3 Мигрировать `HttpWarningPreferencesStore` | `HttpWarningPreferencesStore.swift` | Убрать 2 `@unchecked Sendable` + `NSLock` |
| 1.4 Мигрировать `DiagnosticsLogStoreDependency` | `DiagnosticsLogStoreDependency.swift` | Убрать 1 `@unchecked Sendable` |
| 1.5 Документировать инварианты оставшихся 4 `@unchecked Sendable` | `TransmissionTrustStore`, `TransmissionSessionDelegate`, `AppLogger`, `UserPreferencesRepository+Live` | Комментарии `// @unchecked Sendable safe because:` |
| 1.6 Поднять `SWIFT_STRICT_CONCURRENCY = complete` в Debug | `project.pbxproj` (Debug configs) | Компилятор найдёт скрытые data races |

> **Порядок важен:** 1.1 → 1.2–1.4 можно параллельно → 1.5 → 1.6. Не начинать 1.6 до завершения 1.2–1.5.

### Фаза 2: Декомпозиция монолитов (P1) — **3–5 дней**

| Задача | Файл | Стратегия |
|--------|------|-----------|
| 2.1 `TransmissionClient.swift` (834 строки) | Split на 4 файла: `TransmissionAuth`, `TransmissionRetryPolicy`, `TransmissionRPCResolver`, `TransmissionClient` (facade ~200 строк) | Extract protocol → extract classes → facade delegates |
| 2.2 `TorrentDetailFeature` (88 cases) | Split на sub-reducers: `TorrentFilesReducer`, `TorrentPeersReducer`, `TorrentTrackersReducer`, `TorrentStatsReducer` + родительский координирующий | TCA `Scope` + `forEach` по идентификаторам секций |
| 2.3 `TorrentListView.swift` (630 строк) | Вынести: `TorrentListToolbar`, `TorrentListEmptyState`, `TorrentListFilterBar` в отдельные файлы | View decomposition |
| 2.4 `TorrentListFeature+Reducer.swift` (575 строк) | Вынести: `TorrentListCommands`, `TorrentListFiltering` (уже частично), `TorrentListPolling` | Reducer composition |

> **Правило:** каждый извлечённый файл должен иметь свои тесты (`*Tests.swift`) и не превышать 300 строк.

### Фаза 3: Тестирование (P2) — **2–3 дня**

| Задача | Ожидаемый результат |
|--------|---------------------|
| 3.1 Восстановить UI-тесты: создать `RemissionUITests/` с минимум 3 сценариями | `AddServerFlow`, `AddTorrentFlow`, `TorrentActionsFlow` |
| 3.2 Добавить iOS тесты в CI | CI job `test-ios` на `macos-15` с `destination 'platform=iOS Simulator,name=iPhone 16e'` |
| 3.3 Мигрировать 25 XCTestCase файлов на `@Test` (по мере касания) | 0 файлов с `XCTestCase` в `RemissionTests/` |

### Фаза 4: Гигиена и документация (P3) — **1 день**

| Задача | Ожидаемый результат |
|--------|---------------------|
| 4.1 Унифицировать `Doc/` vs `docs/` (оставить `Doc/`, удалить `docs/`) | Одна папка документации |
| 4.2 Обновить `AGENTS.md` с новыми правилами (пороги, метрики) | Агенты не пропускают большие файлы |
| 4.3 Добавить `danger` / `swift-format` PR-комментарии | Автоматические напоминания в PR |

---

## 📏 Правила и ограничения (MUST для всех PR)

### 1. Лимит размера файла (Hard Gate в CI)

```yaml
# .github/workflows/ci.yml → добавить job:
metrics-check:
  runs-on: macos-15
  steps:
    - uses: actions/checkout@v4
    - name: Check file sizes
      run: |
        MAX_LINES=300
        VIOLATIONS=0
        for f in $(find Remission -name "*.swift" -not -path "*/Tests/*"); do
          lines=$(wc -l < "$f")
          if [ $lines -gt $MAX_LINES ]; then
            echo "❌ $f: $lines lines (max $MAX_LINES)"
            VIOLATIONS=1
          fi
        done
        exit $VIOLATIONS
```

| Тип файла | Hard limit | Soft limit (warning) |
|-----------|------------|----------------------|
| Swift source (app) | **300 строк** | 200 строк |
| Swift source (tests) | 400 строк | 300 строк |
| Reducer `enum Action` cases | **50** | 35 |
| Reducer `reduce(into:)` branches | **50** | 35 |
| View `body` complexity (nesting) | depth ≤ 6 | depth ≤ 4 |

> **Исключения:** генераторы кода, `Package.swift`, миграции — требуют `// swiftlint:disable file_length` с обоснованием в комментарии.

### 2. Правила организации модулей

| Правило | Описание |
|---------|----------|
| **Single Responsibility per File** | Один файл = одна ответственность (один редьюсер, один view, один клиент, один репозиторий) |
| **No God Reducers** | Если `enum Action` > 50 cases → обязательно split на sub-reducers через `Scope` |
| **Feature-First Structure** | Новая фича создаёт: `Features/Xyz/XyzFeature.swift` + `Views/Xyz/XyzView.swift` + `XyzFeatureTests.swift` |
| **Dependency Injection Only** | Никаких синглтонов / `shared` / `static let` в app-коде. Только через `@Dependency` |
| **Actor-First for Shared Mutable State** | Любое в памяти общее изменяемое состояние → `actor` (не `class + NSLock` + `@unchecked Sendable`) |

### 3. Конкурентность (Swift 6)

| Правило | Enforcement |
|---------|-------------|
| `SWIFT_STRICT_CONCURRENCY = complete` в Debug | CI падает на warnings |
| `@unchecked Sendable` только с комментарием инварианта | SwiftLint custom rule (см. ниже) |
| Никаких новых `NSLock` / `OSAllocatedUnfairLock` в app-коде | Code review + lint |
| Публичные типы должны быть `Sendable` по умолчанию | Code review |

### 4. SwiftLint кастомные правила (добавить в `.swiftlint.yml`)

```yaml
custom_rules:
  unchecked_sendable_documented:
    name: "Unchecked Sendable Must Be Documented"
    regex: '@unchecked Sendable'
    message: "Every @unchecked Sendable must have a preceding comment explaining the safety invariant (// @unchecked Sendable safe because: ...)"
    severity: error
    match_kinds:
      - keyword
    # Проверяем, что есть комментарий в 2 строки выше
    # Можно реализовать через regex с negative lookbehind или отдельный скрипт

  file_length_warning:
    name: "File Length Warning"
    regex: '^'
    included: ".*\\.swift$"
    excluded: ".*Tests/.*"
    severity: warning
    # Реализация через script в CI (см. metrics-check выше)
```

### 5. Pre-commit дополнения (в `Scripts/pre-commit`)

```bash
# Добавить после swiftlint:
echo -e "${BLUE}3️⃣  Checking file size limits...${NC}"
MAX_LINES=300
VIOLATIONS=0
for f in $(git diff --cached --name-only -- 'Remission/*.swift' 'Remission/**/*.swift' | grep -v Tests); do
  if [ -f "$f" ]; then
    lines=$(wc -l < "$f")
    if [ $lines -gt $MAX_LINES ]; then
      echo -e "${RED}   ❌ $f: $lines lines (max $MAX_LINES)${NC}"
      VIOLATIONS=1
    fi
  fi
done
if [ $VIOLATIONS -eq 1 ]; then
  echo -e "${YELLOW}   💡 Split large files before committing.${NC}"
  CHECKS_FAILED=1
fi
```

### 6. Code Review чек-лист (добавить в PR template)

```markdown
## Code Review Checklist

### Architecture
- [ ] Нет файлов > 300 строк (или есть обоснование в комментарии)
- [ ] Нет редьюсеров с > 50 actions
- [ ] Новые зависимости через `@Dependency` (не синглтоны)
- [ ] Общее изменяемое состояние → `actor`

### Concurrency
- [ ] Нет новых `@unchecked Sendable` без документации инварианта
- [ ] Нет новых `NSLock` / `OSAllocatedUnfairLock`
- [ ] `SWIFT_STRICT_CONCURRENCY = complete` проходит локально

### Tests
- [ ] Новые редьюсеры покрыты `TestStore` тестами
- [ ] Новые сетевые клиенты имеют `MockURLProtocol` фикстуры
- [ ] UI-критичные изменения имеют UI-тест (или issue заведен)

### Performance
- [ ] Нет `GeometryReader` / `ScrollViewReader` в горячих путях списков
- [ ] `List`/`ForEach` имеют стабильные `id`
- [ ] Тяжёлые вычисления вынесены из `body`
```

---

## 📊 Метрики для отслеживания (Dashboard)

| Метрика | Текущее | Target | Как измерять |
|---------|---------|--------|--------------|
| Max file lines (app) | 834 | ≤ 300 | `wc -l` в CI |
| Max reducer actions | 88 | ≤ 50 | grep `case ` в `*Feature*.swift` |
| `@unchecked Sendable` count | 10 | 0 (или все задокументированы) | grep в CI |
| `NSLock` count in app | 6 | 0 | grep в CI |
| UI test coverage | 0% | ≥ 3 critical flows | xcodebuild test |
| iOS tests in CI | ❌ | ✅ | CI job |
| XCTestCase legacy files | 25 | 0 | grep `XCTestCase` |

---

## 🔄 Процесс внедрения

1. **Неделя 1:** Принять правила, добавить CI job `metrics-check` (warning only)
2. **Неделя 2:** Перевести `metrics-check` на `error` (fail build)
3. **Неделя 3–4:** Фаза 1 (Concurrency) — параллельно с текущей работой
4. **Неделя 5–7:** Фаза 2 (Decomposition) — по одной задаче за PR
5. **Неделя 8:** Фаза 3 (Tests) + Фаза 4 (Hygiene)
6. **Постоянно:** Любой PR, нарушающий hard limits — **Request Changes** автоматически.

---

## 📝 Примеры правильного разделения (Templates)

### Пример: Split редьюсера (TCA)

```swift
// Родительский координирующий редьюсер (≤ 50 actions)
@Reducer
struct TorrentDetailFeature {
    @ObservableState
    struct State: Equatable {
        var files = TorrentFilesReducer.State()
        var peers = TorrentPeersReducer.State()
        var trackers = TorrentTrackersReducer.State()
        var stats = TorrentStatsReducer.State()
    }
    enum Action {
        case files(TorrentFilesReducer.Action)
        case peers(TorrentPeersReducer.Action)
        case trackers(TorrentTrackersReducer.Action)
        case stats(TorrentStatsReducer.Action)
        // координирующие actions ≤ 10
    }
    var body: some ReducerOf<Self> {
        Scope(state: \.files, action: \.files) { TorrentFilesReducer() }
        Scope(state: \.peers, action: \.peers) { TorrentPeersReducer() }
        Scope(state: \.trackers, action: \.trackers) { TorrentTrackersReducer() }
        Scope(state: \.stats, action: \.stats) { TorrentStatsReducer() }
        Reduce { state, action in
            // только координация
        }
    }
}
```

### Пример: Actor-based storage (замена UserDefaultsBox)

```swift
// Remission/Storage/ActorBasedStore.swift
actor UserDefaultsStore<Value: Codable & Sendable> {
    private let key: String
    private let defaults: UserDefaults
    private var cache: Value?
    
    init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }
    
    func load() -> Value? {
        if let cache { return cache }
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return nil
        }
        cache = value
        return value
    }
    
    func save(_ value: Value) throws {
        cache = value
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }
}
```

---

## ✅ Definition of Done для каждого этапа

| Фаза | DoD |
|------|-----|
| 0 | CI job `metrics-check` зелёный, `EngineeringAudit.md` актуален |
| 1 | 0 `@unchecked Sendable` без документации; `SWIFT_STRICT_CONCURRENCY = complete` в Debug проходит без warnings; 0 `NSLock` в app-коде |
| 2 | Все файлы ≤ 300 строк; все редьюсеры ≤ 50 actions; `TransmissionClient` split на 4 файла |
| 3 | `RemissionUITests/` с 3 сценариями; iOS тесты в CI зелёные; 0 `XCTestCase` в `RemissionTests/` |
| 4 | `docs/` удалена; `AGENTS.md` обновлён; PR template с чек-листом |

---

*Документ живой — обновляется по мере выполнения фаз. Все изменения правил требуют согласования в команде.*