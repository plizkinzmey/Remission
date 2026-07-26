import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension Color {
    /// A platform-agnostic background color for grouped content and control areas.
    /// Maps to `.controlBackgroundColor` on macOS and `.secondarySystemGroupedBackground` on iOS.
    static var controlBackgroundColor: Color {
        #if os(macOS)
            return Color(nsColor: .controlBackgroundColor)
        #else
            return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}
