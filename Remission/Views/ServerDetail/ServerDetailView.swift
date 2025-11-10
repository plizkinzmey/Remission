import ComposableArchitecture
import SwiftUI

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>

    var body: some View {
        List {
            connectionSection
            serverSection
            securitySection
            trustSection
            actionsSection
        }
        .navigationTitle(store.server.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(
            store: store.scope(state: \.$editor, action: \.editor)
        ) { editorStore in
            ServerEditorView(store: editorStore)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Изменить") {
                    store.send(.editButtonTapped)
                }
            }
        }
    }

    private var serverSection: some View {
        Section("Сервер") {
            LabeledContent("Название", value: store.server.name)
            LabeledContent("Адрес", value: store.server.displayAddress)
            LabeledContent("Протокол") {
                securityBadge
            }
        }
    }

    private var connectionSection: some View {
        Section("Подключение") {
            switch store.connectionState.phase {
            case .idle:
                Text("Ожидаем начало подключения.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .connecting:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Подключаемся к серверу…")
                }

            case .ready(let ready):
                Label("Подключено", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let description = ready.handshake.serverVersionDescription,
                    description.isEmpty == false
                {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("RPC v\(ready.handshake.rpcVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .failed(let failure):
                Label("Ошибка подключения", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(failure.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Повторить подключение") {
                    store.send(.retryConnectionButtonTapped)
                }
                .buttonStyle(.borderedProminent)
            }
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

    private var securityBadge: some View {
        Group {
            if store.server.isSecure {
                Label("HTTPS", systemImage: "lock.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                    .foregroundStyle(.green)
            } else {
                Label("HTTP", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityLabel(
            store.server.isSecure
                ? "Безопасное подключение"
                : "Небезопасное подключение"
        )
    }

    private var trustSection: some View {
        Section("Доверие") {
            Button(role: .destructive) {
                store.send(.resetTrustButtonTapped)
            } label: {
                Label("Сбросить доверие", systemImage: "arrow.counterclockwise")
            }
            Button {
                store.send(.httpWarningResetButtonTapped)
            } label: {
                Label("Сбросить предупреждения HTTP", systemImage: "exclamationmark.shield")
            }
        }
    }

    private var actionsSection: some View {
        Section("Действия") {
            Button(role: .destructive) {
                store.send(.deleteButtonTapped)
            } label: {
                Label("Удалить сервер", systemImage: "trash")
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
