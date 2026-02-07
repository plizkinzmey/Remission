#if DEBUG
    import Foundation

    #if canImport(ComposableArchitecture)
        import ComposableArchitecture

        /// Пример использования TransmissionClient в TCA reducer.
        /// Демонстрирует, как подключить клиент и использовать его в effects.
        ///
        /// **Использование в реальном reducer:**
        ///
        /// ```swift
        /// @Reducer
        /// struct TorrentListReducer {
        ///   @ObservableState
        ///   struct State {
        ///     var torrents: [Torrent] = []
        ///     var isLoading = false
        ///     var error: String? = nil
        ///   }
        ///
        ///   enum Action {
        ///     case loadTorrents
        ///     case torrentsLoaded([Torrent])
        ///     case loadingFailed(String)
        ///   }
        ///
        ///   @Dependency(\.transmissionClient) var client
        ///
        ///   var body: some ReducerOf<Self> {
        ///     Reduce { state, action in
        ///       switch action {
        ///       case .loadTorrents:
        ///         state.isLoading = true
        ///         return .run { send in
        ///           do {
        ///             let response = try await client.torrentGet(ids: nil, fields: ["id", "name", "percentDone"])
        ///             // Парсирование ответа...
        ///             await send(.torrentsLoaded(torrents))
        ///           } catch let error as APIError {
        ///             await send(.loadingFailed(error.localizedDescription))
        ///           }
        ///         }
        ///
        ///       case .torrentsLoaded(let torrents):
        ///         state.torrents = torrents
        ///         state.isLoading = false
        ///         return .none
        ///
        ///       case .loadingFailed(let message):
        ///         state.isLoading = false
        ///         state.error = message
        ///         return .none
        ///       }
        ///     }
        ///   }
        /// }
        /// ```
        ///
        /// **Использование в тестах:**
        ///
        /// ```swift
        /// @Test
        /// func testLoadTorrents() async {
        ///   let mockResponse = TransmissionResponse(result: "success", arguments: [...], tag: nil)
        ///   let mockClient = MockTransmissionClient(sessionGetResponse: mockResponse)
        ///
        ///   let store = TestStore(
        ///     initialState: TorrentListReducer.State(),
        ///     reducer: { TorrentListReducer() }
        ///   )
        ///   store.dependency(\.transmissionClient, mockClient)
        ///
        ///   await store.send(.loadTorrents)
        ///   await store.receive(.torrentsLoaded(...))
        /// }
        /// ```
        enum TransmissionClientUsageExample {
            // Этот enum служит только для документации примеров использования.
        }

    #endif
#endif
