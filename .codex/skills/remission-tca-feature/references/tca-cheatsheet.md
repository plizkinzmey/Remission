# Remission TCA Cheatsheet

## Key paths
- PRD: `devdoc/PRD.md`
- Architecture plan: `devdoc/plan.md`
- Feature reducers: `Remission/Features/<FeatureName>/`
- Feature views: `Remission/Views/<FeatureName>/`
- Domain models: `Remission/Domain/`
- Dependency clients: `Remission/DependencyClients/`
- Live dependencies: `Remission/DependencyClientLive/`
- App wiring: `Remission/AppDependencies.swift`
- Environment factory: `Remission/ServerConnectionEnvironment.swift`

## TCA patterns
- State: `@ObservableState struct State: Equatable { ... }`
- Optional navigation/alerts: `@Presents var alert: AlertState<Action>?`
- Collections: `IdentifiedArrayOf<Model>`
- Effects: `.run { send in ... }`

## TestStore pattern (Swift Testing)
- Test file naming: `<FeatureName>FeatureTests.swift`
- Use `TestStore` with `withDependencies` overrides
- Verify state mutations in `await store.send(...) { ... }`
- Verify effects in `await store.receive(...) { ... }`

## Example search helpers
- Find reducers: `rg --files -g '*Reducer.swift' Remission/Features`
- Find views: `rg --files -g '*.swift' Remission/Views`
- Find dependency clients: `rg --files -g '*Dependency*.swift' Remission/DependencyClients`
