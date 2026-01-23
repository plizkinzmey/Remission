# Remission TCA Feature Skill

## Description
Build or modify Remission feature modules using The Composable Architecture (TCA): create reducers/state/actions, wire SwiftUI views, handle navigation with @Presents, integrate dependencies, and add TestStore coverage. Use when adding new screens, changing feature flows, or refactoring feature logic in Remission.

## Workflow
1. Align with product scope and docs
   - Read `devdoc/PRD.md` if behavior changes; update it for functional changes.
   - Check `devdoc/plan.md` for architecture decisions and constraints.

2. Create or update the reducer
   - Place reducer in `Remission/Features/<FeatureName>/`.
   - Use `@ObservableState` with `State`, `Action`, and `Reducer`.
   - Use `@Presents` for alerts/sheets/navigation and `IdentifiedArrayOf` for collections.
   - Keep side effects in `.run { send in ... }` with dependencies.

3. Wire the SwiftUI view
   - Place views in `Remission/Views/<FeatureName>/`.
   - Keep business logic out of the view; bind to store state/actions only.
   - Use `NavigationStack` with state-driven routing.

4. Connect dependencies
   - Use dependency clients from `Remission/DependencyClients/`.
   - Add or update factories in `Remission/` (e.g., `ServerConnectionEnvironment.swift`).
   - Register in `Remission/AppDependencies.swift`.

5. Map RPC to domain models
   - Use `TransmissionDomainMapper` for RPC -> domain mapping.
   - Avoid manual `AnyCodable` parsing in features.

6. Add tests
   - Minimum two tests per reducer: happy path + error path.
   - Use Swift Testing + `TestStore` and override dependencies in `withDependencies`.

## Practical checklist
- Update `devdoc/PRD.md` for any functional change.
- Use `Localizable.xcstrings` for new strings.
- Keep UI responsive at 200+ torrents (lazy lists, minimal RPC fields).

## References / Cheatsheet

### Key paths
- PRD: `devdoc/PRD.md`
- Architecture plan: `devdoc/plan.md`
- Feature reducers: `Remission/Features/<FeatureName>/`
- Feature views: `Remission/Views/<FeatureName>/`
- Domain models: `Remission/Domain/`
- Dependency clients: `Remission/DependencyClients/`
- Live dependencies: `Remission/DependencyClientLive/`
- App wiring: `Remission/AppDependencies.swift`
- Environment factory: `Remission/ServerConnectionEnvironment.swift`

### TCA patterns
- State: `@ObservableState struct State: Equatable { ... }`
- Optional navigation/alerts: `@Presents var alert: AlertState<Action>?`
- Collections: `IdentifiedArrayOf<Model>`
- Effects: `.run { send in ... }`

### TestStore pattern (Swift Testing)
- Test file naming: `<FeatureName>FeatureTests.swift`
- Use `TestStore` with `withDependencies` overrides
- Verify state mutations in `await store.send(...) { ... }`
- Verify effects in `await store.receive(...) { ... }`
