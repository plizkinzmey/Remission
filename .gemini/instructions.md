# Remission Agent Instructions

You are an expert software engineer working on the **Remission** project. Remission is a cross-platform (iOS + macOS) client for remote management of Transmission via RPC, focused on speed and monitoring.

## Core Mandates & Architecture

- **Architecture:** The project strictly follows **The Composable Architecture (TCA)**.
  - State: `@ObservableState struct State`
  - Action: `enum Action`
  - Reducer: `Reducer` with `var body`
  - Store: `Store(initialState:, reducer:)`
  - Side Effects: `.run { send in ... }`
  - Navigation: `@Presents` for optional state (sheets, alerts), `IdentifiedArrayOf` for collections.
- **Language:** Swift 6.0+. Use `async/await`, `Task`, actors.
- **Testing:** Use **Swift Testing** framework (`@Test`).
  - TCA Tests: Use `TestStore` for exhaustive testing of reducers and effects.
  - Coverage: Aim for >=60% on key components.
- **Networking:** `TransmissionClientProtocol` implements Transmission RPC.
  - **Reference:** Check `devdoc/TRANSMISSION_RPC_REFERENCE.md`.
  - **Mapping:** Always use `TransmissionDomainMapper` to convert RPC responses to domain models.
- **Security:**
  - Credentials must strictly be stored in **Keychain**.
  - No secrets in logs.
- **Documentation:**
  - **Context7:** Before research, read `devdoc/CONTEXT7_GUIDE.md`.
  - **PRD:** Check `devdoc/PRD.md` for requirements.
  - **Plan:** Check `devdoc/plan.md` for architectural decisions.

## Project Structure

- `Remission/` - Main source code.
  - `Features/` - TCA Reducers.
  - `Views/` - SwiftUI Views.
  - `Domain/` - Models and Mappers.
  - `DependencyClients/` - Dependency definitions.
  - `DependencyClientLive/` - Live implementations.
- `RemissionTests/` - Unit tests (Swift Testing).
- `RemissionUITests/` - UI tests.
- `.codex/` & `.gemini/` - Agent skills and instructions.

## Workflow

1. **Understand:** Read `devdoc/PRD.md` and related code.
2. **Plan:** Propose a plan adhering to TCA and project patterns.
3. **Implement:** Write code, following SwiftLint and formatting rules.
4. **Verify:**
   - Run linter: `swiftlint lint`
   - Run formatter: `swift-format lint ...`
   - Run tests: `xcodebuild test ...`
5. **Commit:** Use concise Russian commit messages.

## Available Skills

You have access to specialized skills in `.gemini/skills/`. Use them for specific tasks:

- **Branching:** `.gemini/skills/branching.md` - For creating/managing branches.
- **TCA Feature:** `.gemini/skills/tca-feature.md` - For building/modifying features.
- **Localization:** `.gemini/skills/localization-assets.md` - For managing strings/assets.
- **Release:** `.gemini/skills/release.md` - For cutting releases.
- **Transmission RPC:** `.gemini/skills/transmission-rpc.md` - For RPC integration.

## Common Pitfalls

- **Do not** mix TCA and `@StateObject`/`@State` unnecessarily.
- **Do not** make network calls directly in Views.
- **Do not** forget to add tests for new Reducers.
- **Do not** use `master`/`main` for development; always branch from `develop`.

For detailed guidelines, refer to `AGENTS.md` in the project root.
