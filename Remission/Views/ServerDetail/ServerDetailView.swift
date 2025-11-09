import ComposableArchitecture
import SwiftUI

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>

    var body: some View {
        List {
            serverSection
            securitySection
            trustSection
        }
        .navigationTitle(store.server.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var serverSection: some View {
        Section("Сервер") {
            LabeledContent("Название", value: store.server.name)
            LabeledContent("Адрес", value: store.server.displayAddress)
        }
    }

    private var securitySection: some View {
        Section("Безопасность") {
            if store.server.isSecure {
                Label("HTTPS соединение", systemImage: "lock.fill")
                    .foregroundStyle(.green)
                if case .https(let allowUntrusted) = store.server.security, allowUntrusted {
                    Text("Разрешены недоверенные сертификаты.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("HTTP (небезопасно)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Данные передаются без шифрования. Рекомендуем включить HTTPS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trustSection: some View {
        Section("Доверие") {
            Button(role: .destructive) {
                store.send(.resetTrustButtonTapped)
            } label: {
                Label("Сбросить доверие", systemImage: "arrow.counterclockwise")
            }
        }
    }
}

#Preview {
    ServerDetailView(
        store: Store(
            initialState: ServerDetailReducer.State(
                server: ServerConfig.previewLocalHTTP
            )
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    )
}
