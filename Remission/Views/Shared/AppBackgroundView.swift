import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        #else
            Color(.systemBackground)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        #endif
    }
}
