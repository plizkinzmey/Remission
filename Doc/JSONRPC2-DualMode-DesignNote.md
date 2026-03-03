# JSON-RPC 2.0 Dual-Mode Design Note

## Scope
- Introduce dual-mode Transmission RPC transport (`auto`, `legacy`, `jsonRpc2`).
- Keep reducers and feature APIs unchanged.
- Add fallback from JSON-RPC 2.0 to legacy when server/protocol mismatch is detected.

## Context7 Verification Summary
- `swift-composable-architecture`: transport/network concerns should stay in dependencies/client layer, not in reducers.
- `swift-dependencies`: runtime behavior can be encapsulated in dependency clients and verified via dependency overrides in tests.
- `swiftlang/swift`: use `Codable` DTOs and explicit typed error modeling for robust protocol parsing.

These align with the chosen implementation:
- protocol selection/fallback is inside `TransmissionClient`;
- feature layer keeps using existing `TransmissionClientDependency`;
- tests assert behavior through mocked HTTP traffic.

## Key Decisions
- `TransmissionClientConfig.rpcMode` defaults to `.auto`.
- In `.auto`, client tries JSON-RPC 2.0 first and falls back to legacy on incompatible protocol/method signals.
- Resolved mode is cached in-memory per client session to avoid repeated probing.
- Request keys are converted to snake_case in JSON-RPC mode.
- Mapper tolerates both snake_case and legacy keys for critical session/stat fields.

## Non-Goals (Phase 1)
- No UI changes for new Transmission 4.x fields/features.
- No migration of feature-layer interfaces.
