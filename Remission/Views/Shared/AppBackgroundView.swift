import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppTheme.Background.baseGradient(colorScheme)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
