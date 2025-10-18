import Foundation

// Проверяем наличие The Composable Architecture
#if canImport(ComposableArchitecture)
    import ComposableArchitecture

    /// DependencyKey для внедрения TransmissionClient в TCA reducers.
    /// Позволяет легко мокировать клиент в тестах и переопределять реализацию.
    ///
    /// Использование в reducer:
    /// ```swift
    /// @Dependency(\.transmissionClient) var client
    /// ```
    ///
    /// Переопределение в тестах:
    /// ```swift
    /// .dependency(\.transmissionClient, MockTransmissionClient())
    /// ```
    extension DependencyValues {
        /// TransmissionClient для текущего reducer.
        public var transmissionClient: TransmissionClientProtocol {
            get { self[TransmissionClientKey.self] }
            set { self[TransmissionClientKey.self] = newValue }
        }
    }

    private struct TransmissionClientKey: DependencyKey {
        static var liveValue: TransmissionClientProtocol = {
            // Дефолтная реализация — заглушка, требует явной конфигурации перед использованием.
            // В реальном приложении подменяется на конкретную реализацию TransmissionClient.
            struct UnimplementedClient: TransmissionClientProtocol {
                func sessionGet() async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func sessionStats() async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentGet(
                    ids: [Int]?,
                    fields: [String]?
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentAdd(
                    filename: String,
                    downloadDir: String?,
                    paused: Bool?,
                    labels: [String]?
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentRemove(
                    ids: [Int],
                    deleteLocalData: Bool?
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentSet(
                    ids: [Int],
                    arguments: AnyCodable
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }

                func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "TransmissionClient not configured")
                }
            }

            return UnimplementedClient()
        }()

        static var testValue: TransmissionClientProtocol = {
            // Тестовая реализация — заглушка для тестов.
            struct TestClient: TransmissionClientProtocol {
                func sessionGet() async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func sessionStats() async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentGet(
                    ids: [Int]?,
                    fields: [String]?
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentAdd(
                    filename: String,
                    downloadDir: String?,
                    paused: Bool?,
                    labels: [String]?
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentRemove(
                    ids: [Int],
                    deleteLocalData: Bool?
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentSet(
                    ids: [Int],
                    arguments: AnyCodable
                ) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }

                func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
                    throw APIError.unknown(details: "Test client not configured")
                }
            }

            return TestClient()
        }()
    }

#endif
