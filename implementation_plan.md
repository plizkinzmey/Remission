# План внедрения Code Review, ретроспективы и рефлексии

## Цель

Довести агентский workflow Remission до состояния, где после реализации и перед коммитом обязательно выполняется отдельный post-implementation review: поиск дублей, мертвого кода, нарушения Swift 6/TCA, избыточности, проверка актуальности API и фиксация ретроспективы.

## Изменения

- Создать `.agents/skills/code-review-reflection/SKILL.md` с триггером, чеклистом ревью, правилами Context7/актуальности API, Periphery и форматом ретроспектив.
- Добавить постоянное хранилище ретроспектив в `.agents/retrospectives/`.
- Обновить `AGENTS.md`: добавить правило 6 в critical block и описать post-implementation review как обязательный gate.
- Исправить структуру `.agents/skills/swift-6-xcode-native/SKILL.md` и добавить секцию F после SwiftUI Previews.
- Создать `Scripts/validate-dead-code.sh` в строгом режиме: Periphery, TODO/FIXME и реальные tool warnings видны в выводе и блокируют коммит до исправления; локальные эвристики остаются видимыми как review notes.
- Подключить `validate-dead-code.sh` в `Scripts/pre-commit` и `Scripts/prepare-hooks.sh`.

## Риски

- Periphery может давать ложные срабатывания, но их нельзя скрывать. Нужно либо исправить код, либо явно настроить исключение/retain-правило, чтобы warning исчез из будущих проверок.
- `.agents` и `Scripts` не входят в Xcode project navigator, поэтому для них используется filesystem workflow.
- В репозитории уже есть незакоммиченные изменения; правки должны быть локализованы только к агентским правилам и hook scripts.

## Верификация

- Проверить наличие всех новых файлов.
- Проверить, что `periphery version` доступен.
- Выполнить `bash -n` для измененных shell-скриптов.
- Запустить `Scripts/validate-dead-code.sh`.
- Проверить Xcode Issue Navigator на ошибки, если Xcode workspace доступен.
