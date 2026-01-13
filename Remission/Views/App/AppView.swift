import ComposableArchitecture
import Dependencies
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>
    @State private var isStartupTextVisible: Bool = false
    @State private var minStartupDurationElapsed: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    /// Минимальное время отображения splash-экрана (в секундах)
    private let minStartupDuration: TimeInterval = 3.0

    var body: some View {
        #if os(iOS)
            ZStack {
                if shouldShowStartup {
                    startupView
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            )
                        )
                        .zIndex(1)
                } else {
                    navigationContent
                }
            }
            .animation(.easeInOut(duration: 0.6), value: shouldShowStartup)
        #else
            navigationContent
                .appRootChrome()
                .handlesExternalEvents(
                    preferring: Set(["*"]),
                    allowing: Set(["*"])
                )
        #endif
    }

    private var navigationContent: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            rootContent
                #if os(iOS)
                    .navigationTitle("")
                #else
                    .navigationTitle(L10n.tr("app.title"))
                #endif
                .toolbar {
                    #if os(macOS)
                        if shouldShowAddServerToolbarButton {
                            ToolbarItem(placement: .primaryAction) { macOSToolbarPill }
                        }
                    #else
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if shouldShowAddServerToolbarButton {
                                addServerButton
                            }
                        }
                    #endif
                }
        } destination: { store in
            ServerDetailView(store: store)
        }
        .onOpenURL { url in
            store.send(.openTorrentFile(url))
        }
        .task {
            await store.send(.serverList(.task)).finish()
        }
        .background(AppBackgroundView())
        .appRootChrome()
    }

    @ViewBuilder
    private var rootContent: some View {
        #if os(iOS)
            ServerListView(
                store: store.scope(state: \.serverList, action: \.serverList)
            )
        #else
            if shouldShowServerList {
                ServerListView(
                    store: store.scope(state: \.serverList, action: \.serverList)
                )
            } else {
                initialLoadingView
            }
        #endif
    }

    private var initialLoadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if os(iOS)
        private var startupView: some View {
            ZStack {
                // Фон совпадает с основными экранами приложения.
                AppBackgroundView()

                // Декоративные размытые светящиеся элементы
                ZStack {
                    // Верхний левый оранжевый свет
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(
                                        red: 1,
                                        green: 0.6,
                                        blue: 0,
                                        opacity: colorScheme == .dark ? 0.18 : 0.1
                                    ),
                                    Color(red: 1, green: 0.6, blue: 0, opacity: 0)
                                ]),
                                center: .init(x: 0.1, y: 0.1),
                                startRadius: 0,
                                endRadius: 260
                            )
                        )

                    // Нижний правый синий свет
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(
                                        red: 0.2,
                                        green: 0.5,
                                        blue: 1,
                                        opacity: colorScheme == .dark ? 0.14 : 0.07
                                    ),
                                    Color(red: 0.2, green: 0.5, blue: 1, opacity: 0)
                                ]),
                                center: .init(x: 0.9, y: 0.9),
                                startRadius: 0,
                                endRadius: 320
                            )
                        )
                }
                .ignoresSafeArea()

                // Основной контент
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    // Иконка приложения
                    Image("LaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(
                            color: Color.black.opacity(0.35),
                            radius: 24,
                            x: 0,
                            y: 14
                        )

                    Spacer()
                        .frame(height: 56)

                    // Текстовое содержимое с каскадной анимацией
                    VStack(spacing: 8) {
                        // Основной заголовок
                        Text(L10n.tr("app.startup.brand"))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .tracking(-0.5)
                            .foregroundStyle(brandTextGradient)
                            .opacity(isStartupTextVisible ? 1 : 0)
                            .blur(radius: isStartupTextVisible ? 0 : 6)
                            .offset(y: isStartupTextVisible ? 0 : 16)
                            .animation(
                                .easeInOut(duration: 3.0).delay(0.2),
                                value: isStartupTextVisible
                            )

                        // Подзаголовок
                        Text(L10n.tr("app.startup.product"))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(productTextGradient)
                            .opacity(isStartupTextVisible ? 1 : 0)
                            .blur(radius: isStartupTextVisible ? 0 : 6)
                            .offset(y: isStartupTextVisible ? 0 : 16)
                            .animation(
                                .easeInOut(duration: 3.0).delay(0.35),
                                value: isStartupTextVisible
                            )

                        // Описание
                        Text(L10n.tr("app.startup.caption"))
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .lineSpacing(3)
                            .foregroundStyle(captionTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .opacity(isStartupTextVisible ? 1 : 0)
                            .blur(radius: isStartupTextVisible ? 0 : 6)
                            .offset(y: isStartupTextVisible ? 0 : 16)
                            .animation(
                                .easeInOut(duration: 3.0).delay(0.5),
                                value: isStartupTextVisible
                            )
                    }

                    Spacer()
                        .frame(height: 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityIdentifier("app_startup_view")
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isStartupTextVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + minStartupDuration) {
                    minStartupDurationElapsed = true
                }
            }
            .onDisappear {
                isStartupTextVisible = false
            }
        }
    #endif

    private var addServerButton: some View {
        Button {
            store.send(.serverList(.addButtonTapped))
        } label: {
            Label(L10n.tr("app.action.addServer"), systemImage: "plus")
        }
        .accessibilityIdentifier("app_add_server_button")
        .accessibilityHint(L10n.tr("serverList.action.addServer"))
    }

    #if os(iOS)
        private var brandTextGradient: LinearGradient {
            if colorScheme == .dark {
                return LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: Color(red: 1, green: 0.7, blue: 0.15), location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            return LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.25, green: 0.18, blue: 0.12), location: 0),
                    .init(color: Color(red: 0.8, green: 0.4, blue: 0.05), location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        private var productTextGradient: LinearGradient {
            if colorScheme == .dark {
                return LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 1, green: 0.65, blue: 0), location: 0),
                        .init(color: Color(red: 1, green: 0.45, blue: 0), location: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            return LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.78, green: 0.35, blue: 0.05), location: 0),
                    .init(color: Color(red: 0.62, green: 0.26, blue: 0.06), location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        private var captionTextColor: Color {
            if colorScheme == .dark {
                return Color.white.opacity(0.75)
            }
            return Color(red: 0.35, green: 0.28, blue: 0.22).opacity(0.9)
        }

    #endif

    #if os(macOS)
        private var macOSToolbarPill: some View {
            HStack(spacing: 10) {
                if shouldShowAddServerToolbarButton {
                    toolbarIconButton(
                        systemImage: "plus",
                        accessibilityIdentifier: "app_add_server_button"
                    ) {
                        store.send(.serverList(.addButtonTapped))
                    }
                    .accessibilityHint(L10n.tr("serverList.action.addServer"))
                }

            }
            .padding(.horizontal, 12)
            .frame(height: macOSToolbarPillHeight)
            .appToolbarPillSurface()
        }

        private func toolbarIconButton(
            systemImage: String,
            accessibilityIdentifier: String,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier)
        }

        private var macOSToolbarPillHeight: CGFloat { 34 }
    #endif

    private var shouldShowAddServerToolbarButton: Bool {
        store.serverList.servers.isEmpty == false
    }

    private var shouldShowServerList: Bool {
        if store.path.isEmpty == false {
            return true
        }
        if store.hasLoadedServersOnce == false {
            return store.serverList.isLoading
        }
        if store.serverList.isLoading, store.serverList.servers.isEmpty {
            return false
        }
        return true
    }

    #if os(iOS)
        private var shouldShowStartup: Bool {
            // Минимум 4 секунды + до завершения первичной загрузки серверов.
            store.path.isEmpty
                && (minStartupDurationElapsed == false || store.hasLoadedServersOnce == false)
        }
    #endif
}

#Preview("AppView Empty") {
    AppView(
        store: Store(
            initialState: AppReducer.State()
        ) {
            AppReducer()
        } withDependencies: {
            $0 = previewDependencies()
        }
    )
}

#Preview("AppView Sample") {
    AppView(
        store: Store(initialState: sampleState()) {
            AppReducer()
        } withDependencies: {
            $0 = previewDependencies()
        }
    )
}

#Preview("AppView Legacy Migration") {
    AppView(
        store: Store(initialState: migratedLegacyState()) {
            AppReducer()
        } withDependencies: {
            $0 = previewDependencies()
        }
    )
}

@MainActor
private func sampleState() -> AppReducer.State {
    var state: AppReducer.State = .init()
    state.serverList.servers = [
        ServerConfig.previewLocalHTTP,
        ServerConfig.previewSecureSeedbox
    ]
    return state
}

@MainActor
private func migratedLegacyState() -> AppReducer.State {
    var serverList = ServerListReducer.State()
    serverList.servers = [
        ServerConfig.previewLocalHTTP
    ]
    let legacyDetailState = ServerDetailReducer.State(server: .previewLocalHTTP)
    let legacyState = AppReducer.State(
        version: .legacy,
        serverList: serverList,
        path: StackState([legacyDetailState])
    )
    return AppBootstrap.makeInitialState(
        arguments: [],
        targetVersion: .latest,
        existingState: legacyState
    )
}

@MainActor
private func previewDependencies() -> DependencyValues {
    var dependencies = AppDependencies.makePreview()
    dependencies.credentialsRepository = .previewMock()
    dependencies.transmissionClient = .previewMock()
    return dependencies
}
