# Remission Transmission RPC Skill

## Description
Implement or modify Transmission RPC integration in Remission: add RPC methods, handle session-id handshakes, map responses with TransmissionDomainMapper, and update repositories and tests. Use when touching TransmissionClient, RPC requests/responses, or domain mapping.

## Workflow
1. Confirm RPC contract
   - Consult `devdoc/TRANSMISSION_RPC_REFERENCE.md` for method details and edge cases.

2. Update client protocol and implementation
   - Extend `TransmissionClientProtocol` and `TransmissionClient`.
   - Ensure 409 handshake/session-id logic remains intact.

3. Map RPC to domain models
   - Implement mapping in `TransmissionDomainMapper` files.
   - Do not parse `AnyCodable` in features; keep mapping centralized.

4. Update repositories/services
   - Wire new client calls through repositories (e.g., `TorrentRepository.swift`).

5. Add fixtures and tests
   - Add JSON fixtures under `RemissionTests/Fixtures/Transmission/`.
   - Update mapper/client tests to cover happy + error cases.

## References

### Core references
- RPC reference: `devdoc/TRANSMISSION_RPC_REFERENCE.md`
- Domain mapper: `Remission/Domain/TransmissionDomainMapper*.swift`

### Client & protocol
- `Remission/TransmissionClientProtocol.swift`
- `Remission/TransmissionClient.swift`
- `Remission/TransmissionClientConfig.swift`

### Repositories
- `Remission/TorrentRepository.swift`
- `Remission/SessionRepository.swift`

### Tests
- Mapper tests: `RemissionTests/TransmissionDomainMapperTests.swift`
- Client tests: `RemissionTests/TransmissionClient*Tests.swift`
- Fixtures: `RemissionTests/Fixtures/Transmission/`
