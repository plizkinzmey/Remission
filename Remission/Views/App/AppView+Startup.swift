import ComposableArchitecture
import SwiftUI

extension AppView {
    #if os(iOS)
        var startupView: some View {
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

                        Text(appVersionText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(captionTextColor.opacity(0.75))
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
            minStartupDurationElapsed == false
        }

        var brandTextGradient: LinearGradient {
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

        var productTextGradient: LinearGradient {
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

        var captionTextColor: Color {
            if colorScheme == .dark {
                return Color.white.opacity(0.75)
            }
            return Color(red: 0.35, green: 0.28, blue: 0.22).opacity(0.9)
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
