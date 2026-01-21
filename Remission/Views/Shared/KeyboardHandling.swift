import SwiftUI

#if os(iOS)
    import Combine
    import UIKit

    extension View {
        func appKeyboardAvoiding() -> some View {
            self
        }

        func appDismissKeyboardOnTap() -> some View {
            contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                )
        }
    }
#else
    extension View {
        func appKeyboardAvoiding() -> some View { self }
        func appDismissKeyboardOnTap() -> some View { self }
    }
#endif
