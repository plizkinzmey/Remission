import ComposableArchitecture
import SwiftUI

extension AppView {
    #if os(iOS)
        var startupView: some View {
            ZStack {
                // Стандартный системный фон
                Color(uiColor: .systemBackground)
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
                            color: .secondary.opacity(0.2),
                            radius: 12,
                            x: 0,
                            y: 4
                        )

                    Spacer()
                        .frame(height: 56)

                    // Текстовое содержимое с каскадной анимацией
                    VStack(spacing: 8) {
                        // Основной заголовок
                        Text(L10n.tr("app.startup.brand"))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .tracking(-0.5)
                            .foregroundStyle(.primary)
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
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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

                        Text(appVersionText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                            .opacity(isStartupTextVisible ? 1 : 0)
                            .blur(radius: isStartupTextVisible ? 0 : 6)
                            .offset(y: isStartupTextVisible ? 0 : 16)
                            .animation(
                                .easeInOut(duration: 3.0).delay(0.65),
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
            }
            .onDisappear {
                isStartupTextVisible = false
            }
        }

        var shouldShowStartup: Bool {
            store.startup.minDurationElapsed == false
        }

        var appVersionLabel: String {
            let info = Bundle.main.infoDictionary
            let shortVersion = info?["CFBundleShortVersionString"] as? String

            return shortVersion?.isEmpty == false ? shortVersion ?? "-" : "-"
        }

        var appVersionText: String {
            #if DEBUG
                return String(
                    format: L10n.tr("app.startup.version.debug"),
                    appVersionLabel
                )
            #else
                return String(
                    format: L10n.tr("app.startup.version"),
                    appVersionLabel
                )
            #endif
        }
    #endif
}
