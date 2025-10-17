# Transmission RPC Reference

## Quick Overview

**Transmission RPC** — это собственный JSON-based API для управления торрент-демоном. Используется в Remission для подключения, управления торрентами и получения информации о сессии.

⚠️ **Важно**: Transmission RPC использует **собственный формат** (NOT JSON-RPC 2.0). Основные отличия:
- Запрос: `method`, `arguments`, `tag` (не `jsonrpc`, `id`)
- Ответ: `result: "success"` или error string, `arguments`, `tag`

- **Минимальная версия Transmission**: 3.0
- **Рекомендуемая версия**: 4.0+
- **Протокол**: JSON поверх HTTP(S)
- **Аутентификация**: Basic Auth + Session ID (X-Transmission-Session-Id)
- **Default порт**: 9091 (один и тот же для HTTP и HTTPS)

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Remission iOS/macOS App               │
└──────────────────┬──────────────────────────────┘
                   │
                   │ TransmissionClient
                   │ (TransmissionClientProtocol)
                   │
                   ▼
        ┌──────────────────────┐
        │  Transmission RPC    │
        │  (HTTP JSON, NOT     │
        │   JSON-RPC 2.0)      │
        └──────────┬───────────┘
                   │
        ┌──────────▼───────────┐
        │ transmission-daemon  │
        │ (port 9091)          │
        │ (3.0+, 4.0+ rec.)    │
        └──────────┬───────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │  Torrent Session    │
         │  Peers, Torrents    │
         │  Stats, Files, etc  │
         └─────────────────────┘
```

## Core Methods for MVP

| Method | Purpose | Request Parameters | Response | Notes |
|--------|---------|-------------------|----------|-------|
| **session-get** | Get session info | — | session object | Called during handshake (HTTP 409) |
| **session-set** | Set session config | settings object | — | Configure limits, paths, etc. |
| **torrent-get** | List torrents | ids, fields | torrents array | Main list view data source |
| **torrent-add** | Add torrent | filename OR metainfo, download-dir | torrent object | Support .torrent and magnet |
| **torrent-start** | Start torrent | ids | — | Resume paused torrent |
| **torrent-stop** | Pause torrent | ids | — | Pause running torrent |
| **torrent-remove** | Remove torrent | ids, delete-local-data | — | Remove with optional data deletion |
| **torrent-verify** | Verify files | ids | — | Verify local files match metainfo |

## Authentication Flow (Critical!)

### Initial Handshake

```
1. Client sends ANY request to /transmission/rpc
2. Server responds with HTTP 409 Conflict
3. Response includes header: X-Transmission-Session-Id: <UUID>
4. Client caches this session ID locally
5. Client retries request with the session ID in header
```

### Request Headers

```http
POST /transmission/rpc HTTP/1.1
Host: transmission.example.com:9091
Authorization: Basic base64(username:password)
X-Transmission-Session-Id: aaaabbbbccccdddd1111222233334444
Content-Type: application/json
```

### Implementation in Swift

```swift
// 1. Handle 409 response and cache session ID
if response.statusCode == 409,
   let sessionId = response.headerFields?["X-Transmission-Session-Id"] {
    UserDefaults.standard.set(sessionId, forKey: "transmission_session_id")
}

// 2. Add session ID to subsequent requests
var request = URLRequest(url: url)
if let sessionId = UserDefaults.standard.string(forKey: "transmission_session_id") {
    request.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
}
```

## JSON-RPC 2.0 Structure

## JSON-RPC Structure

⚠️ **Transmission RPC format (NOT JSON-RPC 2.0)**:

### Request Format

```json
{
  "method": "torrent-get",
  "arguments": {
    "fields": ["id", "name", "status", "uploadRatio"],
    "ids": [1, 2, 3]
  },
  "tag": 1
}
```

Key points:
- `method`: string, required
- `arguments`: object, optional (key/value pairs specific to method)
- `tag`: number, optional (client-generated; server echoes it back in response)

### Successful Response

```json
{
  "result": "success",
  "arguments": {
    "torrents": [
      {
        "id": 1,
        "name": "Ubuntu 20.04",
        "status": 0,
        "uploadRatio": 1.5
      }
    ]
  },
  "tag": 1
}
```

Key points:
- `result`: string, required. Value is ALWAYS `"success"` on success
- `arguments`: object, optional. Contains method-specific response data
- `tag`: number, echoed from request

### Error Response

```json
{
  "result": "too many recent requests",
  "tag": 1
}
```

Key points:
- `result`: string, contains error message (not JSON-RPC error codes like -32602)
- On errors, `arguments` is typically empty or omitted
- Different Transmission versions may return different error strings

## Status Codes (for torrents)

```swift
enum TorrentStatus: Int {
  case stopped = 0        // Stopped
  case checkWait = 1      // Waiting to verify local files
  case check = 2          // Verifying local files
  case downloadWait = 3   // Waiting to download
  case download = 4       // Downloading
  case seedWait = 5       // Waiting to seed
  case seed = 6           // Seeding
  case isolated = 7       // Torrent can't find peers/seeds
}
```

## Error Handling

### HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| **409** | Session ID invalid or expired | Cache new X-Transmission-Session-Id from response header, retry |
| **401** | Authentication failed | Check credentials in Basic Auth header |
| **400** | Bad request | Check format of request JSON and arguments |
| **500** | Server error | Retry with exponential backoff |
| **503** | Service unavailable | Retry with exponential backoff |

### Transmission Error Messages (in response.result)

These are returned as string values in the `result` field, NOT numeric codes:

- `"success"` — Request succeeded
- `"too many recent requests"` — Rate limiting by Transmission
- Custom error strings — Vary by method and Transmission version

**Note**: Transmission does NOT use numeric error codes like JSON-RPC (-32602, etc.). Always parse the `result` string to determine success.

````

## Field References

### torrent-get: Common Fields

```
"id"                  - Torrent ID (number)
"name"                - Torrent name (string)
"status"              - Current status (number: 0-7)
"uploadRatio"         - Ratio uploaded/downloaded (float)
"rateDownload"        - Download speed (bytes/sec)
"rateUpload"          - Upload speed (bytes/sec)
"peersConnected"      - Connected peers (number)
"peersGettingFromUs"  - Peers downloading from us (number)
"peersSendingToUs"    - Peers uploading to us (number)
"percentDone"         - Progress 0.0-1.0 (float)
"eta"                 - Estimated seconds remaining (number)
"downloadDir"         - Download directory (string)
"totalSize"           - Total size in bytes (number)
"downloadedEver"      - Bytes downloaded (number)
"uploadedEver"        - Bytes uploaded (number)
"files"               - Array of file objects
"trackers"            - Array of tracker objects
```

### session-get: Common Fields

```
"alt-speed-enabled"        - Boolean, alt speed enabled
"alt-speed-down"           - Alt down limit (KB/s)
"alt-speed-up"             - Alt up limit (KB/s)
"blocklist-enabled"        - Boolean
"download-dir"             - Download directory path
"version"                  - Transmission version (string, e.g. "4.0.6")
"rpc-version"              - RPC API version (number)
"rpc-version-minimum"      - Min supported RPC version (number)
"speed-limit-down-enabled" - Boolean
"speed-limit-down"         - Down limit (KB/s)
"speed-limit-up-enabled"   - Boolean
"speed-limit-up"           - Up limit (KB/s)
```

## Edge Cases & Handling

### Case 1: Session ID Timeout

**Problem**: Server invalidates session ID after inactivity
**Solution**: Cache session ID but refresh on 409 response

```swift
if response.statusCode == 409 {
    // Refresh session ID
    if let newSessionId = response.headerFields?["X-Transmission-Session-Id"] {
        sessionStorage.update(newSessionId)
        retry(with: newSessionId)
    }
}
```

### Case 2: No Free Space

**Problem**: torrent-add returns error code 3
**Solution**: Display user message, offer alternatives

```swift
if error.code == 3 {
    showAlert("Недостаточно места", 
              "Проверьте свободное место на диске")
}
```

### Case 3: Version Mismatch

**Problem**: New API method not available in user's Transmission version
**Solution**: Check version via session-get, adapt requests

```swift
if session.rpcVersion < 16 {
    // Old method: use "torrent-get" with different fields
    useOldTorrentGetMethod()
} else {
    // New method available
    useNewTorrentGetMethod()
}
```

### Case 4: Network Timeout

**Problem**: Request takes > 30 seconds
**Solution**: Implement timeout + exponential backoff

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30.0
config.timeoutIntervalForResource = 60.0

// Exponential backoff: 1s, 2s, 4s, 8s (max 16s)
let delay = min(pow(2.0, Double(attempt)), 16.0)
try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
```

### Case 5: Large Torrent Lists (200+)

**Problem**: Downloading 200+ torrent metadata is slow
**Solution**: Use field filtering and pagination

```swift
// Only request needed fields (not "files", "trackers")
let fields = ["id", "name", "status", "uploadRatio", "percentDone"]

// Implement pagination (if supported)
// OR use caching with selective updates
```

## Version Compatibility

### Transmission 3.0 (Minimum)

```
✅ Supported methods: session-get, torrent-get, torrent-add, torrent-start, etc.
✅ Basic Auth: Supported
✅ Session ID: Supported (HTTP 409 handshake)
✅ JSON-RPC 2.0: Supported
```

### Transmission 4.0 (Recommended)

```
✅ All 3.0 methods
✅ Better error handling
✅ New fields in responses (e.g., bandwidthPriority, trackerStats)
✅ Improved performance
⚠️ Breaking changes: None from 3.0 → 4.0 for basic operations
```

### Version Check in Code

```swift
@Dependency(\.transmissionClient) var client

// Check version on first connection
let session = try await client.session()
guard session.rpcVersion >= 14 else {
    throw TransmissionError.versionTooOld(session.version)
}
```

## Security Considerations

### ✅ DO

- ✅ Use HTTPS when possible
- ✅ Store credentials in Keychain only
- ✅ Validate SSL certificates
- ✅ Cache session ID securely
- ✅ Never log credentials or sensitive data
- ✅ Use timeout for all requests

### ❌ DON'T

- ❌ Store passwords in UserDefaults
- ❌ Log full request/response bodies
- ❌ Disable SSL verification ("insecure")
- ❌ Retry infinitely without backoff
- ❌ Share session ID between app instances

## Common RPC Sequences

### Sequence 1: Connect & Get Status

```swift
// 1. Get session (triggers 409 if first connection)
let session = try await client.session()

// 2. Get list of torrents
let torrents = try await client.torrentGet(
    fields: ["id", "name", "status", "percentDone"],
    ids: .all
)

// 3. Display to user
showTorrentList(torrents)
```

### Sequence 2: Add & Start Torrent

```swift
// 1. Add torrent from file/magnet
let torrent = try await client.torrentAdd(
    filename: "magnet:?xt=urn:btih:...",
    downloadDir: "/Downloads"
)

// 2. Start immediately
try await client.torrentStart(ids: [torrent.id])

// 3. Show confirmation
showAlert("Торрент добавлен и запущен")
```

### Sequence 3: Monitor Progress

```swift
// Poll every 2 seconds
while isMonitoring {
    let torrents = try await client.torrentGet(
        fields: ["id", "percentDone", "rateDownload"],
        ids: [monitoredId]
    )
    
    if let torrent = torrents.first {
        updateProgressBar(torrent.percentDone)
        updateSpeed(torrent.rateDownload)
    }
    
    try await Task.sleep(nanoseconds: 2_000_000_000)
}
```

## Testing with Docker Compose

### Local Transmission Daemon

```yaml
# docker-compose.yml
version: '3'
services:
  transmission:
    image: linuxserver/transmission:latest
    ports:
      - "9091:9091"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - TRANSMISSION_WEB_HOME=/transmission-web-home/
    volumes:
      - ./data:/data
      - ./downloads:/downloads
```

### Start for Testing

```bash
docker-compose up -d
# Test endpoint: http://localhost:9091/transmission/rpc
# Default auth: admin / password
```

## Official Resources

- **GitHub**: https://github.com/transmission/transmission/wiki
- **RPC Spec**: https://github.com/transmission/transmission/wiki/RPC-protocol-specification
- **Python Client**: https://transmission-rpc.readthedocs.io (Good reference for field names)
- **API Changes**: Check GitHub releases for breaking changes

## Integration Points in Remission

### TCA Dependency

```swift
// Environment
@Dependency(\.transmissionClient) var client

// In Reducer
case .loadTorrents:
    return .run { send in
        let torrents = try await client.torrentGet(...)
        await send(.torrentsLoaded(torrents))
    }
```

### Service Layer

```swift
// TransmissionClientProtocol implementation
protocol TransmissionClientProtocol {
    func session() async throws -> Session
    func torrentGet(fields: [String], ids: TorrentIds) async throws -> [Torrent]
    func torrentAdd(...) async throws -> Torrent
    // ... other methods
}
```

### Error Handling

```swift
enum TransmissionError: LocalizedError {
    case networkError(URLError)
    case invalidResponse
    case versionTooOld(String)
    case noFreeSpace
    case authenticationFailed
    
    var errorDescription: String? {
        // User-friendly error messages
    }
}
```

---

**Last Updated**: October 17, 2025  
**Based on**: Context7 research, Transmission 4.0+ official documentation  
**Used in**: RTC-16 (Research), RTC-17+ (Implementation)

**See also**:
- `devdoc/plan.md` - Main architecture and roadmap
- `devdoc/CONTEXT7_GUIDE.md` - How to research documentation
- `.github/copilot-instructions.md` - Swift/TCA patterns
- `AGENTS.md` - Full development handbook
