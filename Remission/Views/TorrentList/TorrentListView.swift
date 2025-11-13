import ComposableArchitecture
import Foundation
import SwiftUI

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        Section("Торренты") {
            if store.connectionEnvironment == nil {
                disconnectedView
            } else if store.isLoading && store.torrents.isEmpty {
                loadingView
            } else if let message = store.errorMessage {
                errorView(message: message)
            } else if store.torrents.isEmpty {
                emptyStateView
            } else {
                torrentRows
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Загружаем торренты…")
        }
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Нет подключения")
                .font(.subheadline)
                .bold()
            Text("Установите соединение с сервером, чтобы увидеть список торрентов.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Торренты отсутствуют")
                .font(.subheadline)
                .bold()
            Text("Добавьте .torrent или magnet, чтобы начать загрузку.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Обновить") {
                store.send(.refreshButtonTapped)
            }
            .buttonStyle(.bordered)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Не удалось получить список торрентов", systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Повторить") {
                store.send(.refreshButtonTapped)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var torrentRows: some View {
        ForEach(store.torrents) { torrent in
            Button {
                store.send(.torrentTapped(torrent.id))
            } label: {
                TorrentRowView(torrent: torrent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TorrentRowView: View {
    var torrent: Torrent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(torrent.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                statusBadge
            }

            ProgressView(value: progressValue)
                .tint(progressColor)

            HStack {
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(speedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var progressValue: Double {
        min(max(torrent.summary.progress.percentDone, 0), 1)
    }

    private var progressText: String {
        let percent = progressValue * 100
        return String(format: "%.1f%%", percent)
    }

    private var speedText: String {
        let download = ByteCountFormatter.string(
            fromByteCount: Int64(torrent.summary.transfer.downloadRate),
            countStyle: .binary
        )
        let upload = ByteCountFormatter.string(
            fromByteCount: Int64(torrent.summary.transfer.uploadRate),
            countStyle: .binary
        )
        return "↓ \(download)/с · ↑ \(upload)/с"
    }

    private var statusBadge: some View {
        Text(statusTitle)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
            )
            .foregroundStyle(statusColor)
    }

    private var statusTitle: String {
        switch torrent.status {
        case .stopped: return "Остановлен"
        case .checkWaiting: return "Ожидает проверку"
        case .checking: return "Проверка"
        case .downloadWaiting: return "В очереди"
        case .downloading: return "Скачивание"
        case .seedWaiting: return "Ожидает раздачу"
        case .seeding: return "Раздача"
        case .isolated: return "Изолирован"
        }
    }

    private var statusColor: Color {
        switch torrent.status {
        case .downloading: return .blue
        case .seeding: return .green
        case .stopped: return .gray
        case .checking, .checkWaiting: return .orange
        case .downloadWaiting, .seedWaiting: return .purple
        case .isolated: return .red
        }
    }

    private var progressColor: Color {
        switch torrent.status {
        case .downloading: return .blue
        case .seeding: return .green
        case .stopped: return .gray
        case .checking, .checkWaiting: return .orange
        case .downloadWaiting, .seedWaiting: return .purple
        case .isolated: return .red
        }
    }
}
