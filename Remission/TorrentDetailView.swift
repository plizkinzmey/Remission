import ComposableArchitecture
import SwiftUI

/// SwiftUI представление деталей торрента
/// Отображает все поля торрента и предоставляет кнопки управления
struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    @State private var showingDeleteConfirmation: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mainInfoSection
                statisticsSection
                actionsSection

                if !store.files.isEmpty {
                    filesSection
                }

                if !store.trackers.isEmpty {
                    trackersSection
                }

                if !store.peersFrom.isEmpty {
                    peersSection
                }

                if let errorMessage = store.errorMessage {
                    errorSection(errorMessage)
                }
            }
            .padding()
        }
        .navigationTitle(store.name.isEmpty ? "Торрент" : store.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            store.send(.loadTorrentDetails)
        }
        .refreshable {
            store.send(.loadTorrentDetails)
        }
        .overlay {
            if store.isLoading {
                ProgressView("Загрузка...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .confirmationDialog(
            "Удаление торрента",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить только торрент", role: .destructive) {
                store.send(.removeTorrent(deleteData: false))
            }
            Button("Удалить с данными", role: .destructive) {
                store.send(.removeTorrent(deleteData: true))
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выберите способ удаления торрента «\(store.name)»")
        }
    }
}

extension TorrentDetailView {
    // MARK: - Sections

    fileprivate var mainInfoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                labelValueRow("Имя:", store.name)
                labelValueRow("Статус:", statusText)
                labelValueRow("Прогресс:", progressText)
                labelValueRow("Размер:", formatBytes(store.totalSize))
                labelValueRow("Загружено:", formatBytes(store.downloadedEver))
                labelValueRow("Отдано:", formatBytes(store.uploadedEver))
                labelValueRow("Путь:", store.downloadDir)
                labelValueRow("Дата добавления:", formatDate(store.dateAdded))
                if store.eta > 0 {
                    labelValueRow("Осталось:", formatETA(store.eta))
                }
            }
        } label: {
            Text("Основная информация")
                .font(.headline)
        }
    }

    fileprivate var statisticsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                labelValueRow("Скорость загрузки:", formatSpeed(store.rateDownload))
                labelValueRow("Скорость отдачи:", formatSpeed(store.rateUpload))
                labelValueRow("Коэффициент:", String(format: "%.2f", store.uploadRatio))
                labelValueRow("Пиров подключено:", "\(store.peersConnected)")

                Divider().padding(.vertical, 4)

                downloadLimitControls
                uploadLimitControls
            }
        } label: {
            Text("Статистика")
                .font(.headline)
        }
    }

    fileprivate var downloadLimitControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Лимит загрузки:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.downloadLimited },
                        set: { store.send(.toggleDownloadLimit($0)) }
                    )
                )
                .labelsHidden()
            }

            if store.downloadLimited {
                HStack {
                    Text("Значение (КБ/с):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField(
                        "КБ/с",
                        value: Binding(
                            get: { store.downloadLimit },
                            set: { store.send(.updateDownloadLimit($0)) }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    #if os(macOS)
                        .controlSize(.small)
                    #endif
                }
            }
        }
    }

    fileprivate var uploadLimitControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Лимит отдачи:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.uploadLimited },
                        set: { store.send(.toggleUploadLimit($0)) }
                    )
                )
                .labelsHidden()
            }

            if store.uploadLimited {
                HStack {
                    Text("Значение (КБ/с):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField(
                        "КБ/с",
                        value: Binding(
                            get: { store.uploadLimit },
                            set: { store.send(.updateUploadLimit($0)) }
                        ),
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    #if os(macOS)
                        .controlSize(.small)
                    #endif
                }
            }
        }
    }

    fileprivate var actionsSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton(
                        title: isActive ? "Пауза" : "Старт",
                        systemImage: isActive ? "pause.fill" : "play.fill",
                        color: isActive ? .orange : .green
                    ) {
                        if isActive {
                            store.send(.stopTorrent)
                        } else {
                            store.send(.startTorrent)
                        }
                    }

                    actionButton(
                        title: "Проверить",
                        systemImage: "checkmark.shield.fill",
                        color: .blue
                    ) {
                        store.send(.verifyTorrent)
                    }
                }

                actionButton(
                    title: "Удалить торрент",
                    systemImage: "trash.fill",
                    color: .red,
                    fullWidth: true
                ) {
                    showingDeleteConfirmation = true
                }
            }
        } label: {
            Text("Действия")
                .font(.headline)
        }
    }

    fileprivate var filesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.files) { file in
                    fileRow(file)
                }
            }
        } label: {
            Text("Файлы (\(store.files.count))")
                .font(.headline)
        }
    }

    fileprivate var trackersSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.trackers) { tracker in
                    trackerRow(tracker)
                }
            }
        } label: {
            Text("Трекеры (\(store.trackers.count))")
                .font(.headline)
        }
    }

    fileprivate var peersSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.peersFrom) { peerSource in
                    HStack {
                        Text(peerSource.name)
                            .font(.caption)
                        Spacer()
                        Text("\(peerSource.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Text("Источники пиров")
                .font(.headline)
        }
    }

    fileprivate func errorSection(_ message: String) -> some View {
        GroupBox {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                Spacer()
                Button("Закрыть") {
                    store.send(.clearError)
                }
                .buttonStyle(.bordered)
            }
        } label: {
            Text("Ошибка")
                .font(.headline)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helper Views

    fileprivate func labelValueRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    fileprivate func actionButton(
        title: String,
        systemImage: String,
        color: Color,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    fileprivate func fileRow(_ file: TorrentFile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text(formatBytes(file.length))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                ProgressView(value: file.progress)
                    .progressViewStyle(.linear)
                Text("\(Int(file.progress * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                Menu {
                    Button("Низкий") {
                        store.send(.setPriority(fileIndices: [file.index], priority: 0))
                    }
                    Button("Нормальный") {
                        store.send(.setPriority(fileIndices: [file.index], priority: 1))
                    }
                    Button("Высокий") {
                        store.send(.setPriority(fileIndices: [file.index], priority: 2))
                    }
                } label: {
                    Text(priorityText(file.priority))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor(file.priority).opacity(0.2))
                        .foregroundStyle(priorityColor(file.priority))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    fileprivate func trackerRow(_ tracker: TorrentTracker) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tracker.displayName)
                .font(.caption.weight(.medium))

            Text(tracker.announce)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let stats = store.trackerStats.first(where: { $0.trackerId == tracker.index }) {
                HStack(spacing: 12) {
                    Label("\(stats.seederCount)", systemImage: "arrow.up.circle.fill")
                    Label("\(stats.leecherCount)", systemImage: "arrow.down.circle.fill")
                    if !stats.lastAnnounceResult.isEmpty && stats.lastAnnounceResult != "Success" {
                        Text(stats.lastAnnounceResult)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    fileprivate var statusText: String {
        switch store.status {
        case 0: return "Остановлен"
        case 1: return "Проверка очереди"
        case 2: return "Проверка"
        case 3: return "Очередь загрузки"
        case 4: return "Загрузка"
        case 5: return "Очередь раздачи"
        case 6: return "Раздача"
        default: return "Неизвестно"
        }
    }

    fileprivate var progressText: String {
        String(format: "%.1f%%", store.percentDone * 100)
    }

    fileprivate var isActive: Bool {
        store.status == 4 || store.status == 6
    }

    // MARK: - Formatters

    fileprivate func formatBytes(_ bytes: Int) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    fileprivate func formatSpeed(_ bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else { return "0 КБ/с" }
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/с"
    }

    fileprivate func formatDate(_ timestamp: Int) -> String {
        let date: Date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    fileprivate func formatETA(_ seconds: Int) -> String {
        if seconds < 0 { return "—" }
        let hours: Int = seconds / 3600
        let minutes: Int = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }

    fileprivate func priorityText(_ priority: Int) -> String {
        switch priority {
        case 0: return "Низкий"
        case 2: return "Высокий"
        default: return "Нормальный"
        }
    }

    fileprivate func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 0: return .gray
        case 2: return .red
        default: return .blue
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        NavigationStack {
            TorrentDetailView(
                store: Store(
                    initialState: TorrentDetailState(
                        torrentId: 1,
                        name: "Ubuntu 22.04 LTS Desktop",
                        status: 4,
                        percentDone: 0.45,
                        totalSize: 3_500_000_000,
                        downloadedEver: 1_575_000_000,
                        uploadedEver: 500_000_000,
                        eta: 3600,
                        rateDownload: 2_500_000,
                        rateUpload: 500_000,
                        uploadRatio: 0.32,
                        downloadLimit: 1024,
                        downloadLimited: false,
                        uploadLimit: 512,
                        uploadLimited: true,
                        peersConnected: 45,
                        peersFrom: [
                            PeerSource(name: "Tracker", count: 30),
                            PeerSource(name: "DHT", count: 10),
                            PeerSource(name: "PEX", count: 5)
                        ],
                        downloadDir: "/downloads/ubuntu",
                        dateAdded: Int(Date().timeIntervalSince1970) - 3600,
                        files: [
                            TorrentFile(
                                index: 0,
                                name: "ubuntu-22.04-desktop-amd64.iso",
                                length: 3_500_000_000,
                                bytesCompleted: 1_575_000_000,
                                priority: 1
                            )
                        ],
                        trackers: [
                            TorrentTracker(
                                index: 0,
                                announce: "https://torrent.ubuntu.com/announce",
                                tier: 0
                            )
                        ],
                        trackerStats: [
                            TrackerStat(
                                trackerId: 0,
                                lastAnnounceResult: "Success",
                                downloadCount: 1_000,
                                leecherCount: 150,
                                seederCount: 350
                            )
                        ],
                        isLoading: false,
                        errorMessage: nil
                    )
                ) {
                    TorrentDetailReducer()
                }
            )
        }
    }
#endif
