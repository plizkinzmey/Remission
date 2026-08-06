# Pull Request Template

## Описание изменений
<!-- Кратко: что делает этот PR? Зачем нужен? -->

## Тип изменений
- [ ] Bug fix (исправление ошибки)
- [ ] New feature (новая функциональность)
- [ ] Refactor (рефакторинг без изменения поведения)
- [ ] Performance (оптимизация производительности)
- [ ] Tests (добавление/обновление тестов)
- [ ] Docs (документация)
- [ ] Chore (зависимости, конфиг, CI и т.д.)

## Связанные Issues
<!-- Fixes #123, Relates to #456 -->

---

## ✅ Code Review Checklist (Agent MUST verify)

### Architecture & Size Limits
- [ ] Нет файлов > 300 строк (app) / 400 строк (tests) — или есть `// swiftlint:disable file_length` с обоснованием
- [ ] Нет редьюсеров с > 50 `case` в `enum Action`
- [ ] Новые зависимости добавлены ТОЛЬКО через `@Dependency` (нет синглтонов / `shared`)
- [ ] Общее изменяемое состояние вынесено в `actor` (не `class + NSLock`)

### Concurrency (Swift 6)
- [ ] `SWIFT_STRICT_CONCURRENCY = complete` проходит локально в Debug (нет warnings)
- [ ] Все `@unchecked Sendable` имеют комментарий инварианта: `// @unchecked Sendable safe because: ...`
- [ ] Нет новых `NSLock` / `OSAllocatedUnfairLock` в app-коде
- [ ] Публичные типы — `Sendable` (struct / final class with lets / actor)

### Tests
- [ ] Новые редьюсеры покрыты `TestStore` тестами с `TestClock`
- [ ] Новые сетевые клиенты имеют `MockURLProtocol` фикстуры
- [ ] UI-критичные изменения имеют UI-тест в `RemissionUITests/` (или issue заведён)
- [ ] При касании XCTestCase-файлов — мигрированы на `@Test`

### Performance (SwiftUI)
- [ ] Нет `GeometryReader` / `ScrollViewReader` в горячих путях списков
- [ ] `List` / `ForEach` имеют стабильные `id`
- [ ] Тяжёлые вычисления вынесены из `body` (кэш / async)

### Code Quality
- [ ] `swift-format format --in-place` применён
- [ ] `swiftlint lint --fix` проходит без ошибок
- [ ] `Scripts/check-localizations.sh` проходит
- [ ] Нет `force unwrap` / `try!` в новом коде
- [ ] Нет закомментированного кода / `print` / `debugPrint` в production путях

---

## 🔧 Команды для локальной проверки (Agent MUST run)

```bash
# 1. Format
swift-format format --in-place --configuration .swift-format --recursive Remission RemissionTests RemissionUITests

# 2. Lint
swiftlint lint --fix

# 3. Localizations
Scripts/check-localizations.sh

# 4. File size check
MAX=300
for f in $(git diff --cached --name-only -- 'Remission/*.swift' 'Remission/**/*.swift' | grep -v Tests); do
  [ -f "$f" ] && [ $(wc -l < "$f") -gt $MAX ] && echo "❌ $f: $(wc -l < "$f") lines" && exit 1
done

# 5. Build + Test (macOS minimum)
xcodebuild test -scheme Remission -sdk macosx -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO

# 6. iOS tests (if available)
xcodebuild test -scheme Remission -destination 'platform=iOS Simulator,name=iPhone 16e' CODE_SIGNING_ALLOWED=NO
```

---

## 📸 Скриншоты / Видео (для UI изменений)
<!-- Обязательно для изменений Views -->

## 📝 Дополнительный контекст
<!-- Миграции, breaking changes, обновления зависимостей и т.д. -->

---

*By submitting this PR, I confirm I have run all checks above and the code complies with `Doc/RefactoringPlan.md` and `AGENTS.md` quality gates.*