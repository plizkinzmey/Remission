import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        #if os(macOS)
            Rectangle()
                .fill(.windowBackground)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        #else
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        #endif
    }
}
